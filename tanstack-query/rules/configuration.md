# Configuration & Performance Best Practices

## Set query defaults once on the QueryClient

Any option `useQuery` accepts (except `queryKey`) can be defaulted globally via `defaultOptions` when you construct the client. Do this instead of copy-pasting the same `staleTime`/`retry`/`gcTime` into every hook — one source of truth that scales.

```ts
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 10 * 1000,
    },
  },
})
```

## Understand the precedence order

Options resolve in layers, each overriding the previous: global `defaultOptions` → `setQueryDefaults` (per key subset) → the options passed to `useQuery`. Rely on this to keep hooks lean and only specify what deviates.

```ts
// effective options ≈ { ...clientDefaults, ...queryKeyDefaults, ...useQueryOptions }
useQuery({ queryKey: todoKeys.list(sort), staleTime: 5000 }) // wins over defaults
```

## Scope defaults to a subset of keys with `setQueryDefaults`

When only part of your cache needs a different setting, target it by key prefix. Fuzzy matching applies the options to every query whose key starts with the given key.

```ts
// Applies only to ['todos', 'detail', ...] queries
queryClient.setQueryDefaults(['todos', 'detail'], { staleTime: 10 * 1000 })
```

## Derive the queryFn from the queryKey when all requests hit one API

You can default even the `queryFn`. Read the key off the `QueryFunctionContext` and build the URL from it — this makes it impossible to forget a variable in the key that the fetch depends on, and lets hooks shrink to just a `queryKey`.

```ts
queryClient.setQueryDefaults(['posts'], {
  queryFn: async ({ queryKey }) => {
    const res = await fetch('/api/' + queryKey.join('/'))
    if (!res.ok) throw new Error('fetch failed')
    return res.json()
  },
})

// Hook needs no queryFn:
function usePost(path: string) {
  return useQuery({ queryKey: ['posts', path] })
}
```

## Never scatter inline query key arrays — use a query key factory per feature

Hand-typing the same key array in a hook and again in an `invalidateQueries` call is the classic afternoon-killer: one typo and invalidation silently misses. Centralize every key for a feature in one factory object, prefixed with the feature name so keys never collide across features, and import it everywhere.

```ts
// keys.ts
export const todoKeys = {
  allLists: () => ['todos', 'list'],
  list: (sort: string) => ['todos', 'list', { sort }],
} as const
```

```ts
useQuery({ queryKey: todoKeys.list(sort), queryFn: () => fetchTodos(sort) })
```

**Anti-pattern:** `queryKey: ['todos', 'list', { sort }]` re-typed in multiple files.

## Compose specific keys from generic ones for a stable hierarchy

Build each key on top of the level above it so shared prefixes are defined once. This hierarchy is what makes targeted, fuzzy invalidation possible. Add `as const` so TypeScript infers the narrowest tuple type.

```ts
const todoKeys = {
  all: () => ['todos'] as const,
  allLists: () => [...todoKeys.all(), 'list'] as const,
  list: (sort: string) => [...todoKeys.allLists(), { sort }] as const,
}
```

## Use hierarchical keys for targeted (fuzzy) invalidation

Invalidating a parent key invalidates every child under it, because matching is prefix-based. Reach for the broadest key that covers exactly what changed — no more, no less.

```ts
useMutation({
  mutationFn,
  onSuccess: () => {
    // Invalidates every ['todos','list',...] query in one call
    queryClient.invalidateQueries({ queryKey: todoKeys.allLists() })
  },
})
```

## Pass `invalidateQueries` an object, not a bare key array

`invalidateQueries` expects a filters object with a `queryKey` property. Handing it a raw array (or a full query-options object) is a common slip — wrap the key.

```ts
// Wrong: passes an array where an object is expected
queryClient.invalidateQueries(todoKeys.allLists())

// Right:
queryClient.invalidateQueries({ queryKey: todoKeys.allLists() })
```

## Prefer query factories to keep queryKey and queryFn together

A key factory alone splits the key from its fetcher — an inseparable pair, since the key declares the fetcher's dependencies. Promote the factory to a *query factory* that returns full options objects, so key + fn + options live in one place and are reusable across `useQuery` and `prefetchQuery`.

