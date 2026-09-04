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
2024/08/22 - Defer dimension joins in dynamic SQL FAST PATHs
Learning: Using a LEFT JOIN to a dimension table (like dim_produtos) on massive fact tables (data_detailed) solely to support optional dynamic WHERE filters (like categoria_produto) forces the query planner to evaluate the join for millions of rows even when the filter is not applied.
Action: Remove the LEFT JOIN from the heavy aggregation step. Instead, build the dynamic filter string using an IN (SELECT ...) subquery. This allows Postgres to use an efficient semi-join when filtering, and avoids the join overhead entirely when no filter is provided.
## 2025-08-25 - Show all products with stock even if zero sales
 **Learning:** When building list of products (like for "Top Produtos por Caixas" table) matching specific filters, and you need to show products that have 0 sales but have active stock, you cannot aggregate solely over sales history. You must `LEFT JOIN` the sales data onto the full list of products (`dim_produtos`) filtered properly.
 **Action:** We modified `get_boxes_dashboard_data` to first filter `dim_produtos` dynamically based on the dashboard filters, then `LEFT JOIN` the sales `prod_raw` results, and finally added a `HAVING`/`WHERE` condition to only include those matching `(total_qtvenda > 0 OR faturamento > 0 OR estoque > 0)`.
2026/08/25 - Ensure logical parity between targets (Metas) and actuals (Realizado) definitions
Learning: When aggregating goals (metas) for custom KPIs like Mix Foods, verify the frontend import structure directly. In this project, targets are mapped as metrica='MIX' and categoria='mix_foods', whereas the older SQL searched for metrica='POS' and categoria='total_foods', yielding zeros.
Action: Always map SQL Target filter variables exactly to how they are inserted into the system, and map SQL Realized variables (has_foods) precisely to the same rules used elsewhere (e.g. dashboard 4-family rules) to prevent data visualization mismatches.

## 2024-05-18 - [City View Category Ranking]
 **Learning:** When rendering category rankings filtered by dynamic conditions, using a FULL OUTER JOIN with a separate list of distinct dimensions allows rows with 0 metrics to appear in the result set rather than being implicitly removed by inner joins/aggregations.
 **Action:** For "show all zero" metric lists, derive a CTE (`all_cats`) from the dimension table (`dim_produtos`) filtered by the exact dimensions being queried, then `FULL OUTER JOIN` it with the aggregation CTE.

## 2024-10-24 - Defer string dimensions from massive CTE aggregations
 **Learning:** In heavy PostgreSQL reporting queries, such as `get_city_view_data`, using non-grouping aggregate functions like `MAX(cidade)` on string dimensions during the main aggregation step forces the database engine to perform expensive string operations and sort operations on large datasets (like `data_summary`), significantly increasing memory footprint and execution time.
 **Action:** Remove the dimension lookup from the heavy aggregation step (e.g., leaving only `codcli` and `SUM(vlvenda)`). Fetch the dimension during the final output phase (e.g., pagination or formatting) by joining the much smaller, aggregated result set back to the dimension tables (e.g., `data_clients` to fetch `c.cidade`).
