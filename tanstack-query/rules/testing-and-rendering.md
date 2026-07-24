# Testing & Rendering Best Practices

## Test each component with a fresh QueryClient per test

A shared client leaks cache and observers between tests, causing order-dependent flakiness. Create the client inside a render helper so every test (and every `render`) gets an isolated cache.

```tsx
function renderWithClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>
  )
}
```

**Anti-pattern:** a single module-level `const queryClient = new QueryClient()` reused across the whole test file.

## Turn off retries in tests

The default 3 retries with backoff makes error-path tests wait seconds for a failure that will never succeed, and makes them slow and flaky. Disable retries on the test client's `defaultOptions`.

```ts
new QueryClient({ defaultOptions: { queries: { retry: false } } })
```

Set it as a default (not per-`useQuery`) so it applies everywhere, and remember `defaultOptions` are ignored wherever a call site overrides the same option.

## Test the component, not the hook in isolation

Hooks like `usePosts` are implementation details; users interact with rendered UI. Testing the component that consumes the hook (with the network mocked) exercises the real loading/success/error behavior your users see.

```tsx
test('shows posts', async () => {
  const { findByRole } = renderWithClient(<Blog />)
  expect(await findByRole('link', { name: '1st Post' })).toBeInTheDocument()
})
```

## Read the client from context, never import the production one

`useQueryClient()` resolves to the nearest provider, so a test provider transparently swaps in the test client. Importing a shared production `QueryClient` singleton directly into components makes it impossible to inject a test client.

```ts
const queryClient = useQueryClient() // resolves the test client under test
```

## Mock the network with MSW, not by mocking useQuery

Intercepting at the network layer keeps the real React Query machinery (caching, invalidation, retries, status transitions) under test, and lets you script status codes, latency, and per-test overrides. Mocking `useQuery` itself forces you to hand-fabricate a brittle, partial `QueryResult`.

```ts
const server = setupServer(
  http.get('*/api/articles', () => HttpResponse.json([{ id: 1, title: '1st Post' }]))
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

**Anti-pattern:**

```ts
vi.mock('@tanstack/react-query', () => ({ useQuery: () => ({ status: 'success', data: [...] }) }))
```

## Override handlers per test for error and mutation scenarios

`server.use(...)` layers a runtime handler that `resetHandlers()` clears afterward, so one test can return a 500 without polluting others. Use `.once()` to model a mutation that changes what a subsequent refetch returns.

```ts
// error path
server.use(http.get('*/api/articles', () => new HttpResponse(null, { status: 500 })))

// mutation + invalidation: next GET returns the new item exactly once
server.use(
  http.get('/todos/list', () =>
    HttpResponse.json([...existing, { id: '3', title: 'hello', done: false }], { once: true })
  )
)
```

Static handlers that always return the same list will fail an invalidation test because the refetch yields unchanged data.

## Seed the cache for data sources you can't mock over the network

For async browser APIs (e.g. `navigator.mediaDevices`) there's no request to intercept. Pre-populate the cache with `setQueryData` before rendering and set a high `staleTime` so no refetch fires and the `queryFn` never runs.

```ts
const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, staleTime: Infinity } },
})
queryClient.setQueryData(['mediaDevices'], [{ deviceId: 'id1' }, { deviceId: 'id2' }])
```

Trade-off: because the cache is warm, the query never enters `pending`, so you cannot assert a loading state — and a broken `queryFn` won't be caught.

## Use `findBy*` to await async query results

Query resolution is asynchronous, so synchronous `getBy*` queries run before data arrives and fail. `findBy*` returns a promise that retries until the element appears (or times out), which is the assertion equivalent of `waitFor`.

```ts
expect(await findByText('...')).toBeInTheDocument()          // loading
expect(await findByRole('heading', { name: '1st Post' })).toBeInTheDocument() // resolved
```

## Reach for `useSuspenseQuery` when a Suspense/error boundary owns the states

With `useSuspenseQuery`, `data` is guaranteed defined at render time and errors are thrown to the nearest error boundary, so the component carries no loading/error branches. This lifts loading UI to a higher-level, reusable boundary instead of coupling it to each component.

```tsx
function Repo({ name }: { name: string }) {
  const { data } = useSuspenseQuery(repoDataQuery(name)) // data is defined, typed non-nullable
  return <h1>{data.name}</h1>
}

