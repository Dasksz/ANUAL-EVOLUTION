## 2026-04-16 - n8n Credential Redaction

**Vulnerability:** Third-party API credentials (like Chatwoot `api_access_token`) were exposed in exported n8n workflow JSON files, risking unauthorized access if the repository is public or compromised.
**Learning:** Hardcoded secrets in static declarative files (like n8n JSONs or Postman collections) are easily overlooked because they often sit deep inside node parameter definitions.
**Prevention:** Always implement automated or manual sanitization steps to replace API keys, tokens, and sensitive URLs with `REDACTED` or placeholders before committing workflow exports.

## 2024-05-18 - Content Security Policy (CSP) for Static Frontends Heavy on DOM Manipulation
**Vulnerability:** Static, frontend-only applications relying heavily on `.innerHTML` loops (e.g., table generation logic like in `src/js/app.js`) are inherently at a higher risk of DOM-based Cross-Site Scripting (XSS) if variable sanitization (like `escapeHtml()`) is ever accidentally missed by a developer.
**Learning:** Because this architecture relies on zero build tools (no bundler/Vite) and imports scripts dynamically from third-party CDNs (Tailwind, Chart.js, etc), it is highly susceptible to script injection or object embedding if an attacker successfully finds a sink. We cannot eliminate `unsafe-inline` because the app and CDNs depend on it, but we can completely disable `unsafe-eval` and block insecure domains or objects.
**Prevention:** Implement a strict Content Security Policy (CSP) meta tag in `index.html` that whitelists known CDNs (`cdn.tailwindcss.com`, `cdn.jsdelivr.net`, `cdnjs.cloudflare.com`), explicitly drops `object-src 'none'`, and blocks `unsafe-eval`. This provides a crucial defense-in-depth layer to mitigate impact even if an `escapeHtml()` call is missed.
## 2024-04-19 - [DOM-based XSS via unsafe innerHTML usage]
**Vulnerability:** Found multiple instances where values were interpolated into `innerHTML` strings without being sanitized by `escapeHtml()` first. This includes dates, month names, and mathematical derivations in various dashboard tables (`calendar`, `frequency tree`, `innovations table`, `pdf header`). Also the `setElementLoading` in `src/js/utils.js` wasn't escaping `loadingText`.
**Learning:** Developers often forget to sanitize numeric or derived values (like dates or rounded numbers) when writing template literals for `innerHTML`, assuming they are inherently safe. However, if those values are eventually derived from untrusted inputs or the schema changes, it introduces XSS.
**Prevention:** Always use `escapeHtml()` when interpolating *any* dynamic variable into a string that will be assigned to `innerHTML`, regardless of whether the variable currently holds a number or a date. Consider using `.textContent` where possible instead.

## 2025-05-15 - SVG Path Update XSS Prevention (Refined)
**Vulnerability:** Potential Cross-Site Scripting (XSS) via unsafe `innerHTML` assignments when updating SVG icons. Although the data sources were hardcoded path strings, using `innerHTML` with template literals is a dangerous pattern that can be exploited if the data source ever becomes dynamic or compromised.
**Learning:** Updating SVG icons by replacing the entire `innerHTML` of the `<svg>` element is less efficient and more risky than targeting specific attributes. Simple UI toggles often only need to change the `d` attribute of a `<path>` element.
**Prevention:** Always prefer granular DOM API methods like `setAttribute()` or `textContent` over `innerHTML`. For SVG icon state changes, target the `<path>` element and update its `d` attribute directly. If the number of paths changes, consider pre-defining them in the HTML and toggling their visibility or clearing their `d` attribute.
**Refined Action:** Introduced a centralized `updateSvgPaths` utility that uses `document.createElementNS` to manage path elements safely, ensuring consistent styling (attributes) and avoiding `innerHTML` entirely.
