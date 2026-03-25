# Sentinel Learnings

## 2026-03-25: Secure DOM Construction
When building dynamic tables with JavaScript, `innerHTML +=` introduces security vulnerabilities (DOM-based XSS) and performance issues. Always use `document.createElement()`, `DocumentFragment`, and securely map variables (with fallbacks for `undefined` or missing keys). In `app.js`, the `openDetalhadoModal` was refactored to construct rows safely and avoid bugs where an empty initial array failed to map to a table correctly.
