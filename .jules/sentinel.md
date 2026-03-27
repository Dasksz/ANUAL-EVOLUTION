## Sentinel Security Learnings

### 2024-10-24
- Avoid `innerHTML` directly with user variables where possible, although safe elements created via literals without user data are acceptable for DOM skeleton/resets (e.g. `<canvas>`).
2026-03-25: Addressed month filter bug that passed incremented month strings (e.g. 03 became 04) when querying Supabase RPCs on Innovations page, which aligns with security practices of keeping client-requested input deterministic and un-mangled before hitting the database.
## 2024-10-25 - Prevent DOM-based XSS with loop-based innerHTML
**Vulnerability:** Loop-based `innerHTML +=` usage could cause DOM-based XSS when parsing potentially unsafe array values or executing unnecessary re-parsing steps, resulting in heavy reflows and possible script execution if data is crafted maliciously.
**Learning:** Instead of appending to `innerHTML` inside a loop (which serializes/deserializes DOM repeatedly), use `insertAdjacentHTML` or `DocumentFragment`.
**Prevention:** Avoid `element.innerHTML +=` completely. Either build an entire string and set `innerHTML` once, or use `insertAdjacentHTML('beforeend', str)` which does not corrupt existing nodes.
## 2026-03-26 - Ensure consistent aggregation logic in SQL
**Vulnerability:** Data discrepancy caused by inconsistent filtering logic. `get_mix_salty_foods_data` was filtering `vlvenda >= 1` and `tipovenda NOT IN ('5', '11')` at the row level before aggregation, which caused differences compared to `get_comparison_view_data` which aggregates first.
**Learning:** For KPIs based on aggregate conditions (e.g. positive mix), ensure that the base dataset is identical and any business logic (like >= 1 or ignoring certain sales types) is applied consistently after the initial grouping/aggregation, otherwise the final metrics will drift between views.
**Prevention:** Align SQL RPCs that calculate the same KPIs to use identical base table combinations and `WHERE` clauses, standardizing the query structure.
## 2024-03-27 - Cross-Site Scripting (XSS) in DOM Construction
**Vulnerability:** Missing escaping of data properties (like client names, city names, etc.) when dynamically constructing UI elements using template literals and assigning them to `innerHTML`.
**Learning:** In a vanilla JS application heavily relying on dynamic DOM building strings, it's very easy to miss escaping fields. Since there is no framework like React or Vue handling escaping automatically, any database string containing malicious payloads like `<script>` or `<img src=x onerror=...>` would execute on rendering.
**Prevention:** Whenever generating HTML strings manually to append via `innerHTML` or `insertAdjacentHTML`, every dynamic string variable originating from external data or user input MUST be wrapped in the `escapeHtml()` utility function. Where possible, refactor complex components to use `document.createElement` and `textContent` as a more robust defense against DOM-based XSS.
