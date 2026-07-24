# Mutations & Optimistic Updates Best Practices

## Use `useMutation` for writes, never `useQuery`

Queries must be idempotent and side-effect-free because React Query runs them automatically and repeatedly. Writes (POST/PATCH/DELETE) have side effects and must fire imperatively on an event, exactly once — that is what `useMutation` is for.

```tsx
function useUpdateUser() {
  return useMutation({ mutationFn: updateUser })
}

function ChangeName({ id }: { id: string }) {
  const { mutate, isPending } = useUpdateUser()
  return (
    <form onSubmit={(e) => {
      e.preventDefault()
      const newName = new FormData(e.currentTarget).get('name') as string
      mutate({ id, newName })
    }}>
      <input name="name" />
      <button type="submit" disabled={isPending}>Update</button>
    </form>
  )
}
```

## Type the `mutationFn` parameter explicitly

Types do not flow into a mutation's variables automatically, even when the underlying function is typed. Annotate the `mutationFn` argument so `mutate`, and the `variables` passed to every callback, are correctly typed.

```ts
type UpdateUserInput = { id: string; newName: string }

function useUpdateUser() {
  return useMutation({
    mutationFn: (input: UpdateUserInput) => updateUser(input),
  })
}
```

## Prefer `invalidateQueries` over manual `setQueryData` for correctness

Invalidation refetches active queries and marks the rest stale, making the server the source of truth. Manual cache writes force you to re-implement server logic on the client (sorting, filtering, derived fields) and drift out of sync — a single mutated entity often lives in many cache entries at once.

```ts
function useAddTodo() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: addTodo,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['todos', 'list'] }),
  })
}
```

## Structure query keys generic → specific and lean on fuzzy matching

`invalidateQueries({ queryKey: ['todos', 'list'] })` invalidates every key that *starts with* that array, so one call clears all sort/filter variants. This only works if keys are ordered hierarchically from entity down to specifics.

```ts
// These are all invalidated by ['todos', 'list']:
['todos', 'list', { sort: 'id' }]
['todos', 'list', { sort: 'title' }]
// Untouched:
['todos', 'detail', '1']
['posts', 'list', { sort: 'date' }]
```

## Return the invalidation promise from `onSuccess`/`onSettled`

Returning the promise keeps the mutation in its `pending` state until the refetch resolves. This prevents UI flashes where the button re-enables (or a form re-shows) before the fresh data has landed.

```ts
onSuccess: () => {
  return queryClient.invalidateQueries({ queryKey: ['todos', 'list'] })
}
```

## Refine invalidation with filters or a `predicate` when keys can't target cleanly

Beyond the key prefix you can filter by `type: 'active'`, `stale: true`, or a `predicate` for full control. Use `refetchType: 'all'` only when you deliberately want inactive queries to refetch immediately too (more consistency, more network).

```ts
queryClient.invalidateQueries({
  predicate: (query) => query.queryKey[1] === 'detail',
})
```

## Implement optimistic updates as the full five-step pattern

When you already know the post-mutation UI, update it instantly and roll back on failure. The complete, correct sequence inside one mutation is: **cancel → snapshot → optimistic write → return rollback → rollback in `onError` → invalidate in `onSettled`.** Skipping any step reintroduces races or leaves stale data.

```ts
function useToggleTodo(id: string, sort: string) {
  const queryClient = useQueryClient()
  const key = ['todos', 'list', { sort }]

  return useMutation({
    mutationFn: () => toggleTodo(id),
    onMutate: async () => {
      // 1. Stop in-flight refetches that could clobber our write
      await queryClient.cancelQueries({ queryKey: key })
      // 2. Snapshot for rollback
      const snapshot = queryClient.getQueryData(key)
      // 3. Optimistically write the expected result
      queryClient.setQueryData(key, (todos) =>
        todos?.map((t) => (t.id === id ? { ...t, done: !t.done } : t))
      )
      // 4. Return a rollback closure as context
      return () => queryClient.setQueryData(key, snapshot)
    },
    // 5a. On failure, restore the snapshot
    onError: (error, variables, rollback) => {
      rollback?.()
    },
    // 5b. Always reconcile with the server afterwards
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['todos', 'list'] }),
  })
}
```

## Always `await cancelQueries` before an optimistic write

An in-flight refetch that resolves *after* your optimistic `setQueryData` will overwrite it with stale server data. `cancelQueries` (awaited, so `onMutate` must be `async`) removes that race.

