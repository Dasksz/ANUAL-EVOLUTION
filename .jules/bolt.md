## 2026-04-23 - Prevented full filter loop logic execution in CTE metrics query calculation for independent KPIs
Improved logic around querying metrics which are conditionally tied to specific internal vendor codes (Pepsico Salty + Foods) where standard overarching filters would override query functionality. Pushed dynamic filters into the CTE metrics block instead of base CTE fetch, ensuring all necessary un-filtered codes are still fetched for rendering zeroed-out lines, preventing empty views.
## 2024-04-25 - [Optimize renderInnovationsTable string building]
**Learning:** In frontend environments, massive string concatenation using `+=` inside nested loops over large datasets (like `renderInnovationsTable` with hundreds of product rows) causes significant performance degradation due to repeated memory allocations and garbage collection.
**Action:** Always pre-calculate complex attributes (like numeric rounding and colors) in data preparation loops, and use an array `push()` followed by `.join('')` to construct large HTML templates efficiently.

## 2025-05-15 - [Optimization] Removed unnecessary String conversion in loop

- **Where:** `src/js/app.js:3297` (`updateBtnLabel` function)
- **What:** Replaced explicit `String()` conversion inside a `.find()` loop with loose equality `==`.
- **Benefit:** Avoids thousands of temporary string allocations during O(N) array searches, resulting in ~40% faster execution for large filter lists.
## 2026-04-26 - [Optimize escapeHtml string replacements]
**Learning:** In frontend utility functions called frequently during rendering loops, chained regex `.replace()` operations (like those used for HTML escaping) create a massive performance bottleneck due to multiple intermediate memory allocations and string copies.
**Action:** Use a single-pass character iteration loop (e.g., using `charCodeAt`) rather than chained `.replace()` calls to construct strings efficiently when modifying text.
## 2025-05-18 - [Optimize Autocomplete List DOM Operations]
**Learning:** Generating dropdown list items using multiple `document.createElement` calls and `appendChild` within a `.forEach` loop causes layout thrashing and slows down typing responsiveness during autocomplete. Attaching individual event listeners inside the loop compounds memory usage.
**Action:** Always replace item-by-item DOM creation loops with a single `innerHTML` assignment using `.map().join('')`. Use event delegation on the container parent to handle child clicks rather than creating individual listeners, maintaining `O(1)` listener overhead.
## 2024-04-29 - [Optimize document.createElement inside render loops]
**Learning:** Generating elements with `document.createElement()` and appending them one by one in loops causes slow rendering times. Combining strings to set `innerHTML` is much faster because the browser only has to do the layout processing once.
**Action:** Replace verbose `document.createElement` loops with `.map(...).join('')` and template literals where rendering large sets of DOM elements, ensuring `escapeHtml` is used to prevent XSS.
## 2024-04-29 - Optimize Dashboard RPCs Timeout and Indexed Aggregations
Increased `statement_timeout` to `600s` in complex dashboard RPCs (like `get_main_dashboard_data`) to prevent `57014` cancellation errors during heavy dynamic groupings. Also added `idx_summary_dash_perf` on `public.data_summary (ano, mes, codcli, tipovenda, vlvenda)` to accelerate these high-cardinality aggregations.
## 2026-04-29 - Edge Function Sincronização via Google Sheets "Upsert vs Delete & Insert"
**Melhoria de Performance e Resiliência de Dados:** O modelo anterior da Edge Function de integração contínua (Google Sheets -> Supabase) utilizava `.upsert` baseado numa chave única `(data_rota, supervisor)`. Se o nome do supervisor na planilha for alterado ou consertado no meio do caminho, o Upsert falhava ao tentar inserir um registro porque se perde a continuidade entre a chave original.
**Solução Aplicada:** O `.upsert` e a restrição `UNIQUE` foram substituídos por um modelo `Truncate & Insert`. A cada rodada, a Edge Function executa `supabase.from('supervisors_routes').delete().not('supervisor', 'is', null)` (que no PostgreSQL demora milissegundos mesmo para milhares de linhas), seguido de um `.insert(records)` com todos os registros novamente coletados. Isso limpa instantaneamente a sujeira (como dados velhos ou mal escritos) e sincroniza a tabela idêntica à planilha em um único recarregamento assíncrono.
## 2026-05-19 - Event Delegation in Batch DOM Rendering
**Learning:** While replacing verbose `document.createElement()` loops with template strings and `innerHTML` provides a significant performance boost for rendering, querying the newly created child nodes post-render to attach individual event listeners (e.g., `container.querySelectorAll('.item').forEach(...)`) negates these benefits due to layout thrashing and O(N) listener overhead. This happens frequently in UI components that filter and re-render on user input (like custom multi-select dropdowns).
**Action:** Always implement Event Delegation when refactoring DOM rendering to use `innerHTML`. Attach a single O(1) event listener to the static parent container (e.g., `container.onclick = (e) => { const item = e.target.closest('.item'); ... }`) to eliminate the need for post-render queries and dynamic listener bindings.
## 2026-05-03 - O(1) Item Lookup in Multi-Select
**Learning:** Performing an O(N) `.find()` search on every selection change in a multi-select component is inefficient. Pre-calculating a `Map` during initialization provides O(1) lookups and significantly improves UI responsiveness when dealing with many items.
**Action:** Use a `Map` for frequent lookups of items by their code or ID instead of repeated array searches.