<AppErrorBoundary>
  <Suspense fallback={<Loading />}>
    <Repo name="tanstack/query" />
  </Suspense>
</AppErrorBoundary>
```

**Anti-pattern:** keeping an `if (isPending)` / `if (status === 'pending')` branch inside a `useSuspenseQuery` component — it's dead code, and there is no `isPending`-style guard to write.

## One suspense query per component, or batch with `useSuspenseQueries`

A component suspends as a whole the moment it requests one resource, so two sequential `useSuspenseQuery` calls in the same component run as a waterfall (suspend, resume, suspend again). Split into separate components under the boundary, or fetch them in parallel with `useSuspenseQueries`.

```tsx
const [repo, table] = useSuspenseQueries({
  queries: [repoDataQuery('tanstack/query'), repoDataQuery('tanstack/table')],
})
```

## Don't reach for `enabled` or `placeholderData` under Suspense

`useSuspenseQuery` supports neither, by design: `enabled` would break the guarantee that `data` is always present, and `placeholderData` is redundant when the boundary's `fallback` already covers the wait. Dependent queries "just work" because same-component suspense queries run in series.

```tsx
// dependent data: no `enabled` needed — the second call suspends until the first resolves
const { data: movie } = useSuspenseQuery(movieQuery(title))
const { data: director } = useSuspenseQuery(directorQuery(movie.directorId))
```

## Keep previous page visible with `useTransition`, not `placeholderData`

Since Suspense drops `placeholderData`, wrap the state update that triggers a new fetch in `startTransition`. React then keeps the old content mounted (instead of unmounting to show the fallback) until the new data is ready, and `isPending` gives you the "stale" flag.

```tsx
const { data } = useRepos(sort, page) // useSuspenseQuery under the hood
const [isPending, startTransition] = React.useTransition()

<ul style={{ opacity: isPending ? 0.5 : 1 }}>{/* rows */}</ul>
<button
  disabled={isPending || page === 1}
  onClick={() => startTransition(() => setPage((p) => p - 1))}
>
  Previous
</button>
```

## Prefetch above the boundary to render-as-you-fetch, not fetch-on-render

Firing the request only when the component renders creates a request waterfall. Kick off the fetch as early as possible — a route loader, an event handler, a server component, or `usePrefetchQuery` above the suspense boundary in a client-only app.

```tsx
function App() {
  usePrefetchQuery(repoDataQuery('tanstack/query'))
  return (
    <Suspense fallback={<p>...</p>}>
      <RepoData name="tanstack/query" />
    </Suspense>
  )
}
```

Share one query-options factory (e.g. `repoDataQuery(name)`) between the prefetch and the `useSuspenseQuery` so keys and `queryFn` can't drift apart.

## For SSR, prefetch on the server and hand off with `dehydrate` + `HydrationBoundary`

Create a per-request `QueryClient`, `prefetchQuery` into it, then serialize with `dehydrate` and rehydrate on the client via `HydrationBoundary`. Unlike `initialData`, the hydrated cache also feeds subsequent background revalidations, so every consumer always sees the freshest server or client data.

```tsx
// app/page.tsx (Server Component)
import { QueryClient, dehydrate, HydrationBoundary } from '@tanstack/react-query'

