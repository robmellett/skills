# Query Patterns Best Practices

## Prefer parallel queries over waterfalls

Independent resources have no reason to wait on each other. Fetch them concurrently so the user sees data as soon as possible, rather than serializing requests into an artificial waterfall. Simply calling `useQuery` more than once triggers the fetches simultaneously.

```tsx
function useRepos() {
  return useQuery({ queryKey: ['repos'], queryFn: fetchRepos })
}

function useMembers() {
  return useQuery({ queryKey: ['members'], queryFn: fetchMembers })
}

// Both fire in parallel; each renders as soon as it resolves.
```

## Only create a dependent-query waterfall when data genuinely depends on prior data

A waterfall is unavoidable when one request needs a value from another (e.g. a movie returns a `director` id you must then fetch). Model this by gating the second query with `enabled` on the presence of the input — do not fetch with an `undefined` argument.

```tsx
function useDirector(id?: number) {
  return useQuery({
    queryKey: ['director', id],
    queryFn: () => fetchDirector(id!),
    enabled: id !== undefined, // waits until the movie query yields an id
  })
}

function useMovieWithDirector(title: string) {
  const movie = useMovie(title)
  const director = useDirector(movie.data?.director)
  return { movie, director }
}
```

## Keep distinct entities in separate cache entries

Bundling two unrelated fetches into one `queryFn` (via `Promise.all`) couples them: they fetch and refetch together, error together, can't have independent `staleTime`, and — the worst part — get no request de-duplication or reuse elsewhere in the app. Cache each entity under its own `queryKey` so it can be shared and invalidated independently.

```tsx
// Anti-pattern: one key for two entities — no dedup, coupled error/refetch.
useQuery({
  queryKey: ['reposAndMembers'],
  queryFn: () => Promise.all([fetchRepos(), fetchMembers()]),
})
```

Only reach for the combined single-query form when you deliberately want one unified loading/error/data state and accept the loss of flexibility.

## Use `useQueries` for a dynamic number of parallel queries

When the number of queries isn't known at author time (e.g. fetch issues for every repo), map inputs to a `queries` array. This keeps each result cached under its own key while giving you one hook to derive aggregate values from. Guard against an undefined input with `?? []` so the array is always valid.

```tsx
function useIssues(repos?: Repo[]) {
  return useQueries({
    queries: repos?.map((repo) => ({
      queryKey: ['repos', repo.name, 'issues'],
      queryFn: async () => ({ repo: repo.name, issues: await fetchIssues(repo.name) }),
    })) ?? [],
  })
}
```

Derive aggregate state from the returned array, either with plain JavaScript or the built-in `combine` option:

```tsx
const queries = useIssues(repos.data)
const isPending = queries.some((q) => q.status === 'pending')
const totalIssues = queries
  .map(({ data }) => data?.issues.length ?? 0)
  .reduce((a, b) => a + b, 0)
```

## Extract shared query options with `queryOptions`

Factoring `queryKey`/`queryFn`/`staleTime` into a single definition lets you feed the exact same config to `useQuery`, `useQueries`, `prefetchQuery`, and `getQueryData`. Use the `queryOptions` helper (not a plain object) so options are type-checked — a misspelled `staleTime` on a plain object is silently ignored by TypeScript, and the returned `queryKey` carries the `queryFn`'s return type for type-safe cache reads.

```ts
import { queryOptions } from '@tanstack/react-query'

function getPostQueryOptions(path: string) {
  return queryOptions({
    queryKey: ['posts', path],
    queryFn: () => fetchPost(path),
    staleTime: 5000,
  })
}

const usePost = (path: string) => useQuery(getPostQueryOptions(path))
```

## Prefetch on intent to eliminate loading states

When a user signals interest (e.g. hovering a link), imperatively warm the cache with `queryClient.prefetchQuery` so the data is ready on navigation. `prefetchQuery` respects the query's `staleTime`, so give it one — otherwise every hover refires the request (default `staleTime` is `0`). Use `staleTime: Infinity` to prefetch only when nothing is cached.

```tsx
const queryClient = useQueryClient()

<a
  onMouseEnter={() => queryClient.prefetchQuery(getPostQueryOptions(post.path))}
  onClick={() => setPath(post.path)}
>
  {post.title}
</a>
```

Don't over-prefetch everything the user *might* need — that causes overfetching. Prefetch on a real signal (hover, or the next page of a paginated list).

## Never destructure the QueryClient

`QueryClient` is a class; pulling methods off it loses the `this` binding. Get it from `useQueryClient` and call methods on the instance.

```ts
const queryClient = useQueryClient()          // ✅
const { prefetchQuery } = useQueryClient()    // ❌ broken `this`
```

## Use `initialData` only when you have the complete, real record

`initialData` is written into the cache and treated as genuine data — React Query won't refetch until it goes stale. If you seed it with a partial record, the query treats the incomplete data as valid and the missing fields never load. Reserve it for cases where the seed is the full entity.

```tsx
// Only valid because the list entry IS a complete post record.
useQuery({
  ...getPostQueryOptions(path),
  initialData: () => queryClient.getQueryData<Post[]>(['posts'])
    ?.find((p) => p.path === path),
})
```

