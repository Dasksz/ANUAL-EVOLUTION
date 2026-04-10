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
## 2026-04-08 - [Fix DOM XSS in KPI Rendering and fmtVar]
**Vulnerability:** XSS vulnerability where template strings were assigned to `innerHTML` dynamically in `renderComparisonKPIs` (`container.innerHTML = kpis.map(...)`) and in Box KPIs where `fmtVar` returned HTML injected via `.innerHTML`. Although inputs might appear safe, this is a dangerous anti-pattern prone to XSS if data is tampered with.
**Learning:** `innerHTML` and `insertAdjacentHTML` combined with template literals are common sources of DOM-based XSS in this project.
**Prevention:** Avoid `innerHTML` entirely for dynamically generated DOM elements. Use `document.createElement()`, `textContent`, and `.appendChild()` combined with a `DocumentFragment` to securely construct UI elements natively. Modify formatters to return text and class names separately rather than raw HTML strings.

## 2024-04-09 - Client-Side Supabase Keys are public
**Learning:** The user explicitly requested that the Supabase URL and Key remain in the codebase because the page is purely hosted by GitHub Pages (static front-end only) and has no backend. In a static setup like this, Supabase anon keys and URLs are designed to be public. Security relies entirely on Postgres Row Level Security (RLS) policies on the Supabase end, rather than keeping the anon key secret.
**Prevention:** Do not attempt to hide the Supabase URL or the anonymous key in purely client-side static architectures.
## 2024-04-10 - [Fix XSS in modal rendering]
**Vulnerability:** XSS vulnerability where raw database strings (`row.vendedor_nome`, `row.filial`) and other data strings (`rootData.varYagoStr`) were directly interpolated into string templates that were then assigned to `innerHTML`. This allowed for arbitrary HTML and Javascript injection if an attacker were to manipulate the database records or other data.
**Learning:** `innerHTML` used with unescaped string interpolation is an extremely common pattern for XSS in this codebase.
**Prevention:** Always use `escapeHtml()` when assigning data from strings directly into `innerHTML`, or use native DOM methods like `document.createElement()`, `textContent`, and `appendChild()` which inherently escape content.
