2024/08/06 - Fix Foods Sub-brand Filter Mismatch

Learning: The summary tables (`data_summary_frequency`) already materialize `codfor` with mapped string values for specific sub-brands (e.g., `'1119_TODDYNHO'`). Using a query filter like `codfor = '1119' AND categorias_arr && ARRAY['TODDYNHO']` on the summarized views will always yield zero rows because `codfor` is strictly `'1119_TODDYNHO'`, not `'1119'`.
Action: Ensure frontend filters align precisely with the keys pre-calculated during the data materialization process (`clear_summary_month`).
2024/08/06 - Avoid overriding prod functions before validating shadow schema

Learning: The local sql schema file might use aliases or old table names (e.g. `dim_clientes` vs `data_clients`) that diverge from the live DB. Running massive replacements blindly can cause runtime HTTP exceptions in shadow tests.
Action: Test specifically patched live function schema strings during shadow runs rather than dropping in untested local chunks blindly.

## 2024-08-07 - N+1 LATERAL JOIN in 6-month sales trend aggregation
**Learning:** In `get_boxes_dashboard_data`, enriching a final JSON array with 6-month historical sales data using a `LEFT JOIN LATERAL` block evaluated the subqueries once per product (up to 1,000 times). While Postgres' planner can sometimes flatten this, relying on raw table queries inside the LATERAL join caused massive nested loop inefficiencies compared to evaluating the sales globally first.
**Action:** When joining aggregations across large sets of products against historical logs (`data_detailed`/`data_history`), materialize the aggregate using a CTE like `sales_6m` that pre-calculates grouped data for all products found in the target list at once, and join that pre-aggregated result set (e.g. `agg_sales_6m`) into the LATERAL or LEFT JOIN.