```ts
const todoQueries = {
  all: () => ['todos'] as const,
  allDetails: () => [...todoQueries.all(), 'detail'] as const,
  detail: (id: string) => ({
    queryKey: [...todoQueries.allDetails(), id],
    queryFn: () => fetchTodo(id),
    staleTime: 5 * 1000,
  }),
}

useQuery(todoQueries.detail(id))
queryClient.prefetchQuery(todoQueries.detail(id)) // same source
```

## Type query factories with the `queryOptions` helper

In TypeScript, wrap each real query entry in `queryOptions` so a mistyped option (`staletime`) is caught and the `QueryFunctionContext` passed to `queryFn` is correctly typed.

```ts
import { queryOptions } from '@tanstack/react-query'

const todoQueries = {
  list: (sort: string) =>
    queryOptions({
      queryKey: ['todos', 'list', sort],
      queryFn: () => fetchTodos(sort),
      staleTime: 5 * 1000,
    }),
}
```

## Wrap every query in a custom hook

Colocate the key, fetcher, and options behind a named hook so call sites read intent, not plumbing, and the query definition lives in one file next to the feature that uses it.

```ts
export function useTodos(sort: string) {
  return useQuery({
    queryKey: todoKeys.list(sort),
    queryFn: () => fetchTodos(sort),
  })
}
```

## Merge factory options to customize a single call

You don't lose per-call flexibility with factories — spread the factory result and append overrides.

```ts
const { data } = useQuery({
  ...todoQueries.list(sort),
  refetchInterval: 10 * 1000,
})
```

## Use `select` to subscribe to a slice of the data

The Observer knows when `data` changed but not *which fields* a component reads. `select` lets you transform/narrow the query result so the component only re-renders when the selected slice changes — unrelated fields (e.g. a churning `updatedAt`) no longer trigger renders. Referential equality is irrelevant here; React Query compares the selected *content*.

```ts
const { data } = useQuery({
  queryKey: ['user'],
  queryFn: fetchUser,
  select: (data) => ({ name: data.name }), // ignores updatedAt churn
})
```

**Anti-pattern:** subscribing to a whole object and reading one field in the component — every change to any field re-renders.

## Memoize an expensive `select`

`select` runs on every render by default. If the transform is costly, stabilize it with `useCallback` so it only recomputes when its dependencies change.

```ts
select: React.useCallback(expensiveTransformation, [])
```

## Rely on structural sharing — don't fight it

When a `queryFn` returns a new object whose contents are unchanged, React Query keeps the previous reference. This means `data` is safe to use in `useEffect`/`useMemo` dependency arrays and with `React.memo` without spurious triggers. Don't manually clone or re-wrap `data` in ways that defeat this.

## Don't rest-destructure the useQuery result

React Query returns the result object with custom getters so it can track which properties (`data`, `error`, `status`…) a component actually reads — and re-render only when those change (Tracked Properties). Using `...rest` forces every getter to fire, marking all fields as observed and killing the optimization. Destructure named fields or access properties directly.

```ts
// Good — only tracks data and error
const { data, error } = useQuery({ queryKey, queryFn })

// Good — direct access
const result = useQuery({ queryKey, queryFn })
result.data

// Bad — touches every tracked property
const { data, ...rest } = useQuery({ queryKey, queryFn })
```

Enable the `@tanstack/query/no-rest-destructuring` ESLint rule to catch this automatically.

## Cancel in-flight requests with the AbortController signal

For rapid successive queries (e.g. an un-debounced search), React Query by default lets every request resolve, wasting client and server resources. Forward the `signal` from the context to `fetch` so superseded requests are aborted and only the latest fills the cache.

```ts
function useIssues(search: string) {
  return useQuery({
    queryKey: ['issues', search],
    queryFn: async ({ signal }) => {
      const res = await fetch(`/api/search?q=${search}`, { signal })
      if (!res.ok) throw new Error('fetch failed')
      return res.json()
    },
  })
}
```