## Use `placeholderData` for partial or temporary stand-in data

Unlike `initialData`, `placeholderData` is **not** persisted to the cache — the `queryFn` still runs and the real data replaces it when it arrives. This is the right tool for showing a partial preview (e.g. title while the body loads). Branch UI on the `isPlaceholderData` flag to show a loading indicator over the placeholder.

```tsx
function usePost(path: string) {
  const queryClient = useQueryClient()
  return useQuery({
    ...getPostQueryOptions(path),
    placeholderData: () =>
      queryClient.getQueryData<Post[]>(['posts'])?.find((p) => p.path === path),
  })
}

const { data, isPlaceholderData } = usePost(path)
```

For TypeScript, model partial fields as optional (`body_markdown?: string`) so the placeholder shape conforms to the `queryFn` return type.

## Paginate by putting the page in the queryKey and keep the previous page visible

Include pagination params in the `queryKey` so each page caches separately and back/forward navigation is instant. In v5, pass `placeholderData: keepPreviousData` (imported from the package) — this replaces v4's `keepPreviousData: true` boolean. The previous page stays on screen while the next loads, avoiding a jarring layout shift.

```tsx
import { useQuery, keepPreviousData } from '@tanstack/react-query'

function useRepos(sort: string, page: number) {
  return useQuery({
    queryKey: ['repos', { sort, page }],
    queryFn: () => fetchRepos(sort, page),
    staleTime: 10_000,
    placeholderData: keepPreviousData,
  })
}
```

`placeholderData` also accepts a function receiving the previous data (`(previousData) => previousData`) if you need custom logic; `keepPreviousData` is the idiomatic shorthand.

## Drive pagination controls off `isPlaceholderData` and page-size heuristics

Disable navigation while a new page is in flight using `isPlaceholderData`, and dim the stale list for feedback. When the API gives no explicit "last page" flag, infer the end by checking whether a full page (`PAGE_SIZE` items) came back. Avoid magic numbers — export the page size as a constant shared by the fetcher and the UI.

```tsx
const { data, status, isPlaceholderData } = useRepos(sort, page)

<ul style={{ opacity: isPlaceholderData ? 0.5 : 1 }}>{/* ... */}</ul>
<button disabled={isPlaceholderData || page === 1} onClick={() => setPage((p) => p - 1)}>
  Previous
</button>
<button
  disabled={isPlaceholderData || data.length < PAGE_SIZE}
  onClick={() => setPage((p) => p + 1)}
>
  Next
</button>
```

For a polished feel, prefetch the next page in the background (in a `useEffect`) so "Next" resolves instantly.

## Use `useInfiniteQuery` for append-style lists, never a growing `useQuery`

`useQuery` only holds data for its current key, which fights against infinite lists that must accumulate. `useInfiniteQuery` keeps one cache entry and appends pages to it, managing the page param for you. In v5 it **requires** `initialPageParam`, and `getNextPageParam` should be fully typed. Return `undefined` from `getNextPageParam` to signal there are no more pages.

```tsx
function usePosts() {
  return useInfiniteQuery({
    queryKey: ['posts'],
    queryFn: ({ pageParam }) => fetchPosts(pageParam),
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages, lastPageParam) =>
      lastPage.length === 0 ? undefined : lastPageParam + 1,
  })
}
```

For cursor APIs, return the cursor the server sent — which means your `queryFn` must return that cursor as part of the page data:

```ts
getNextPageParam: (lastPage) => lastPage.nextCursor,
```

## Read infinite data from `data.pages` and drive the UI off the hook's flags

`useInfiniteQuery` returns data as `{ pages, pageParams }` — a page-per-entry array, not a flat list. Flatten with `Array.flat()` for rendering. Trigger loading with `fetchNextPage`, and gate the trigger on `hasNextPage` and `isFetchingNextPage` so you don't fire redundant requests or paginate past the end.

```tsx
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = usePosts()
const posts = data?.pages.flat() ?? []

<button
  onClick={() => fetchNextPage()}
  disabled={!hasNextPage || isFetchingNextPage}
>
  {isFetchingNextPage ? '...' : 'More'}
</button>
```

For true infinite scroll, fire `fetchNextPage` from an intersection observer on a sentinel element at the list's end rather than a button. Add `getPreviousPageParam` (with `firstPage`, `allPages`, `firstPageParam`) for bidirectional lists such as deep-linked message threads.

## Cap infinite caches with `maxPages`

Refetching an infinite query is all-or-nothing: React Query refetches from the first page and walks forward through every page to guarantee consistency (a partial refetch could duplicate or drop records when items are added/removed upstream). With many pages this is costly in network and memory. Set `maxPages` to bound how many pages are retained.

```tsx
useInfiniteQuery({
  queryKey: ['posts'],
  queryFn: ({ pageParam }) => fetchPosts(pageParam),
  initialPageParam: 1,
  getNextPageParam: (lastPage, _all, lastParam) =>
    lastPage.length === 0 ? undefined : lastParam + 1,
  maxPages: 3,
})
```
