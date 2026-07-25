## 2024/05/27 - Chart query optimization
Learning: GroupAggregate speed heavily degrades when applying `FILTER (WHERE ...)` against a column that isn't the primary group key on large datasets. Incremental sort has to retain too many non-matching rows during scanning.
Action: If a CTE or aggregation query applies a global `FILTER (WHERE ...)` across all calculated metrics, move that condition directly into the global `WHERE` clause instead so the index can scan `Index Only` skipping the rows completely.

## 2025/07/25 - Missing compound index on frequently filtered JSON aggregations
Learning: Building large dynamic JSON aggregations (like `get_dashboard_filters_optimized` or `get_dashboard_filters`) heavily degraded performance when filtering by year but missing compound indexes for the selected columns (e.g., `categoria_produto`). This forces Postgres to use sequential scans and slow memory sorts to find distinct values.
Action: Add compound indexes (e.g., `idx_cache_ano_categoria ON cache_filters (ano, categoria_produto)`) matching the query's primary filter key and the target column to enable Index Only Scans, reducing execution time significantly.
