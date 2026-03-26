# Performance & Logic Fixes

## 2024-03-26
- **Mix Salty & Foods Logic Update**: Aligned `get_comparison_view_data` and `get_mix_salty_foods_data` PostgreSQL RPC functions with the original JavaScript-based logic from the PRIME repository.
    - Instead of strict equivalence checks (`mix_marca = 'CHEETOS'`), the updated logic now gracefully evaluates `dp.descricao ILIKE '%CHEETOS%'` allowing identical flexibility to the JS implementation's `.includes('CHEETOS')`.
    - Also explicitly fixed the matching constraint for 'TODDY ' (with trailing space) that previously counted extraneous variations causing the count to inflate to 85 instead of the expected 84.

- **Re-architecture of get_mix_salty_foods_data**: Abandoned the flawed approach of relying on `data_summary_frequency` JSON parsing for string evaluation, replacing it entirely with the direct unioned `data_detailed` and `data_history` logic used effectively inside `get_comparison_view_data`. This ensures 100% equivalence between the monthly charts and the comparativo page, and properly prevents false zeros or false hits from misaligned arrays and substrings.

## 2024-05-18
- **Mix Salty & Foods Exact Match Enforced**: Updated the `get_mix_salty_foods_data` function to match the `mix_marca` column strictly instead of using a fuzzy `ILIKE` on `dp.descricao`. This provides much better performance and precisely aligns the Visão Geral chart data perfectly with the current logic governing the KPI metric counters on the Comparativo page.
