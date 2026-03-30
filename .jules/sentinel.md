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
## 2026-03-27 - Inconsistent KPI Business Logic Between Dashboards
**Vulnerability:** Different dashboards showing different results for the same conceptual metric ("Clientes Atendidos" / "Base Atendida"). The main dashboard considered bonifications (when explicitly filtered) or values >= 1, while the innovations dashboard strictly enforced >= 1 excluding bonifications in all cases.
**Learning:** Hardcoding business rules like `tipovenda NOT IN ('5', '11')` in one dashboard while making it dynamic in another creates data inconsistency, leading to lack of trust in the system and potential decisions based on partial data.
**Prevention:** Centralize KPI calculation logic or ensure identical `HAVING` clauses are used across all RPCs that calculate "active" or "attended" clients based on sales thresholds and types.
## 2024-10-26 - Unescaped variables in HTML interpolations (DOM-based XSS)
**Vulnerability:** Several dynamically rendered fields (like category name, product name, product code, indicator name, and hierarchy node name) were directly injected into HTML strings used with `innerHTML` and `insertAdjacentHTML` without proper sanitization. This allowed for potential Cross-Site Scripting (XSS) if the source data contained malicious payload.
**Learning:** In systems where dynamic HTML is built by concatenating template literals without a framework, it's very easy to miss unescaped variables. Every dynamic piece of data originating from a database or external source must be treated as unsafe.
**Prevention:** Strictly enforce the use of `escapeHtml()` when interpolating any string properties that are injected into the DOM via literal strings. This includes seemingly safe fields like codes and names.
## 2026-03-29 - [Fix XSS in Innovations Table Render]
**Vulnerability:** XSS vulnerability where raw database strings (`cat.name`, `p.code`, `p.name`) were directly interpolated into `innerHTML` strings in `renderInnovationsTable`, allowing arbitrary HTML injection. Also, `cat.name` was embedded in an `onclick` attribute without escaping, enabling attribute-based injection.
**Learning:** Template literal strings assigned to `innerHTML` are a common vector for XSS in this codebase if not explicitly passed through `escapeHtml()`. Inline event handlers pose an extra risk.
**Prevention:** Always wrap data from untrusted sources in `escapeHtml()`. For inline JS handlers, use safe alphanumeric IDs instead of raw strings to prevent syntax-breaking injections.
