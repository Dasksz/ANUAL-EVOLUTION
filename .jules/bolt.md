## Bolt Performance Learnings

## 2025-03-25
**Optimization:** Optimized `get_frequency_table_data` calculation for `SKU/PDV` (Mix).
Instead of calculating the distinct count of `codcli || '-' || sku` globally across the branch/city/salesperson, which caused inaccurate averages when divided by `positivacao` in the frontend, the backend now accurately calculates the distinct SKUs per client (`dist_skus_per_cli`) and sums them up (`SUM(dist_skus_per_cli)`). This allows the frontend calculation (`sum_skus / positivacao`) to output the exact distinct average SKUs per positive client, aligning perfectly with the global `MIX PDV:` KPI metric and avoiding cross-client SKU counting drift.

### 2025-03-03: Optimized Global Aggregation for Distinct Mix Attributes

When computing distinct items purchased by a client across a hierarchy (e.g. Salesperson > City > Branch), if you need global distinct counts (e.g. at the Branch level), **do not pre-aggregate `COUNT(DISTINCT sku)` at the leaf nodes (Salesperson)** and `SUM()` those values upward. This approach leads to severe double-counting if a single client buys the exact same item from two different salespeople.

**Bolt Optimization:**
Instead, calculate distinct combinations directly in a higher-level CTE using a composite key:
```sql
COUNT(DISTINCT codcli || '-' || sku) as dist_skus
```
Group this by the dimensions that actually slice the data horizontally (e.g., `filial, cidade, codusur`) without grouping by the client ID itself. This effectively tracks true unique (Client + SKU) events up the grouping hierarchy, ensuring accurate macro-level metrics like `MIX PDV` without the heavy processing overhead of multi-level lateral DISTINCT aggregations.
### 2024-10-24
- Added the `mix_chart_data` CTE securely into the single `get_frequency_table_data` RPC execution to return both Chart and Freq results in a single database round-trip to the Supabase client, avoiding additional latency over network.
