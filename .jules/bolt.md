## 2025-05-18 - [Dropdown Render Bottleneck]
**Learning:** Using `.includes()` on arrays inside `.sort()` callbacks leads to O(n^2 log n) complexity. Appending individual DOM elements to a container in a loop causes numerous layout reflows per render.
**Action:** Convert arrays to `Set` objects for O(1) lookups during sorting. Use `DocumentFragment` to batch DOM appends into a single reflow when updating UI lists.
## 2026-03-24 - [Estrelas Dashboard SQL Optimization]
**Learning:** For rendering complex KPIs with multiple conditions (sellout vs salty vs foods) and matching arrays (aceleradores_realizado and aceleradores_parcial), evaluating array containment checks (`<@` and `&&`) efficiently inside `COUNT(DISTINCT)` with `jsonb_array_elements_text` is critical to prevent OOM errors and timeouts.
**Action:** When implementing new KPI components using large multi-conditional groupings (like `get_estrelas_kpis_data`), use CTEs and `EXISTS (SELECT 1 FROM jsonb_array_elements_text)` to pre-filter rows before applying aggregations instead of performing JSON parsing during the actual final group by aggregation, which dramatically reduces memory usage.

### 2024-03-24
- **Bolt Optimization**: Refactored `kpi_active_count` in `sql/full_system_v1.sql` (`get_main_dashboard_data` RPC) to use `COUNT(DISTINCT codcli)` with direct early `WHERE` filters (e.g., `vlvenda >= 1` or `bonificacao > 0`). This replaces an expensive `GROUP BY codcli HAVING SUM(vlvenda) >= 1` subquery over the `filtered_summary` CTE, which was causing statement timeouts ("canceling statement due to statement timeout" - 57014) on large datasets when loading the dashboard after data upload.

## 2026-05-18 - [Global Array Cache Anti-pattern]
**Learning:** Caching `Object.keys(row).sort()` to a global variable (e.g., in a function processing array of objects) and reusing it across *all* invocations causes data corruption when the function is reused to process distinct tables/objects of different shapes, leading to missing keys or undefined values.
**Action:** Do not use global state to cache object keys for a generic function like `generateHash`. While caching is fast, state isolation (e.g., passing a specific keys array or generating a schema mapping per dataset) is required to ensure correctness across diverse workloads.

## 2026-05-18 - [V8 Date and String Parsing Bottlenecks]
**Learning:** During heavy data ingestion (e.g., Web Workers parsing 100k+ rows), calling `String.substring()`, `String.split()`, and `parseInt()` repeatedly on well-known string formats (like `YYYY-MM-DD` or `DD/MM/YYYY`) creates massive intermediate string allocation overhead and forces the garbage collector to work heavily. Furthermore, evaluating regexes over clean numbers adds significant CPU time.
**Action:** When extracting components from strictly formatted strings in hot loops, use `.charCodeAt(index)` to read bytes directly, followed by manual base-10 integer math `(c - 48) * 10...` to bypass string object creation entirely. For number parsing that handles edge cases like "R$ ", add a fast path (`indexOf(',') === -1 && indexOf('R$') === -1`) to fallback immediately to native `parseFloat` for pre-cleaned data.
