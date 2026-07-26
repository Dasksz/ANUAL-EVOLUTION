## 2024/05/27 - Chart query optimization
Learning: GroupAggregate speed heavily degrades when applying `FILTER (WHERE ...)` against a column that isn't the primary group key on large datasets. Incremental sort has to retain too many non-matching rows during scanning.
Action: If a CTE or aggregation query applies a global `FILTER (WHERE ...)` across all calculated metrics, move that condition directly into the global `WHERE` clause instead so the index can scan `Index Only` skipping the rows completely.

## 2025/07/25 - Missing compound index on frequently filtered JSON aggregations
Learning: Building large dynamic JSON aggregations (like `get_dashboard_filters_optimized` or `get_dashboard_filters`) heavily degraded performance when filtering by year but missing compound indexes for the selected columns (e.g., `categoria_produto`). This forces Postgres to use sequential scans and slow memory sorts to find distinct values.
Action: Add compound indexes (e.g., `idx_cache_ano_categoria ON cache_filters (ano, categoria_produto)`) matching the query's primary filter key and the target column to enable Index Only Scans, reducing execution time significantly.

## 2025/07/25 - Inline JSON/Array aggregations with DISTINCT cause massive sorts
Learning: Constructing dynamic JSON or Array aggregations using `json_agg(DISTINCT jsonb_build_object(...))` or `array_agg(DISTINCT ...)` directly against large tables severely degrades performance. PostgreSQL evaluates the object/array build on every single row first, forcing massive and slow disk/memory sorts to find distinct combinations. 
Action: Transform the query to push the `DISTINCT` evaluation down into a subquery first. Aggregate the already deduplicated results using `SELECT json_agg(...) FROM (SELECT DISTINCT ... FROM ...) sub`. This leverages fast HashAggregates on raw columns before the more expensive object construction.

## 2025/07/26 - Window function vs DISTINCT ON for Top-N per group
Learning: Using `ROW_NUMBER() OVER(PARTITION BY ... ORDER BY ...)` inside a CTE just to filter `WHERE rn = 1` forces a heavy WindowAgg and large external disk sorts on massive tables (like `data_summary_frequency`).
Action: For finding the single latest/top row per group, rewrite the query to use PostgreSQL's native `DISTINCT ON (...)` combined with `ORDER BY`. This allows the planner to eliminate the WindowAgg entirely, resolving the data in a single pass and speeding up queries significantly (e.g., from ~4.7s down to ~600ms).

2024/05/23 - Heavy ROW_NUMBER() mapped to Index Only Scan
Learning: Identifying mapping attributes (like `codusur` to `codsupervisor`) via heavy `ROW_NUMBER() OVER(PARTITION BY...)` across raw fact tables (`data_detailed`, `data_history`) forces huge disk sorts taking ~6.6s.
Action: By extracting the same mapping pairs (`DISTINCT codusur, codsupervisor`) from the already aggregated/indexed table (`data_summary_frequency`), PostgreSQL can utilize an Index Only Scan (`idx_dat_summary_freq_vendedor_supervisor`), dropping execution time to ~170ms (38x faster). Applied to `get_estrelas_kpis_data`, `get_main_dashboard_data`, and `get_innovations_data`.

## 2024/05/27 - Window function vs DISTINCT ON for Top-N per group in data retrieval
Learning: Using `ROW_NUMBER() OVER(PARTITION BY ... ORDER BY ...)` inside a CTE just to filter `WHERE rn = 1` forces a heavy WindowAgg and large external disk sorts on massive tables (like `data_summary_frequency`), which can take upwards of ~300ms.
Action: For finding the single latest/top row per group, rewrite the query to use PostgreSQL's native `DISTINCT ON (...)` combined with `ORDER BY`. This allows the planner to eliminate the WindowAgg entirely, resolving the data in a single pass using sorting. In `search_loja_perfeita_clients`, this improved performance significantly.
