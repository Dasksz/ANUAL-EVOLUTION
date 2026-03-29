# 2026-03-27

### Bolt Optimization

- When aggregating massive monthly data chunks, parallel processing via `Promise.all` can cause significant database locking and CPU overload, resulting in statement timeouts from PostgREST.
- Switched parallel `supabase.rpc` execution to a sequential `await` execution model within a try/catch loop. This slightly increases client wait time but guarantees transaction completion by relieving the concurrent pressure on the PostgreSQL execution planner.

## 2026-03-29 - Array Spread vs Concat Memory Optimization
**Learning:** In heavily data-intensive scripts (like Web Workers processing thousands of rows), using the array spread operator (`[...a, ...b, ...c]`) inside loops or multiple times within the same scope creates massive O(N) memory allocation overhead and triggers frequent garbage collection pauses.
**Action:** Instead, pre-compute combined arrays once using `Array.prototype.concat()` or replace repeated inline spread operators with a single pre-computed array reference to optimize performance and significantly lower the memory footprint.
