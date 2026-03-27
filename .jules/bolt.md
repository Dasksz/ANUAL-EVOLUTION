# Performance & Logic Fixes

## 2024-03-26
- **Mix Salty & Foods Logic Update**: Aligned `get_comparison_view_data` and `get_mix_salty_foods_data` PostgreSQL RPC functions with the original JavaScript-based logic from the PRIME repository.
    - Instead of strict equivalence checks (`mix_marca = 'CHEETOS'`), the updated logic now gracefully evaluates `dp.descricao ILIKE '%CHEETOS%'` allowing identical flexibility to the JS implementation's `.includes('CHEETOS')`.
    - Also explicitly fixed the matching constraint for 'TODDY ' (with trailing space) that previously counted extraneous variations causing the count to inflate to 85 instead of the expected 84.

- **Re-architecture of get_mix_salty_foods_data**: Abandoned the flawed approach of relying on `data_summary_frequency` JSON parsing for string evaluation, replacing it entirely with the direct unioned `data_detailed` and `data_history` logic used effectively inside `get_comparison_view_data`. This ensures 100% equivalence between the monthly charts and the comparativo page, and properly prevents false zeros or false hits from misaligned arrays and substrings.

## 2024-05-15 - localeCompare() vs Standard Operators for Sorting
**Learning:** In the `worker.js` chunking logic, using `String.prototype.localeCompare` within the `.sort()` comparator on arrays of ~10,000 items is a massive performance bottleneck. The `localeCompare` function has significant overhead due to Unicode and internationalization checks, taking ~384ms compared to ~99ms for standard operators (`<`, `>`).
**Action:** When sorting large volumes of data for deterministic hashing (where locale-specific sorting isn't functionally required), avoid `localeCompare`. Use standard string comparison operators (`ka < kb ? -1 : (ka > kb ? 1 : 0)`) to drastically improve CPU-bound execution times inside Web Workers.