export default async function Home() {
  const queryClient = new QueryClient()
  await queryClient.prefetchQuery({
    queryKey: ['repoData'],
    queryFn: fetchRepoData,
    staleTime: 10 * 1000,
  })

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <Repo />
    </HydrationBoundary>
  )
}
```

A bonus of `prefetchQuery`: the server code never touches the resolved data, so it can't introduce a server/client mismatch.

## Prefer hydration over `initialData` for dynamically rendered pages

`initialData` only seeds a cache entry the first time it's created, so on dynamically rendered requests a changed prop won't update an existing entry (same trap as `useState(initialValue)`). Reserve `initialData` for statically generated pages; use `dehydrate`/`HydrationBoundary` when the server renders per request.

```tsx
// fine for SSG only:
useQuery({ queryKey: ['repoData'], queryFn: fetchRepoData, initialData })
```

## Create the client per request, and stabilize it with a ref in client providers

Sharing one `QueryClient` across requests leaks one user's data to another on the server. In a `'use client'` provider, store the client in a ref so React doesn't recreate it on every render; a server component can create it inline since it never re-renders.

```tsx
'use client'
export default function Providers({ children }: { children: React.ReactNode }) {
  const ref = React.useRef<QueryClient>()
  if (!ref.current) ref.current = new QueryClient()
  return <QueryClientProvider client={ref.current}>{children}</QueryClientProvider>
}
```

## Stream by not awaiting the prefetch, then suspend per section

Awaiting `prefetchQuery` blocks the whole tree until data arrives, hiding even data-independent UI. Kick off the prefetch without `await`, switch the consumer to `useSuspenseQuery`, and wrap it in its own `Suspense` so the shell streams immediately and the data-dependent chunk streams in later.

```tsx
export default async function Home() {
  const queryClient = new QueryClient({
    defaultOptions: {
      dehydrate: {
        // include pending queries so the in-flight promise is streamed, not just settled data
        shouldDehydrateQuery: (q) =>
          defaultShouldDehydrateQuery(q) || q.state.status === 'pending',
      },
    },
  })

  queryClient.prefetchQuery({ queryKey: ['repoData'], queryFn: fetchRepoData }) // no await

  return (
    <main>
      <Navbar />
      <HydrationBoundary state={dehydrate(queryClient)}>
        <Suspense fallback={<RepoSkeleton />}>
          <Repo />
        </Suspense>
      </HydrationBoundary>
      <Footer />
    </main>
  )
}
```

The dehydrated state now carries a `Promise`; React Query reuses that server-created promise on the client instead of refetching, so data lands as early as possible.

## Drop the hydration boilerplate with the experimental streamed-hydration plugin

`@tanstack/react-query-next-experimental`'s `ReactQueryStreamedHydration` transfers server-fetched data into the client cache automatically, so you can call `useSuspenseQuery` in client components with no `dehydrate`/`HydrationBoundary` wiring per page. Note it is explicitly experimental and Next.js-specific.

```tsx
'use client'
import { ReactQueryStreamedHydration } from '@tanstack/react-query-next-experimental'

<QueryClientProvider client={ref.current}>
  <ReactQueryStreamedHydration>{children}</ReactQueryStreamedHydration>
</QueryClientProvider>
```

## Push realtime WebSocket messages into the cache instead of polling

Polling and `staleTime` are only guesses about freshness; a WebSocket tells you exactly when data changed. Subscribe in an effect and either write the payload directly with `setQueryData` (when the message carries the new data) or `invalidateQueries` to trigger a refetch (when it doesn't).

```tsx
function useWebsocketQueryInvalidate() {
  const queryClient = useQueryClient()
  React.useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const queryKey = JSON.parse(event.data)
      queryClient.invalidateQueries({ queryKey })
      // or, if the server sends the data:
      // queryClient.setQueryData(queryKey, payload)
    }
    ws.addEventListener('message', handleMessage)
    return () => ws.removeEventListener('message', handleMessage)
  }, [queryClient])
}
```

Include `queryClient` in the effect deps and always return the `removeEventListener` cleanup so subscriptions don't leak or duplicate.

## Set `staleTime: Infinity` when the socket is the sole source of truth

If a live connection drives every update, background refetching is redundant work. Set `staleTime: Infinity` so the cache changes only when the socket pushes an invalidation or new data.

```tsx
useQuery({ queryKey: ['todos'], queryFn: fetchTodos, staleTime: Infinity })
```
