2024/08/06 - Fix Foods Sub-brand Filter Mismatch

Learning: The summary tables (`data_summary_frequency`) already materialize `codfor` with mapped string values for specific sub-brands (e.g., `'1119_TODDYNHO'`). Using a query filter like `codfor = '1119' AND categorias_arr && ARRAY['TODDYNHO']` on the summarized views will always yield zero rows because `codfor` is strictly `'1119_TODDYNHO'`, not `'1119'`.
Action: Ensure frontend filters align precisely with the keys pre-calculated during the data materialization process (`clear_summary_month`).
2024/08/06 - Avoid overriding prod functions before validating shadow schema

Learning: The local sql schema file might use aliases or old table names (e.g. `dim_clientes` vs `data_clients`) that diverge from the live DB. Running massive replacements blindly can cause runtime HTTP exceptions in shadow tests.
Action: Test specifically patched live function schema strings during shadow runs rather than dropping in untested local chunks blindly.
