## 2026-03-29 - [Fix XSS in Innovations Table Render]
**Vulnerability:** XSS vulnerability where raw database strings (`cat.name`, `p.code`, `p.name`) were directly interpolated into `innerHTML` strings in `renderInnovationsTable`, allowing arbitrary HTML injection. Also, `cat.name` was embedded in an `onclick` attribute without escaping, enabling attribute-based injection.
**Learning:** Template literal strings assigned to `innerHTML` are a common vector for XSS in this codebase if not explicitly passed through `escapeHtml()`. Inline event handlers pose an extra risk.
**Prevention:** Always wrap data from untrusted sources in `escapeHtml()`. For inline JS handlers, use safe alphanumeric IDs instead of raw strings to prevent syntax-breaking injections.
