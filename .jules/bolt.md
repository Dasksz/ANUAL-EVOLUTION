# 2026-03-27

### Bolt Optimization

- When aggregating massive monthly data chunks, parallel processing via `Promise.all` can cause significant database locking and CPU overload, resulting in statement timeouts from PostgREST.
- Switched parallel `supabase.rpc` execution to a sequential `await` execution model within a try/catch loop. This slightly increases client wait time but guarantees transaction completion by relieving the concurrent pressure on the PostgreSQL execution planner.

# 2025-05-15

### Bolt Optimization

- When processing heavy monthly data chunks in `src/js/app.js`, we found that pure sequential execution was too slow for large historical datasets.
- Implemented "Intra-Month Parallelism": The three 10-day chunks for a single month are now parallelized using `Promise.all`, while the months themselves remain sequential.
- Impact: This balances database throughput and prevents the statement timeouts encountered when parallelizing across multiple months simultaneously. Theoretical performance improvement of ~50% for the refresh process.
