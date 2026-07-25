## 2024/05/27 - Chart query optimization
Learning: GroupAggregate speed heavily degrades when applying `FILTER (WHERE ...)` against a column that isn't the primary group key on large datasets. Incremental sort has to retain too many non-matching rows during scanning.
Action: If a CTE or aggregation query applies a global `FILTER (WHERE ...)` across all calculated metrics, move that condition directly into the global `WHERE` clause instead so the index can scan `Index Only` skipping the rows completely.
