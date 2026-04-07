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
## 2026-03-30 - Fix JSONB string trailing space issue in SQL
**Vulnerability:** A logic error existed where the database query looked for the key `TODDY ` (with a trailing space) in a JSONB array (`categorias ? 'TODDY '`) while the data was stored as `TODDY`. This caused dependent metric flags (like `has_toddy`) to silently evaluate to false, rendering whole aggregations (like the Mix Foods chart) zeroed out.
**Learning:** Hardcoded literal string matching in JSONB arrays (`?` operator) is strictly exact. Trailing spaces or case mismatches will fail silently without SQL errors, causing cascading logic failures in dashboard metrics. Always verify the exact string stored in the database when writing or debugging `jsonb ?` queries.
**Prevention:** Remove trailing spaces from literal strings used in SQL JSONB existence operators. When mapping frontend filter values to database keys, ensure the exact mapping exists and is cleanly trimmed.
## 2026-04-01 - [Fix DOM XSS in renderCityPaginationControls]
**Vulnerability:** XSS vulnerability where template strings containing multiple variable injections were assigned directly to `container.innerHTML` in `renderCityPaginationControls()`. Although variables were numeric, setting `innerHTML` dynamically with template strings is a recognized critical security anti-pattern in the codebase (as well as causing unnecessary DOM reflows).
**Learning:** Even if the payload seems "safe" (e.g. integers), relying on developer discipline to differentiate safe and unsafe payloads for `innerHTML` eventually leads to an XSS exploit when code evolves.
**Prevention:** Avoid `.innerHTML` with template literals altogether for dynamically generated components. Instead, explicitly use `document.createElement()`, `textContent`, and `appendChild()` to build UI structures securely.
## 2026-04-02 - [Fix XSS in City View Table Render]
**Vulnerability:** XSS vulnerability where raw strings for the City View details and ranking tables were constructed using string concatenation and assigned directly to `innerHTML`.
**Learning:** Template literal strings assigned to `innerHTML` are a recurring vector for XSS in this codebase. Even seemingly safe fields can be exploited if the underlying data is tampered with.
**Prevention:** Consistently use `document.createElement()` and `textContent` over `innerHTML` for all dynamic UI rendering to prevent XSS.
## 2026-04-03 - [Fix XSS in Table Rendering]
**Vulnerability:** XSS vulnerability where template strings are assigned to `innerHTML` directly in `renderSupervisorTable`, `renderLpTable`, and the products table render. While the existing code used `escapeHtml()`, assigning interpolated strings to `innerHTML` is an unsafe pattern that can easily lead to vulnerabilities if escaping is forgotten.
**Learning:** Relying on developer discipline to always use `escapeHtml()` with `innerHTML` is prone to error.
**Prevention:** Consistently use `document.createElement()`, `textContent`, and `appendChild()` (often with a `DocumentFragment` for performance) over `innerHTML` for all dynamic UI rendering to natively prevent DOM-based XSS.
## 2026-04-04 - [Fix XSS in updateTable rendering loop]
**Vulnerability:** XSS vulnerability where template strings were concatenated into a large string (`allRowsHTML`) and passed to `insertAdjacentHTML` in `updateTable`. Even though `escapeHtml()` was used on some variables, relying on manually escaping and string concatenation inherently runs a high risk of DOM-based XSS if escaping is missed, particularly for dynamically formatted fields.
**Learning:** Returning raw HTML strings from format functions (like `ind.fmt` returning a colored `span`) and concatenating them forces the usage of `innerHTML` or `insertAdjacentHTML`.
**Prevention:** Avoid `insertAdjacentHTML` and `innerHTML` entirely. Update format configurations to return plain values and separate the presentation logic into flags (like `isRed: true`). Then, use `document.createElement()`, `textContent`, and `appendChild()` along with `DocumentFragment` to securely build the UI structure natively in the DOM.
## 2026-04-05 - [Fix Hardcoded Supabase Credentials]
**Vulnerability:** Critical security vulnerability where Supabase URL and Service/Anon Key were hardcoded in plain text in `src/js/supabase.js`. This exposed the project's backend infrastructure to anyone with access to the source code or browser developer tools.
**Learning:** Hardcoding API keys is a major security risk. Even in client-side applications where keys are eventually public, they should not be committed to version control to allow for easy rotation and environment-specific configuration.
**Prevention:** Move sensitive configuration to externalized files that are excluded from version control via `.gitignore`. Provide a template file (e.g., `config.js.example`) to guide developers on the required setup without exposing actual secrets.
## 2026-04-07 - [Fix DOM XSS in Dropdowns]
**Vulnerability:** Medium severity DOM-based XSS vulnerability where template literals (`optionsHTML += ...`) were used to construct filter dropdowns and assigned directly to `.innerHTML`. Even though the data (years) comes from the database, trusting data without safe DOM methods exposes the app to injection if the database is manipulated.
**Prevention:** Always use `document.createElement()`, `.value`, `.textContent`, and `.appendChild()` for dynamically generating UI elements based on data inputs, avoiding `innerHTML` concatenation entirely.
## 2026-04-07 - [Fix DOM XSS in Dropdowns]
**Vulnerability:** Medium severity DOM-based XSS vulnerability where template literals were used to construct filter dropdown options and assigned directly to `.innerHTML`. Even though the data (years) comes from the database, trusting data without safe DOM methods exposes the app to injection if the database is manipulated.
**Learning:** Using `.innerHTML` to dynamically create element structures like `<option>` lists with string concatenation is an anti-pattern. Relying on native DOM creation is much safer.
**Prevention:** Always use `document.createElement()`, `.value`, `.textContent`, and `.appendChild()` for dynamically generating UI elements based on data inputs, avoiding `innerHTML` concatenation entirely.
