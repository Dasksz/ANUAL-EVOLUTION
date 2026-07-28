2024/07/28 - Fix Frequency and Mix Means
 Learning: Replaced `AVG()` inside CTE rollups with `SUM(num)/NULLIF(SUM(den), 0)` to fix a global "mean of means" bug that inflated distinct SKU metrics and frequency aggregates incorrectly in PostgreSQL and chunk-based UI state aggregators.
 Action: Fixed `get_frequency_table_data` and `get_main_dashboard_data` to return un-aggregated distinct metrics and properly weigh them on both DB and frontend client-side mergers.
