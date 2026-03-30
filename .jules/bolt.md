# 2026-03-27

### Bolt Optimization

- When aggregating massive monthly data chunks, parallel processing via `Promise.all` can cause significant database locking and CPU overload, resulting in statement timeouts from PostgREST.
- Switched parallel `supabase.rpc` execution to a sequential `await` execution model within a try/catch loop. This slightly increases client wait time but guarantees transaction completion by relieving the concurrent pressure on the PostgreSQL execution planner.

## $(date +%Y-%m-%d) - Optimize Dropdown Filtering and DOM Batching
**Learning:** During array filtering and sorting for multi-select dropdown UI components (`setupBranchMultiSelect`, `setupBranchFilialSelect`), performing repeated lookups with `Array.includes()` across a potentially large state array inside tight loop/sort functions scales with an O(N^2) or O(M*N log N) time complexity constraint. Also, rendering new elements individually with `appendChild` inside loops creates excessive DOM repaints.
**Action:** Extract large state arrays into a `Set` immediately prior to iteration or sort operations, achieving O(1) membership lookups. In addition, attach newly generated elements to a `DocumentFragment` inside the loop, and apply the fragment to the main DOM node exactly once after loop termination to optimize layout recalculations.
