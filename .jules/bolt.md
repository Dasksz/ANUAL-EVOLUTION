## 2024-04-13 - Optimize Supabase Dynamic SQL Timeouts
**Learning:**
Heavy analytical queries with `COUNT(DISTINCT)` over large datasets (like `data_summary_frequency`) often timeout if they unconditionally perform `INNER JOIN` operations with dimension tables or excessive `CROSS JOIN LATERAL` JSONB unnesting. In Supabase RPCs returning dynamic SQL (e.g., `get_frequency_table_data`), these timeouts are particularly evident when the dashboard loads with no filters (full-year scope). Furthermore, performing `LEFT JOIN` on massive fact tables against large dimension tables before filtering significantly degrades performance (e.g., `get_mix_salty_foods_data`).

**Action:**
1. Dynamically constructed CTEs in PL/PGSQL to conditionally bypass heavy joins. In `get_frequency_table_data`, the `INNER JOIN public.dim_produtos` is bypassed when `v_where_unnested` is empty, significantly accelerating the unnested `jsonb_array_elements_text` distinct counts.
2. In `get_mix_salty_foods_data`, replaced a deferred `LEFT JOIN` with a preemptive `INNER JOIN` against a pre-filtered `dim_produtos` CTE (`WHERE mix_marca IS NOT NULL AND mix_marca != ''`). This acts as an early data pruner, dropping over 90% of irrelevant rows before expensive multi-column aggregations.
