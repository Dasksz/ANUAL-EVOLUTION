## 2025-02-14 - Fix Cross-Site Scripting (XSS) in Innovations Table
**Vulnerability:** The `renderInnovationsTable` function interpolated untrusted database values (`cat.name`, `p.code`, `p.name`) directly into an HTML template string which was then written to the DOM using `element.innerHTML += html`.
**Learning:** Even internal database information can be a vector for XSS if it gets rendered directly into HTML without escaping. Specifically, whenever constructing HTML strings manually via template literals that use `innerHTML`, all dynamically inserted data should be validated or safely escaped.
**Prevention:** Always use the `escapeHtml` utility for any variables embedded into raw HTML strings, or alternatively use `document.createElement` and `textContent` as a more robust defense against DOM-based XSS when building elements.

## 2025-02-14 - Fix Cross-Site Scripting (XSS) in Innovations Table
**Vulnerability:** The `renderInnovationsTable` function interpolated untrusted database values (`cat.name`, `p.code`, `p.name`) directly into an HTML template string which was then written to the DOM using `element.innerHTML += html`.
**Learning:** Even internal database information can be a vector for XSS if it gets rendered directly into HTML without escaping. Specifically, whenever constructing HTML strings manually via template literals that use `innerHTML`, all dynamically inserted data should be validated or safely escaped.
**Prevention:** Always use the `escapeHtml` utility for any variables embedded into raw HTML strings, or alternatively use `document.createElement` and `textContent` as a more robust defense against DOM-based XSS when building elements.
