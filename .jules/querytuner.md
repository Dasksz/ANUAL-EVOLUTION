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
## 2026-07-31 - Title
 Learning: Massive join operations on raw event tables before aggregation leads to devastating performance drops (statement timeouts) due to memory/disk spills in hash aggregates.
 Action: Apply pre-aggregation strategies (grouping by target dimension before left joining metadata/dim tables) in CTEs. Convert EXTRACT date clauses to SARGable constraints (make_date intervals).
