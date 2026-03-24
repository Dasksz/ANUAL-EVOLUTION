## 2025-05-18 - [Dropdown Render Bottleneck]
**Learning:** Using `.includes()` on arrays inside `.sort()` callbacks leads to O(n^2 log n) complexity. Appending individual DOM elements to a container in a loop causes numerous layout reflows per render.
**Action:** Convert arrays to `Set` objects for O(1) lookups during sorting. Use `DocumentFragment` to batch DOM appends into a single reflow when updating UI lists.
## 2026-03-24 - [Estrelas Dashboard SQL Optimization]
**Learning:** For rendering complex KPIs with multiple conditions (sellout vs salty vs foods) and matching arrays (aceleradores_realizado and aceleradores_parcial), evaluating array containment checks (`<@` and `&&`) efficiently inside `COUNT(DISTINCT)` with `jsonb_array_elements_text` is critical to prevent OOM errors and timeouts.
**Action:** When implementing new KPI components using large multi-conditional groupings (like `get_estrelas_kpis_data`), use CTEs and `EXISTS (SELECT 1 FROM jsonb_array_elements_text)` to pre-filter rows before applying aggregations instead of performing JSON parsing during the actual final group by aggregation, which dramatically reduces memory usage.
