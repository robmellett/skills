# Robustness Best Practices

## Always let errors reach React Query — never swallow them in the `queryFn`

Any promise rejection (a `throw`, `Promise.reject()`, or `reject`) tells React Query to set `status: 'error'`. If you `try/catch` inside the `queryFn` without re-throwing, React Query never learns the request failed, so it can't update status or trigger retries.

```ts
function useRepos() {
  return useQuery({
    queryKey: ['repos'],
    queryFn: async () => {
      const response = await fetch('https://api.github.com/orgs/TanStack/repos')
      if (!response.ok) {
        throw new Error(`Request failed with status: ${response.status}`)
      }
      return response.json()
    },
  })
}
```

**Anti-pattern:** catching the error and only `console.log`-ing it — you silently swallow the failure and disable retries.

## Validate and parse response data inside the `queryFn`

Third-party API shapes are untrusted and can drift. Parse the response against a schema in the `queryFn` so only well-formed data ever enters the cache — then everything downstream can trust the cached data. A failed parse throws, which React Query already treats as an error state.

```ts
import { z } from 'zod'

const pokemonSchema = z.object({
  id: z.number(),
  name: z.string(),
  sprites: z.object({ front_default: z.string().url() }).optional(),
})

function usePokemon(id: number) {
  return useQuery({
    queryKey: ['pokemon', id],
    queryFn: async () => {
      const res = await fetch(`https://pokeapi.co/api/v2/pokemon/${id}`)
      if (!res.ok) throw new Error(`Request failed: ${res.status}`)
      return pokemonSchema.parse(await res.json()) // throws on mismatch → error state
    },
  })
}

// TS: infer the type from the schema, don't hand-maintain it
type Pokemon = z.infer<typeof pokemonSchema>
```

Parsing also strips unknown fields, shrinking what you store in the cache. Runtime validation isn't free — skip it only for APIs you fully control where the payload cost outweighs the safety.

## Rely on the retry defaults; disable retries deliberately

By default React Query retries a failed request 3 times with exponential backoff (1s up to 30s). This absorbs transient failures for free. Override `retry`/`retryDelay` per case, but prefer setting them globally for consistency.

```ts
useQuery({
  queryKey: ['repos'],
  queryFn: fetchRepos,
  retry: (failureCount, error) => {
    if (error instanceof HTTPError && error.status >= 500) {
      return failureCount < 3 // only retry server errors
    }
    return false // don't retry 4xx — the request won't get better
  },
  retryDelay: (failureCount) => failureCount * 1000,
})
```

Set `retry: false` for queries where a retry is pointless (e.g. a 404 on a resource that doesn't exist). During retries the query stays `pending`; use `failureCount`/`failureReason` to surface "taking longer than expected" messaging.

## Use `throwOnError` + an error boundary for render-time error handling

Checking `status === 'error'` in every component couples error UI to each query. Error boundaries let a higher-level component own the fallback UI for anything below it. But boundaries only catch errors thrown *during render* — fetch errors happen outside React's render flow, so you must opt in with `throwOnError` to have React Query re-throw them.

```tsx
import { ErrorBoundary } from 'react-error-boundary'

function useTodos() {
  return useQuery({
    queryKey: ['todos', 'list'],
    queryFn: fetchTodos,
    // Only throw when there's no cached data to show
    throwOnError: (error, query) => typeof query.state.data === 'undefined',
  })
}

<ErrorBoundary FallbackComponent={Fallback}>
  <TodoList />
</ErrorBoundary>
```

**Anti-pattern:** unconditionally throwing every error (`throwOnError: true`) — a failed *background* refetch will blow away a screen that already has good data. Gate on `query.state.data === undefined` (or `error.status >= 500`) so background failures fail silently.

## Wire error-boundary reset to a query refetch

Resetting the boundary's fallback UI is only half the job — you also need React Query to refetch. Wrap the boundary in `QueryErrorResetBoundary` and pass its `reset` to the boundary's `onReset` so retrying clears both the fallback and the query error.

```tsx
import { QueryErrorResetBoundary } from '@tanstack/react-query'
import { ErrorBoundary } from 'react-error-boundary'

