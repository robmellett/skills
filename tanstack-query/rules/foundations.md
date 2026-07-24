# Foundations Best Practices

## Treat React Query as async state management, not a data-fetching library

React Query does not fetch anything for you — you hand it a promise (from `fetch`, `axios`, GraphQL, IndexedDB, anything) and it manages the resulting *server state* over time: caching, deduplication, invalidation, refetching. The hard part was never the fetch; it's keeping that data correct across renders, components, and time. Frame every decision around "how is this cached state managed", not "how do I fetch".

## Separate server state from client state

Client state is yours: synchronous, instantly available, ephemeral, and only you mutate it — reach for `useState`/`useReducer`/Zustand. Server state is a remote snapshot that can be stale, is owned by many users, and persists across sessions — that is what React Query exists to manage. Don't force server state through `useState` + `useEffect`; that path leads to race conditions, duplicated data, and manual cache invalidation.

```tsx
// Server state -> React Query
const { data } = useQuery({ queryKey: ['pokemon', id], queryFn: () => getPokemon(id) })

// Client state -> useState
const [isModalOpen, setIsModalOpen] = useState(false)
```

**Anti-pattern:** hand-rolling fetch-in-`useEffect` + `useState` for loading/error, then lifting it to Context to share it. You end up re-implementing a buggy cache with no subscription granularity, no dedupe, and no invalidation.

## Create the QueryClient once, outside the component tree

The `QueryClient` owns the `QueryCache` (an in-memory Map). Instantiate it at module scope so it stays stable across re-renders — creating it inside a component would throw the cache away on every render.

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient()

export default function Root() {
  return (
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  )
}
```

**Anti-pattern:** `const queryClient = new QueryClient()` inside a component body (unless deliberately memoized with `useState(() => new QueryClient())` for SSR-per-request isolation).

## Import from `@tanstack/react-query`

The package is `@tanstack/react-query`, not the legacy `react-query`. The core is framework-agnostic; this is the React adapter. `QueryClientProvider` uses Context purely for dependency injection of the stable client — not for state distribution — so it never causes re-renders on its own.

## Always give useQuery a `queryKey` and a `queryFn`

The `queryKey` is the cache Map key (used for reads, dedupe, and invalidation) and must be globally unique. The `queryFn` must return a promise that resolves with the data to cache. Use the v5 object form.

```tsx
const { data } = useQuery({
  queryKey: ['pokemon', id],
  queryFn: () => fetch(`https://pokeapi.co/api/v2/pokemon/${id}`).then((res) => res.json()),
})
```

**Anti-pattern:** positional-argument form (`useQuery(key, fn)`) — removed in v5.

## Make query keys unique and serializable, and include every dependency

Because the key indexes the cache, anything the `queryFn` reads must appear in the key. Two queries with the same key share one cache entry; a key that omits a variable will serve stale data for the wrong input.

```tsx
// id is part of what we fetch, so it belongs in the key
useQuery({ queryKey: ['pokemon', id], queryFn: () => getPokemon(id) })
```

**Anti-pattern:** `queryKey: ['pokemon']` while fetching by `id` — every id collides on one cache slot.

## Wrap queries in custom hooks

Encapsulating a query behind a named hook turns complex async code into something that reads synchronously and is reusable across the app. Type inference flows through automatically — no manual annotation of the return type needed.

```tsx
function usePokemon(id: number) {
  return useQuery({
    queryKey: ['pokemon', id],
    queryFn: () => getPokemon(id), // returns Promise<Pokemon>
  })
} // inferred as UseQueryResult<Pokemon, Error>
```

## Rely on deduplication instead of lifting or prop-drilling shared data

Any number of components calling `useQuery` with the same `queryKey` — anywhere under the same provider — share one cache entry and one in-flight request. The `queryFn` only runs when there's no fresh value. Don't hoist fetched data into a parent or Context to "share" it; just call the same hook wherever you need it.

```tsx
// Both render from a single cache entry; queryFn runs at most once
<LuckyNumber />
<LuckyNumber />
```

## Never read `data` without handling the pending state

`data` is `undefined` until the promise resolves, so accessing it directly (e.g. `data.map(...)`) crashes on first render. Branch on query state first; TypeScript then narrows `data` to defined in the success path. The returned object is a discriminated union keyed on `status` / the boolean flags.

```tsx
const { data, isPending, isError } = useQuery({
  queryKey: ['mediaDevices'],
  queryFn: () => navigator.mediaDevices.enumerateDevices(),
})

if (isPending) return <Spinner />
if (isError) return <p>Unable to load devices</p>
return <ul>{data.map((d) => <li key={d.deviceId}>{d.label}</li>)}</ul>
```

**Anti-pattern:** `data.map(...)` with no guard — `Cannot read properties of undefined`.

## Use v5 names: `isPending`, `gcTime`, `status`

v5 renamed the loading-state flag to `isPending` (there is no `isLoading` as the primary flag) and the cache-retention option to `gcTime` (formerly `cacheTime`). The three statuses map to promise states: `pending` → pending, `success` → fulfilled, `error` → rejected. Pick `status` string checks *or* the derived `isPending`/`isSuccess`/`isError` booleans and stay consistent.

```tsx
const { status, data } = useQuery({ queryKey: ['x'], queryFn: getX })
if (status === 'pending') return <Spinner />
if (status === 'error') return <Error />
return <View data={data} />
```

## Understand `status` vs `fetchStatus` — they answer different questions

`status` describes whether you *have data* (`pending`/`success`/`error`). `fetchStatus` describes whether the `queryFn` is *currently running* (`fetching`/`paused`/`idle`). They are orthogonal: a query can be `success` while also `fetching` (a background refetch of already-cached data), or `pending` while `paused` (offline, waiting to run). Use `status` to decide what to render; use `fetchStatus` for background-activity indicators.

## Tune the lifecycle with `staleTime` and `gcTime` deliberately

Fresh data is served from cache with no refetch; once past `staleTime` it becomes stale and eligible for background refetch on triggers (mount, window focus, reconnect). `gcTime` controls how long an *unused* (no observers) cache entry lingers before garbage collection. `staleTime` defaults to `0` (everything immediately stale); raise it for data that doesn't change often to avoid needless refetches.

```tsx
useQuery({
  queryKey: ['config'],
  queryFn: getConfig,
  staleTime: 5 * 60 * 1000, // fresh for 5 min — no refetch on remount/focus
  gcTime: 10 * 60 * 1000,   // keep unused data 10 min before GC
})
```

**Mental model:** `staleTime` = "how long is this data trusted as fresh?"; `gcTime` = "how long do we keep it around after nobody's using it?". They are independent — `staleTime` governs refetching, `gcTime` governs memory eviction.

## Let the query lifecycle handle races — don't manually cancel effects

The classic `useEffect` + `ignore`-flag dance exists only to defeat race conditions from overlapping fetches. React Query eliminates that entire class of bug: keyed caching plus observers guarantee each component renders exactly what's in the cache for its key, in order. Deleting hand-rolled fetch effects is a feature, not a regression.
