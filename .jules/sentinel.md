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