<QueryErrorResetBoundary>
  {({ reset }) => (
    <ErrorBoundary
      onReset={reset}
      FallbackComponent={({ error, resetErrorBoundary }) => (
        <>
          <p>Error: {error.message}</p>
          <button onClick={resetErrorBoundary}>Try again</button>
        </>
      )}
    >
      <TodoList />
    </ErrorBoundary>
  )}
</QueryErrorResetBoundary>
```

## Handle imperative error side effects once, globally, via `QueryCache({ onError })`

For side effects like a toast, don't put the logic in a per-component `useEffect` — every extra call site of the hook fires it again, so you get duplicate toasts. The `QueryCache` `onError` callback runs once *per query*, regardless of how many components observe it.

```ts
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      throwOnError: (error, query) => typeof query.state.data === 'undefined',
    },
  },
  queryCache: new QueryCache({
    onError: (error, query) => {
      // Data already on screen → toast; otherwise let the ErrorBoundary handle it
      if (typeof query.state.data !== 'undefined') {
        toast.error(error.message)
      }
    },
  }),
})
```

This combination — throw to a boundary when there's no data, toast when there is — is a solid default you configure once.

**Anti-pattern:** per-hook `useEffect(() => { if (error) toast(...) }, [error])`. It's not deduped and multiplies with each observer.

## Understand `networkMode` — offline pauses fetches, it doesn't fail them

With the default `networkMode: 'online'`, an offline device puts the query in `fetchStatus: 'paused'` without ever running the `queryFn`; it auto-resumes on reconnect. Going offline never clears the cache, so previously fetched data stays visible.

```
{ status: 'pending', data: undefined, fetchStatus: 'paused' }
```

Because a paused query is `pending` but not `fetching`, use `isPending` (not `isLoading`) to drive loading UI — `isLoading` is `status === 'pending' && fetchStatus === 'fetching'`, so it's `false` while paused even with no data.

## Pick the right `networkMode` for the query's needs

- `online` (default) — needs the network; pauses when offline.
- `always` — never pauses; use for queries that don't touch the network (e.g. computed/local data). Note this also disables `refetchOnReconnect`.
- `offlineFirst` — fires the first request even offline, pausing only retries; use when there's a cache layer in front of your API (e.g. the browser HTTP cache honoring `cache-control`).

```tsx
useQuery({
  queryKey: ['luckyNumber'],
  queryFn: () => Promise.resolve(7),
  networkMode: 'always', // no network required, don't pause offline
})
```

## Trust React Query's offline mutation queue; invalidate once at the end of a chain

`networkMode` applies to mutations too — offline mutations are queued and replayed, in order, on reconnect (`onMutate` writes to the cache before pausing, so optimistic UI still works). When several queued mutations hit the same entity, invalidating after each one shows intermediate server states and makes the UI jump. Tag mutations with a `mutationKey` and, in `onSettled`, only invalidate when yours is the last one running.

```ts
useMutation({
  mutationFn: toggleTodo,
  mutationKey: ['todos', 'list'],
  onSettled: () => {
    if (queryClient.isMutating({ mutationKey: ['todos', 'list'] }) === 1) {
      return queryClient.invalidateQueries({ queryKey: ['todos', 'list'] })
    }
  },
})
```

## Persist the cache for offline-first apps with `PersistQueryClientProvider`

The cache is in-memory and lost on reload/close. For offline-first or flaky-network apps, persist it to storage so it's restored before anything else runs. Use `createSyncStoragePersister` for synchronous storage (`localStorage`), the async variant for `IndexedDB`, and swap `QueryClientProvider` for `PersistQueryClientProvider`.

```tsx
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client'
import { createSyncStoragePersister } from '@tanstack/query-sync-storage-persister'

const persister = createSyncStoragePersister({ storage: window.localStorage })

<PersistQueryClientProvider client={queryClient} persistOptions={{ persister }}>
  {children}
</PersistQueryClientProvider>
```

## Control what gets persisted, and keep only successful queries

Persistence is global by default. Never persist sensitive data to `localStorage`. Opt queries in via `meta` and filter in `shouldDehydrateQuery`, and always compose with `defaultShouldDehydrateQuery` so failed/pending queries aren't written.

```tsx
import { defaultShouldDehydrateQuery } from '@tanstack/react-query'

