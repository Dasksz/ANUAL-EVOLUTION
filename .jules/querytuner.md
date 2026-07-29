2024/07/28 - Fix Frequency and Mix Means
 Learning: Replaced `AVG()` inside CTE rollups with `SUM(num)/NULLIF(SUM(den), 0)` to fix a global "mean of means" bug that inflated distinct SKU metrics and frequency aggregates incorrectly in PostgreSQL and chunk-based UI state aggregators.
 Action: Fixed `get_frequency_table_data` and `get_main_dashboard_data` to return un-aggregated distinct metrics and properly weigh them on both DB and frontend client-side mergers.

2024/07/28 - Optimize Chronological Filtering
Learning: Using `EXTRACT(YEAR FROM date_col) = X` or `EXTRACT(YEAR FROM date_col) IN (X, Y)` forces PostgreSQL to evaluate the extraction function on every row, leading to slow Sequential Scans and ignoring indexes (like the BRIN or B-tree index on `dtped`).
Action: Always rewrite chronological filters to use bounding logic: `date_col >= make_date(X, 1, 1) AND date_col <= make_date(X, 12, 31)`. This allows the query planner to utilize `Index Scan` effectively, drastically reducing execution time (e.g. from 11ms to 0.08ms on a partition check, avoiding timeouts on massive tables).

2026/07/29 - Optimize get_boxes_dashboard_data Slow Path
Learning: Executing multiple queries with UNION ALL between large datasets (data_detailed, data_history) inside a single `EXECUTE format` statement forces PostgreSQL to scan the history table repeatedly.
Action: Restructured dynamic query generation to use a single `WITH base_data AS MATERIALIZED (...)` CTE, ensuring the database evaluates and stores the raw joined subset in memory first, reducing queries from timeouts (>600s) to ~1.5s execution.
