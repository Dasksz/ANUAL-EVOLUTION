## 2024-04-20 - Frequency and Mix Tables Opt
**Learning:** `jsonb_array_elements_text` combined with massive dynamic `ROLLUP` and `CROSS JOIN LATERAL` causes Postgres statements to time out for large datasets. `data_history` scans inside dashboards are intrinsically slow.
**Action:** Migrated `data_summary_frequency` array schemas to native Postgres `text[]` using `array_agg` and added boolean flags for heavy mix brands like `has_cheetos`. Updated `get_frequency_table_data` to use `unnest()` and `&&` array operator, avoiding `jsonb` unpacking, and rewrote `get_mix_salty_foods_data` to entirely query `data_summary_frequency` using these new integer flags instead of scanning `data_history` and `data_detailed`. Created migration script for safe application.

## 2024-04-21 - [SQL Aggregation Logic for Mix Attributes]
**Learning:** When pre-aggregating data for threshold-based metrics (e.g., Mix PDV needing `prod_vlvenda >= 1`), evaluating the threshold on unaggregated source rows () causes false negatives if orders are split into multiple fractional rows.
**Action:** Refactored `refresh_summary_year` and `refresh_summary_chunk` in `sql/full_system_v1.sql` to include a CTE that first groups and sums order values per product/client before applying the threshold logic, ensuring correct KPI calculations when uploading files.

## 2024-04-21 - [SQL Aggregation Logic for Mix Attributes]
**Learning:** When pre-aggregating data for threshold-based metrics (e.g., Mix PDV needing prod_vlvenda >= 1), evaluating the threshold on unaggregated source rows causes false negatives if orders are split into multiple fractional rows.
**Action:** Refactored refresh_summary_year and refresh_summary_chunk in sql/full_system_v1.sql to include a CTE that first groups and sums order values per product/client before applying the threshold logic, ensuring correct KPI calculations when uploading files.
