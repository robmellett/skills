---
name: tanstack-query
description: "Apply this skill whenever writing, reviewing, or refactoring TanStack Query (React Query v5) code. Triggers on useQuery/useMutation/useInfiniteQuery/useQueries, query keys and the QueryClient, staleTime vs gcTime, caching and invalidation, background refetching and polling, dependent and parallel queries, pagination and infinite scroll, optimistic updates, prefetching, error handling and retries, validating fetched data, offline support and persistence, Suspense, SSR/streaming hydration, WebSockets, and testing queries. Use when data fetching is done through fetch-in-useEffect that should move to React Query, and for React Query code review."
license: MIT
metadata:
  author: robmellett
  source: https://query.gg
---

# TanStack Query Best Practices

Best practices for **TanStack Query v5** (React Query), organized as an index of rule files. Each rule teaches what to do and why.

The one idea underneath every rule: **React Query is async state management, not a data-fetching library.** You hand it a promise; it manages the resulting *server state* — caching, deduplication, background sync, invalidation. Server state (remote, shared, can go stale) belongs to React Query; client state (local, synchronous, yours) belongs in `useState`. Don't reach for `useState` + `useEffect` to fetch — that reinvents a buggy cache with no dedupe or invalidation.

## Version

This skill targets **React Query v5** (`@tanstack/react-query` ≥ 5, imported from `@tanstack/react-query` — not the legacy `react-query` package). Confirm the installed version in `package.json` before applying version-sensitive rules. v5 specifics assumed throughout:

- The object form is the only call signature: `useQuery({ queryKey, queryFn })`.
- `isPending` (not `isLoading` as the primary flag), `gcTime` (not `cacheTime`).
- Pagination uses `placeholderData: keepPreviousData` (not the v4 `keepPreviousData: true` boolean).
- `useInfiniteQuery` requires `initialPageParam` and a typed `getNextPageParam`.
- `throwOnError` (not `useErrorBoundary`).

If the project is still on v4, the caching model and most patterns hold, but these names and signatures do not.

## Consistency First

Before applying any rule, check what the codebase already does. If queries already live in custom hooks, keys already come from a factory, the project already picked a `staleTime` policy or a single error-handling strategy — follow that. These rules are defaults for when no pattern exists yet, not overrides. Inconsistency is worse than a suboptimal pattern.

## How to Apply

1. Check sibling hooks, query key factories, and the installed React Query version for established patterns. Deviate only for a correctness defect, and call it out.
2. Map every affected concern to the rule index below. Read each mapped rule file before editing. Skip unrelated ones.
3. Keep the query key the single source of truth for a query's dependencies — every input the `queryFn` reads belongs in the key.
4. Wrap each query/mutation in a named custom hook; make the `queryFn` throw on failure and (for untrusted APIs) validate its data.
5. Make the smallest coherent change; don't introduce a second way to fetch or invalidate the same data.
6. Re-read the diff against every mapped rule before finishing.

## Rule Index

Cross-cutting changes often need more than one rule file.

| Concern | Read |
| --- | --- |
| QueryClient setup, `useQuery`, query keys, deduplication, the lifecycle (`staleTime`/`gcTime`, `status` vs `fetchStatus`, `isPending`) | [`rules/foundations.md`](rules/foundations.md) |
| Writing `queryFn`s (throwing, `AbortSignal`), keys as dependencies, background sync & refetch triggers, `enabled`/`skipToken`, garbage collection, polling | [`rules/fetching.md`](rules/fetching.md) |
| Dependent & parallel queries, `useQueries`, prefetching, `initialData` vs `placeholderData`, pagination, `useInfiniteQuery` | [`rules/query-patterns.md`](rules/query-patterns.md) |
| `useMutation`, `invalidateQueries`, the full optimistic-update pattern, `mutate` vs `mutateAsync`, callback scoping | [`rules/mutations.md`](rules/mutations.md) |
| `defaultOptions`, query key & query factories (`queryOptions`), `select`, tracked properties, re-render performance | [`rules/configuration.md`](rules/configuration.md) |
| Error handling (`throwOnError` + boundaries, retries, global `onError`), validating data, offline `networkMode`, persistence, custom adapters | [`rules/robustness.md`](rules/robustness.md) |
| Testing queries/mutations (fresh client, MSW), `useSuspenseQuery`, SSR & streaming hydration, WebSockets | [`rules/testing-and-rendering.md`](rules/testing-and-rendering.md) |

## Review Checklist

- Is server state managed by React Query rather than hand-rolled `useState` + `useEffect` fetching?
- Is the `QueryClient` created once outside the component tree (or per-request with a ref for SSR), never rebuilt each render?
- Does every input the `queryFn` reads appear in the `queryKey`? (Enable `@tanstack/eslint-plugin-query`'s `exhaustive-deps`.)
- Does the `queryFn` throw on non-ok responses and forward the `AbortSignal`, rather than swallowing errors?
- Are query keys built from a per-feature factory with a hierarchy, not re-typed inline — so invalidation can target them fuzzily?
- Is `staleTime` tuned to how fast the data changes, rather than disabling refetch triggers?
- Do optimistic updates run the full cancel → snapshot → write → rollback-on-error → invalidate-on-settled sequence?
- Is `data` read only after `status === 'success'` (or via `useSuspenseQuery`), never assumed present just because loading is false?
- Is the `useQuery` result not rest-destructured (`...rest`), preserving tracked-property re-render optimization?
- Do tests use a fresh `QueryClient` with `retry: false` and mock at the network layer (MSW), not by mocking `useQuery`?