// mark a query as persistable
useQuery({ queryKey: ['posts'], queryFn: fetchPosts, meta: { persist: true } })

<PersistQueryClientProvider
  client={queryClient}
  persistOptions={{
    persister,
    dehydrateOptions: {
      shouldDehydrateQuery: (query) =>
        defaultShouldDehydrateQuery(query) && query.meta?.persist === true,
    },
  }}
>
```

## Keep `gcTime >= maxAge` so persisted data isn't garbage-collected early

Persisted storage is synced to the cache, and cache entries are removed on `gcTime`. If `gcTime` is shorter than the persister's `maxAge` (default 24h), queries get GC'd and dropped from storage before they should expire. Set `gcTime` equal to or greater than `maxAge`.

```tsx
const queryClient = new QueryClient({
  defaultOptions: { queries: { gcTime: 1000 * 60 * 60 * 12 } }, // 12h
})

<PersistQueryClientProvider
  client={queryClient}
  persistOptions={{ persister, maxAge: 1000 * 60 * 60 * 12 }} // 12h
>
```

## Handle persister write failures with a `retry` strategy

Storage has quotas (~5MB for `localStorage`); since the cache is persisted as a whole, one over-quota write persists *nothing*. Supply a `retry` handler to shed data and try again. Prefer the built-in `removeOldestQuery` over hand-rolled logic.

```ts
import { removeOldestQuery } from '@tanstack/react-query-persist-client'

const persister = createSyncStoragePersister({
  storage: window.localStorage,
  retry: removeOldestQuery, // drop oldest query and retry on quota errors
})
```

## Don't assume the cache is restored on first render — gate on `useIsRestoring` if needed

Restoration is a side effect outside render, so on the initial render the cache may not be populated yet (queries sit at `status: 'pending'`, `fetchStatus: 'idle'`). React Query renders immediately and defers running queries until restore completes — good for SSR. If you must delay UI until restore finishes (non-SSR), build a gate with `useIsRestoring` rather than blocking render globally.

```tsx
import { useIsRestoring } from '@tanstack/react-query'

function PersistGate({ children, fallback = null }) {
  return useIsRestoring() ? fallback : children
}
```

## Persist and resume mutations for durable offline writes

`PersistQueryClientProvider` persists paused *mutations* too, so offline edits survive a tab close or dead battery. To replay them, register default mutation functions up front (so React Query can restore without waiting to find the `useMutation` call) and call `resumePausedMutations` from `onSuccess`. Return the promise to keep queries pending until replay finishes.

```tsx
queryClient.setMutationDefaults(['posts'], { mutationFn: addPost })

<PersistQueryClientProvider
  client={queryClient}
  persistOptions={{ persister }}
  onSuccess={() => queryClient.resumePausedMutations()}
>
```

## Build framework adapters on `@tanstack/query-core`, not by re-implementing caching

React Query is a thin layer over the framework-agnostic core. To integrate any UI layer, wrap the core rather than reinventing caching/dedup/retries. Every adapter follows three steps: create a `QueryObserver` per component, `subscribe` to it, and update the view on change — plus `mount()`/`unmount()` the client for focus/reconnect refetching, and clean up on teardown.

```ts
import { QueryObserver } from '@tanstack/query-core'

function createQueryBinding(queryClient, queryOptions, render) {
  queryClient.mount() // enables refetchOnWindowFocus / reconnect; deduped internally
  const observer = new QueryObserver(queryClient, queryOptions)

  const unsubscribe = observer.subscribe(() => {
    // trackResult opts into property tracking (on by default in React, off in core)
    render(observer.trackResult(observer.getCurrentResult()))
  })

  return {
    setOptions: (opts) => observer.setOptions(opts), // support dynamic option changes
    destroy: () => { unsubscribe(); queryClient.unmount() }, // always clean up
  }
}
```

Key rules: one observer per component instance; always `unsubscribe` and `unmount` on destroy to avoid leaks; forward option changes via `observer.setOptions`; wrap results in `trackResult` so views only update on fields they actually read.