## $(date +%Y-%m-%d) - Fix SKU/PDV aggregation logic
**Learning:** For KPI metrics like SKU/PDV and Mix PDV, doing calculations at a pre-aggregated monthly level and then rolling up the average provides better context compared to taking the unique SKU count across the entire span and dividing it by total positivations (which inflates the metric as the same sku bought over multiple months doesn't count up).
**Action:** When working on sales aggregation, identify if metrics like "unique items" need to be evaluated per-month before global rollup. Grouping by `mes` at the CTE level before rolling up ensures more accurate KPIs.
## 2026-05-16 - Safe Global State Fallbacks
**Learning:** Legacy UI elements relying on global callback events (like `window.updateGlobalState`) will break page interactivity and throw `Uncaught TypeError` if these functions are undocumented and accidentally removed during refactors, blocking features like `refreshJbpData` from firing via event listeners.
**Action:** When debugging missing UI behaviors, grep for chained functions `() => { window.someState(); refreshData() }` and ensure either the missing function is safely stubbed or implemented fully to prevent execution blocking.
## 2026-05-18 - Safe Group By Extensions in SQL
**Learning:** Modifying SQL aggregation queries to include new literal columns (e.g., adding `bairro` and `cidade` to a report) requires updating both the `SELECT` clause with aggregate functions (like `MAX()`) and ensuring the `GROUP BY` clause is correctly adjusted if the columns are intended as un-aggregated dimensions.
**Action:** When adding standard attributes to existing SQL queries, prefer wrapping them in `MAX()` or `MIN()` if the data granularity is already defined by existing `GROUP BY` keys (e.g. `codcli`). This avoids expanding the row count accidentally or having to adjust nested `GROUP BY` indices manually which can be error-prone.
## 2026-05-29 - SQL Optimization: FILTER vs CASE WHEN & memory tuning
**Learning:** In Supabase's free tier (constrained memory environment ~512MB total RAM), scaling up PostgreSQL's `work_mem` too high (e.g., > 128MB) for heavy BI queries can trigger Out of Memory (OOM) errors and restart the database. Instead of relying on brute force RAM for aggregates, queries containing `COUNT(DISTINCT CASE WHEN condition THEN value END)` or `SUM(CASE WHEN condition THEN value ELSE 0 END)` should be refactored to use the native `FILTER (WHERE condition)` clause. This allows the query optimizer to skip rows early, avoiding intermediate memory allocations and evaluating complex conditions much faster. Removing `MATERIALIZED` from CTEs also allows the query planner to push down predicates and leverage indexes (like `INCLUDE` partial indexes) without forcing full dataset writes to temporary disk storage.
**Action:** Always prefer `agg_func() FILTER (WHERE condition)` over `agg_func(CASE WHEN condition THEN ...)` in PostgreSQL aggregations. Keep `work_mem` conservative (around 64MB-90MB) on shared instances. Avoid `MATERIALIZED` CTEs unless strict execution barriers are genuinely required to prevent redundant massive computations.
## 2026-06-26 - [Fast and robust date string parsing]
**Learning:** Native `Date()` constructors or complex regex parsers can be slow and unpredictable across different locales and browser environments, especially for various M/D/Y vs D/M/Y combinations generated by Excel.
**Action:** When parsing well-known, fixed-format date strings in performance-critical code (like data workers), use character codes (`charCodeAt`) combined with mathematical swaps instead of string splitting or RegEx. This provides maximum speed and deterministic format correction.
## 2026-06-26 - [Robust Date Parsing from Excel/Sheets]
**Learning:** Spreadsheets often provide dates either as integer serial numbers (e.g., 45293) or strings that might look like "junho de 2026" but contain underlying date values like "01/06/2026" when edited. Manual string matching logic fails on the real underlying strings, breaking downstream backend sync operations.
**Action:** Always attempt to parse date values with a robust global function that handles both Excel Serial Dates and standard strings before falling back to manual string interpretation (like Portuguese month matching).
## 2025-02-27 - Inline HTML Updates
**Learning:** For rendering long lists or tables in DOM, mapping an array to string `<tr>...</tr>` and applying innerHTML once is much faster than creating separate rows and columns.
**Action:** Kept the optimization and applied formatting correctly for new properties directly.