```ts
onMutate: async () => {
  await queryClient.cancelQueries({ queryKey: key })
  // ...snapshot + optimistic write
}
```

## Snapshot the cache before writing, and return the rollback as context

Whatever `onMutate` returns is passed as the third argument to `onError`, `onSuccess`, and `onSettled`. Capture the snapshot *before* mutating and return a closure that restores it — this is the cleanest way to give `onError` its rollback.

```ts
onMutate: async () => {
  await queryClient.cancelQueries({ queryKey: key })
  const snapshot = queryClient.getQueryData(key)
  queryClient.setQueryData(key, updater)
  return () => queryClient.setQueryData(key, snapshot)
}
```

## Always invalidate in `onSettled`, even after an optimistic write

`onSettled` runs on both success and failure, after the other callbacks. A final invalidation guarantees the cache matches the server in the edge case where the server returned something different from your optimistic guess.

```ts
onSettled: () => {
  return queryClient.invalidateQueries({ queryKey: ['todos', 'list'] })
}
```

## Update the cache immutably

React Query detects changes by reference. Mutating `previousData` in place leaves the reference unchanged, so observers never re-render. Always return a new object/array.

```ts
// Good — new object
queryClient.setQueryData(['user', id], (prev) =>
  prev ? { ...prev, name: newName } : prev
)

// Anti-pattern — mutates in place, UI won't update
queryClient.setQueryData(['user', id], (prev) => {
  if (prev) prev.name = newName // reference unchanged!
  return prev
})
```

## Handle `undefined` in functional cache updaters

The updater signature is `(prev: TData | undefined) => TData | undefined` — the query may not exist in the cache yet. Guard against `undefined` and return it to bail out of the update cleanly.

```ts
queryClient.setQueryData(['user', id], (prev) =>
  prev ? { ...prev, name: newName } : undefined
)
```

## Choose `mutate` vs `mutateAsync` deliberately

Use `mutate` for fire-and-forget calls with callbacks — it never throws, so you handle outcomes via `onSuccess`/`onError`. Reach for `mutateAsync` only when you genuinely need to await the result or coordinate several mutations; it rejects on failure, so you **must** wrap it in try/catch or you get an unhandled rejection.

```ts
// mutate — fire and forget, callbacks handle the result
mutate({ id, newName }, { onSuccess: () => form.reset() })

// mutateAsync — await, but you own error handling
try {
  const user = await mutateAsync({ id, newName })
} catch (error) {
  // handle it yourself
}
```

## Scope callbacks correctly: hook-level for cache, call-level for component effects

Callbacks on `useMutation` belong to the mutation and always run — put shared concerns like cache updates and invalidation there. Callbacks passed as the second argument to `mutate` are tied to the call site — use them for component-specific side effects (resetting a form, navigating, toast). Note: `mutate`-level callbacks do **not** fire if the component unmounts before the mutation settles, whereas hook-level ones always do.

```tsx
// Hook-level: cache concerns, always run
function useUpdateUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: updateUser,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })
}

// Call-level: component concern, tied to this submit
mutate({ id, newName }, { onSuccess: () => formRef.current.reset() })
```

## Derive UI from mutation `status` for the simple case, but not under rapid fire

For a single toggle you can render optimistically straight from `isPending` without touching the cache — no rollback needed. But this breaks under rapid successive clicks: between a mutation finishing and its invalidation completing, the UI briefly disagrees with the server. When rapid or concurrent mutations are possible, update the cache optimistically instead so the cache stays the single source of truth.

```tsx
// Fine for one-off toggles; races under rapid clicks
<input
  type="checkbox"
  checked={isPending ? !todo.done : todo.done}
  onChange={() => mutate()}
/>
```

## Extract a reusable `useOptimisticMutation` when the pattern repeats

The optimistic dance is verbose and error-prone to hand-write each time. Abstract it once behind a hook that takes the `queryKey`, an `updater`, and what to `invalidate`, so call sites stay declarative.

```ts
export const useOptimisticMutation = ({ mutationFn, queryKey, updater, invalidates }) => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn,
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey })
      const snapshot = queryClient.getQueryData(queryKey)
      queryClient.setQueryData(queryKey, updater)
      return () => queryClient.setQueryData(queryKey, snapshot)
    },
    onError: (err, variables, rollback) => rollback?.(),
    onSettled: () => queryClient.invalidateQueries({ queryKey: invalidates }),
  })
}
```
