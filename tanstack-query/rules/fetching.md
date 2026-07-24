# Fetching & Synchronization Best Practices

## Put every `queryFn` input in the `queryKey`

The query key *is* your dependency array. React Query re-runs the `queryFn` when a value in the key changes, and it caches each key independently — so anything the `queryFn` reads must appear in the key or you'll serve stale/wrong data and lose per-parameter caching.

```ts
function useRepos(sort: string) {
  return useQuery({
    queryKey: ['repos', { sort }], // sort is used below, so it lives here
    queryFn: () => fetchRepos(sort),
  })
}
```

Anti-pattern — the `queryFn` uses `sort`, but the key never changes, so switching sort does nothing:

```ts
// ❌ queryKey missing sort — refetch never triggers, cache collides
useQuery({
  queryKey: ['repos'],
  queryFn: () => fetchRepos(sort),
})
```

## Drive refetches declaratively through the key, not imperatively

Calling `refetch()` from an event handler to react to changed inputs is the imperative escape hatch. Feed the input through the `queryKey` instead and let React Query refetch, cache, and de-race for you.

```tsx
// ❌ imperative
onChange={(e) => { setSort(e.target.value); refetch() }}

// ✅ declarative — key drives it
const { data } = useRepos(sort)
```

## Keys can hold objects and arrays — no referential stability needed

Unlike a `useEffect` dependency array, React Query hashes keys deterministically, so inline objects are fine and won't cause spurious refetches. Prefer a labeled object for parameters so the key stays self-documenting as it grows.

```ts
queryKey: ['repos', { sort, page, filters }] // hashed by value, not identity
```

## Enable the query lint rule to catch missing key dependencies

Tracking every `queryFn` input by hand gets error-prone as parameters accumulate. Install `@tanstack/eslint-plugin-query` and let `exhaustive-deps` flag anything used in the `queryFn` but absent from the key.

```
The following dependencies are missing in your queryKey: sort
  (@tanstack/query/exhaustive-deps)
```

## Throw in the `queryFn` on non-ok responses

`fetch` does *not* reject on 4xx/5xx — the promise resolves normally. React Query only marks a query as `error` when the `queryFn` throws, so you must check `response.ok` and throw yourself, or failures silently look like success.

```ts
queryFn: async () => {
  const response = await fetch('https://api.github.com/orgs/TanStack/repos')
  if (!response.ok) {
    throw new Error(`Request failed with status: ${response.status}`)
  }
  return response.json() // returning the promise is fine — RQ awaits it
}
```

Don't swallow the error with a local `try/catch` that returns `undefined` — that hides the failure from React Query and leaves `status` stuck.

## Pass the `AbortSignal` from the `queryFn` context to `fetch`

React Query hands the `queryFn` a context object containing a `signal`. Forward it to `fetch` so superseded or unmounted requests are cancelled instead of racing to completion.

```ts
queryFn: async ({ signal }) => {
  const response = await fetch(url, { signal })
  if (!response.ok) throw new Error(`Request failed: ${response.status}`)
  return response.json()
}
```

## Type the `queryFn` return, never the `useQuery` call site

`useQuery` has multiple type parameters; passing a generic to it wrecks inference for the others and leaves `data` weakly typed. Annotate the fetch function's return type (or assert on `response.json()`) so `data` flows through correctly.

```ts
// ✅ annotate the source of truth
async function fetchRepos(): Promise<Array<RepoData>> { /* ... */ }

// ❌ ruins inference for the other type params
useQuery<Array<RepoData>>({ queryKey, queryFn })
```

## Tune `staleTime` to match how fast the data changes

`staleTime` (default `0`) is the window during which data is served purely from cache with no refetch. The default is aggressive by design — refetching too often beats showing out-of-date data — but raise it for resources that change slowly to cut needless requests. It's the right knob for "fetch less often."

```ts
useQuery({
  queryKey: ['exchangeRates'],
  queryFn: fetchRates,
  staleTime: 60 * 60 * 1000, // updates daily — an hour fresh is fine
})
```

Set `staleTime: Infinity` only for data you're confident never changes within a session.

## Prefer raising `staleTime` over disabling refetch triggers

A stale query refetches in the background on four triggers: key change, a new observer mounting, window refocus, and network reconnect. These give great UX for free. If refetches feel too frequent, increase `staleTime` rather than switching the triggers off — you keep the nice behavior while controlling frequency.

```ts
// ✅ conservative but still resyncs when it matters
useQuery({ queryKey: ['repos'], queryFn: fetchRepos, staleTime: 30_000 })

// ⚠️ only when you truly want to opt out of a trigger
useQuery({
  queryKey: ['repos'],
  queryFn: fetchRepos,
  refetchOnWindowFocus: false,
  refetchOnMount: false,
  refetchOnReconnect: false,
})
```

