## 2024-04-13 - Optimize Supabase Dynamic SQL Timeouts
**Learning:**
Heavy analytical queries with `COUNT(DISTINCT)` over large datasets (like `data_summary_frequency`) often timeout if they unconditionally perform `INNER JOIN` operations with dimension tables or excessive `CROSS JOIN LATERAL` JSONB unnesting. In Supabase RPCs returning dynamic SQL (e.g., `get_frequency_table_data`), these timeouts are particularly evident when the dashboard loads with no filters (full-year scope). Furthermore, performing `LEFT JOIN` on massive fact tables against large dimension tables before filtering significantly degrades performance (e.g., `get_mix_salty_foods_data`).

**Action:**
1. Dynamically constructed CTEs in PL/PGSQL to conditionally bypass heavy joins. In `get_frequency_table_data`, the `INNER JOIN public.dim_produtos` is bypassed when `v_where_unnested` is empty, significantly accelerating the unnested `jsonb_array_elements_text` distinct counts.
2. In `get_mix_salty_foods_data`, replaced a deferred `LEFT JOIN` with a preemptive `INNER JOIN` against a pre-filtered `dim_produtos` CTE (`WHERE mix_marca IS NOT NULL AND mix_marca != ''`). This acts as an early data pruner, dropping over 90% of irrelevant rows before expensive multi-column aggregations.
## 2024-05-17 - Fast table rendering via innerHTML
**Learning:** Using `innerHTML` with mapped strings and an `escapeHtml` utility is significantly faster (over 50% faster in jsdom benchmarks) than iteratively using `document.createElement()` and `appendChild()` within a loop for large datasets in this application. The difference is especially noticeable because the system handles thousands of rows in complex multi-column table interfaces without a virtual DOM abstraction.
**Action:** Default to using `element.innerHTML = dataArray.map(item => \`<html structure...>\`).join('')` instead of `document.createElement` loops when rendering tables and dropdowns in raw JavaScript. Always enforce the use of `escapeHtml()` for any user or database-provided strings to prevent XSS.
## 2024-05-18 - Memoize Expensive String Normalizations in Web Workers
**Learning:** In the Web Worker (`src/js/worker.js`), `normalizeCityName` processes hundreds of thousands of rows containing repetitive city names. Using `.normalize("NFD")` and regex replacements on strings repeatedly is extremely CPU-intensive and blocks the worker thread unnecessarily. A simple test showed normal operations taking ~385ms while memoized operations dropped to ~14ms for the same dataset.
**Action:** Always implement a simple `Map`-based caching mechanism (`memoization`) for functions performing heavy string normalizations or regular expression replacements when the domain of inputs (like city names or statuses) is small and repetitive.

## 2024-04-15 - Incremental Cache Refreshes to Prevent Timeouts
**Learning:** Calling heavy global SQL RPCs (like refreshing the entire global cache table from scratch) via `supabase.rpc` at the end of a bulk upload loop easily triggers `canceling statement due to statement timeout` errors when historical data sizes increase.
**Action:** Transitioned from a single parameterless `refresh_cache_filters()` call at the end of the upload process to a sequential, parameterized `refresh_cache_filters(year, month)` call executing directly inside the data chunking loop in `src/js/app.js`. Also replaced the `FOR` loop in the fallback SQL logic inside `sql/full_system_v1.sql` with a fast, single-pass `INSERT INTO ... SELECT ... GROUP BY` aggregation query.

## 2024-05-20 - Set.has instead of Array.includes for O(1) matching

**Learning:** For performance optimization in dynamic key lookup loops (like `getVal` in `src/js/worker.js`), use `Set` instead of `Array` for caching matched keys (e.g., `matchedKeysCache`). This replaces O(N) `.includes()` deduplication checks with O(1) `.add()` operations. Because `Set` maintains insertion order, `for...of` loops safely preserve the original evaluation order while significantly improving execution speed.
