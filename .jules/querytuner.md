2024/11/01 - Optimize String Functions on Indexes
 Learning: Using `LTRIM(col, '0') IN ('X', 'Y')` causes full table scans or sequence scans rather than index lookups because the function alters the indexed column value.
 Action: Replaced `LTRIM(codfor, '0') IN ('707', '708', '752')` with `codfor IN ('707', '708', '752', '0707', '0708', '0752')` to enable index usage on `data_summary` and `data_detailed`/`data_history`.

2024/11/01 - Prevent Duplicate Scans
 Learning: When generating product aggregations in dynamic queries, redundant historical table scanning occurs when both current and previous years query `data_history` blindly.
 Action: Restricted the `data_history` branch in `prod_agg` CTE for `get_boxes_dashboard_data` to only use `v_previous_year` since `data_detailed` reliably handles the current year data.
2024/11/01 - Optimize String Functions on Indexes
 Learning: Using `LTRIM(col, '0') IN ('X', 'Y')` causes full table scans or sequence scans rather than index lookups because the function alters the indexed column value.
 Action: Replaced `LTRIM(codfor, '0') IN ('707', '708', '752')` with `codfor IN ('707', '708', '752', '0707', '0708', '0752')` to enable index usage on `data_summary` and `data_detailed`/`data_history`.

2024/11/01 - Prevent Duplicate Scans
 Learning: When generating product aggregations in dynamic queries, redundant historical table scanning occurs when both current and previous years query `data_history` blindly.
 Action: Restricted the `data_history` branch in `prod_agg` CTE for `get_boxes_dashboard_data` to only use `v_previous_year` since `data_detailed` reliably handles the current year data.
2024/11/01 - Optimize Date Functions on Indexes (get_boxes_dashboard_data)
 Learning: Using `EXTRACT(YEAR FROM dtped) = X` in WHERE clauses forces full table/sequential scans because it alters the indexed column before comparison, rendering B-Tree indexes useless.
 Action: Replaced `EXTRACT` logic with explicit SARGable ranges (`dtped >= make_date(X, 1, 1) AND dtped <= make_date(X, 12, 31)`) in `get_boxes_dashboard_data` CTEs (`kpi_curr`, `kpi_prev`, `prod_agg`). Also learned that replacing one placeholder (`%L`) with two in dynamic SQL requires duplicating the passed formatting variable.
## 2026-07-26 - Optimized `prod_agg` with Pre-Aggregation and Sargable Dates
 Learning: In `get_boxes_dashboard_data`, `prod_agg` was extracting raw sales for an entire year and joining `dim_produtos` *before* aggregation, scanning millions of rows. It also used `EXTRACT(MONTH FROM dtped) = X`, defeating `dtped` indexes.
 Action: Rewrote the `prod_agg` CTE to aggregate `data_detailed` and `data_history` first (into `prod_raw`), and only join `dim_produtos` at the final step. Replaced `EXTRACT` with Sargable date boundaries. This reduced execution time of `prod_agg` from ~663ms to ~132ms per branch query.

2026-08-01 - Optimize Stock Trend and Fix Missing FROM clause error
 Learning: When generating dynamic queries for different paths (e.g. FAST vs SLOW path), if table joins (like dim_produtos as dp) exist in one CTE but not another, pushing filters with explicit table aliases will cause "missing FROM-clause entry" errors on execution paths where the join is absent. Also, row-by-row division in aggregates using correlated subqueries can be severely bottlenecked.
 Action: Ensured both paths exposed the required joined columns (or removed specific prefixes when safe) to prevent runtime syntax errors with dynamic string filters. Pushed aggregate arithmetic (like division) outside the inner SUM(...) to operate only once per product rather than per raw sale record.
2026-08-02 - Optimize EXTRACT with IN operator
 Learning: Using `EXTRACT(YEAR FROM s.dtped)::int IN (Y1, Y2)` on massive timestamp tables causes the PostgreSQL query planner to bypass index range scans, forcing a full parallel sequential scan (e.g. ~1220ms).
 Action: Replaced the extraction and IN operator with a single continuous SARGable explicit boundary `(s.dtped >= make_date(Y2, 1, 1) AND s.dtped < make_date(Y1 + 1, 1, 1))`. This drops execution time to ~75ms by allowing an index Range Scan, and fixes bugs with midnight cutoff issues by using `< make_date` instead of `<= make_date`.

2024/09/20 - Optimize distinct lookup query
 Learning: When finding distinct relationships (like codusur mapped to codsupervisor) combined with a filter (like `nome = ANY(p_supervisor)`), doing `SELECT DISTINCT ... FROM massive_table` in a subquery BEFORE the JOIN forces PostgreSQL to parallel sequence scan and HashAggregate the entire massive table first (taking e.g. ~56ms+).
 Action: Replace unrestricted DISTINCT subqueries with a direct filter pushdown using an `IN` clause: `WHERE codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ...)`. This allows the planner to use existing indexes on `codsupervisor` in the massive table, dropping execution time to ~0.17ms.

2026-08-03 - Optimize Array/JSONB distinct aggregations by pushing DISTINCT into CTE
 Learning: In PostgreSQL, when aggregating large datasets with `jsonb_agg(DISTINCT col)` or `array_agg(DISTINCT col)`, if the query includes multiple aggregates or grouping, it can cause the query planner to perform extremely slow external merge sorts or memory-bound HashAggregates for each distinct calculation. Furthermore, inline `FILTER (WHERE col IS NOT NULL)` clauses on these aggregates often force slower GroupAggregates instead of HashAggregates.
 Action: Rewrote inline `json_agg(DISTINCT col)` to use a subquery pattern: `SELECT json_agg(col) FROM (SELECT DISTINCT col FROM ...)`. Additionally, for `jsonb_agg` applied to array elements in `get_presentation_dashboard_data`, pushed the DISTINCT down into the `FROM` subquery, which yielded measurable improvements.
2026-08-04 - Optimize FILTER WHERE on large aggregates
 Learning: In PostgreSQL, applying a `FILTER (WHERE ...)` clause on aggregate functions across large datasets (e.g. `COUNT(*) FILTER (WHERE sum_vlvenda >= 1)`) can severely degrade performance by forcing slow `GroupAggregate` and `Incremental Sort` operations.
 Action: Replace inline `FILTER` clauses with `COUNT(CASE WHEN cond THEN 1 END)` or `COUNT(DISTINCT CASE WHEN cond THEN col END)`. This mathematically equivalent structure allows the query planner to utilize significantly faster `HashAggregate` execution paths.