Remember: refetch settings never affect *delivery* — cached data is always served instantly, fresh or not. `staleTime` only governs when the background resync happens.

## Use `enabled` for on-demand and dependent queries — never call `useQuery` conditionally

You can't wrap a hook in an `if`. To defer a fetch until an input exists (a search term, an id from another query), gate it with `enabled`.

```ts
function useIssues(search: string) {
  return useQuery({
    queryKey: ['issues', search],
    queryFn: () => fetchIssues(search),
    enabled: search !== '',
  })
}
```

Anti-pattern:

```ts
// ❌ breaks the rules of hooks
if (search) {
  return useQuery({ queryKey: ['issues', search], queryFn: ... })
}
```

## Use `skipToken` when `enabled` should also narrow types

`enabled: false` stops the fetch but does not narrow the input type, so TypeScript still sees `id` as possibly `undefined` inside the `queryFn`. Returning `skipToken` instead of a function disables the query *and* narrows the type without a `!`.

```ts
import { skipToken, useQuery } from '@tanstack/react-query'

function useIssue(id: number | undefined) {
  return useQuery({
    queryKey: ['issues', id],
    queryFn: id === undefined ? skipToken : () => fetchIssue(id), // id narrowed to number
  })
}
```

## Gate rendering on `status === 'success'`, not on the absence of loading/error

A `pending` status only means "no data in cache" — it does not mean fetching. A disabled query sits in `pending` + `idle`, so `isLoading` is `false` while `data` is still `undefined`. Never assume data exists just because you're not loading and not errored; check `success` explicitly.

```tsx
function IssueList({ search }: { search: string }) {
  const { data, status, isLoading } = useIssues(search)

  if (isLoading) return <div>...</div>              // pending AND fetching
  if (status === 'error') return <div>Error</div>
  if (status === 'success') {                       // only here is data guaranteed
    return <ul>{data.items.map((i) => <li key={i.id}>{i.title}</li>)}</ul>
  }
  return <div>Please enter a search term</div>      // pending + idle (disabled)
}
```

## Use `isLoading` (not `status === 'pending'`) for the loading spinner

`isLoading` is derived shorthand for `status === 'pending' && fetchStatus === 'fetching'` — data is genuinely on its way. `pending` alone is true even for a disabled query that isn't fetching, which would show a spinner before the user has done anything.

```ts
const { isLoading } = useIssues(search)
if (isLoading) return <div>...</div>
```

## Consider conditional rendering instead of `enabled` for on-demand fetches

`enabled` isn't the only tool. Moving the whole query into a child component and conditionally rendering that component is plain React — it drops the `enabled` flag and the extra `isLoading`/`success` guards, and can read cleaner when the query is only meaningful once mounted.

```tsx
{search ? <IssueResults search={search} /> : <p>Please enter a search term</p>}
```

## Set `gcTime` for how long *inactive* data should linger, not when data expires

`gcTime` (default 5 minutes) starts counting only once a query has *no observers* — i.e. after every component using it unmounts. Active queries are never garbage-collected. It controls memory retention of unused entries, which is a different concern from `staleTime` (freshness of shown data).

```ts
useQuery({
  queryKey: ['issues', search],
  queryFn: () => fetchIssues(search),
  staleTime: 5000, // how long data stays fresh (no refetch)
  gcTime: 3000,    // how long an unobserved entry survives before removal
})
```

Don't conflate the two: a short `gcTime` means returning to a previous search after the window elapsed shows a loading spinner again; `staleTime` only decides whether a still-cached entry refetches in the background.

## Use `refetchInterval` for polling data that must stay current regardless of triggers

When data must be periodically fresh independent of focus/mount/etc. (dashboards, live metrics), poll with `refetchInterval`. The timer is smart — it resets whenever another trigger or manual `refetch` updates the cache.

```ts
useQuery({
  queryKey: ['repos', { sort }],
  queryFn: () => fetchRepos(sort),
  refetchInterval: 5000, // re-run every 5s no matter what
})
```

## Use the function form of `refetchInterval` for conditional polling

To poll until a job completes, pass a function that inspects query state and returns `false` to stop. This avoids hammering an endpoint after the work it reports on has finished.

```ts
useQuery({
  queryKey: ['totalAmount'],
  queryFn: fetchTotalAmount,
  refetchInterval: (query) => {
    if (query.state.data?.finished) return false // stop polling
    return 3000                                  // otherwise keep going every 3s
  },
})
```
