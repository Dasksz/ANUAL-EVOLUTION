# 2026-03-27

### Bolt Optimization

- When aggregating massive monthly data chunks, parallel processing via `Promise.all` can cause significant database locking and CPU overload, resulting in statement timeouts from PostgREST.
- Switched parallel `supabase.rpc` execution to a sequential `await` execution model within a try/catch loop. This slightly increases client wait time but guarantees transaction completion by relieving the concurrent pressure on the PostgreSQL execution planner.

## 2025-03-28 - Optimize Large Array Spread Iterations
**Learning:** In heavily data-intensive scripts like `src/js/worker.js`, using the spread operator `[...a, ...b, ...c]` multiple times on large arrays inside the same function scope introduces an `O(N)` memory and time overhead for every invocation. This causes unnecessary massive array allocation and garbage collection cycles, just to iterate over the items once. Also, using `Array.prototype.concat` on large arrays is significantly faster (often 10x-15x faster) than creating a new array via spread.
**Action:** When a combined list of multiple arrays is needed for multiple iterations, pre-compute the combined array once using `.concat` and cache it in a constant variable (e.g., `const allArrays = a.concat(b, c);`) early in the pipeline, instead of performing inline spreading at every `forEach` loop.
2024-03-30: In PostgreSQL, when manually filtering sub-categories (like 1119_TODDYNHO) within a parent category (1119), ensure dynamic PL/pgSQL clauses do not universally append `OR codfor LIKE '1119_%'` to queries. If specific subcategories are targeted, strict matching (`= ANY(...)`) must be enforced to prevent broad inclusions that skew analytical metrics. Additionally, ensure correct string escaping (`'''`) is used during dynamic query construction in PL/pgSQL to avoid compilation errors.
