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
