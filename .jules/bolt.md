## Bolt Performance Learnings

### 2024-10-24
- Added the `mix_chart_data` CTE securely into the single `get_frequency_table_data` RPC execution to return both Chart and Freq results in a single database round-trip to the Supabase client, avoiding additional latency over network.
