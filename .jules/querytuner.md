2024/08/06 - Fix Foods Sub-brand Filter Mismatch

Learning: The summary tables (`data_summary_frequency`) already materialize `codfor` with mapped string values for specific sub-brands (e.g., `'1119_TODDYNHO'`). Using a query filter like `codfor = '1119' AND categorias_arr && ARRAY['TODDYNHO']` on the summarized views will always yield zero rows because `codfor` is strictly `'1119_TODDYNHO'`, not `'1119'`.
Action: Ensure frontend filters align precisely with the keys pre-calculated during the data materialization process (`clear_summary_month`).
2024/08/06 - Avoid overriding prod functions before validating shadow schema

Learning: The local sql schema file might use aliases or old table names (e.g. `dim_clientes` vs `data_clients`) that diverge from the live DB. Running massive replacements blindly can cause runtime HTTP exceptions in shadow tests.
Action: Test specifically patched live function schema strings during shadow runs rather than dropping in untested local chunks blindly.

## 2024-08-07 - N+1 LATERAL JOIN in 6-month sales trend aggregation
**Learning:** In `get_boxes_dashboard_data`, enriching a final JSON array with 6-month historical sales data using a `LEFT JOIN LATERAL` block evaluated the subqueries once per product (up to 1,000 times). While Postgres' planner can sometimes flatten this, relying on raw table queries inside the LATERAL join caused massive nested loop inefficiencies compared to evaluating the sales globally first.
**Action:** When joining aggregations across large sets of products against historical logs (`data_detailed`/`data_history`), materialize the aggregate using a CTE like `sales_6m` that pre-calculates grouped data for all products found in the target list at once, and join that pre-aggregated result set (e.g. `agg_sales_6m`) into the LATERAL or LEFT JOIN.
## 2026-08-17 - [Fix] Mismatched Virtual Key in Filter Cache
**Learning:** When using virtual or computed keys in an aggregated reporting table (like '1119_QUAKER' inside `cache_filters` instead of original code '1119'), dynamic filter SQL must query that exact string literal. Using the original base table logic (`codfor = '1119' AND categoria_produto = 'QUAKER'`) against the cache table results in 0 rows found.
**Action:** When debugging empty filters or datasets that work with some options but not others, verify that the string literals expected by the dynamic SQL condition match exactly how the pre-aggregated target cache table generates its keys. Also, when separating conditions for different target tables (like `cache_filters` vs `dim_produtos`), isolate their `WHERE` array appends (e.g. `v_conditions` vs `v_prod_conditions`) so you don't break one table's query when fixing the other.
