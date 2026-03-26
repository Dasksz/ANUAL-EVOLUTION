## Sentinel Security Learnings

### 2024-10-24
- Avoid `innerHTML` directly with user variables where possible, although safe elements created via literals without user data are acceptable for DOM skeleton/resets (e.g. `<canvas>`).
2026-03-25: Addressed month filter bug that passed incremented month strings (e.g. 03 became 04) when querying Supabase RPCs on Innovations page, which aligns with security practices of keeping client-requested input deterministic and un-mangled before hitting the database.
## 2024-10-25 - Prevent DOM-based XSS with loop-based innerHTML
**Vulnerability:** Loop-based `innerHTML +=` usage could cause DOM-based XSS when parsing potentially unsafe array values or executing unnecessary re-parsing steps, resulting in heavy reflows and possible script execution if data is crafted maliciously.
**Learning:** Instead of appending to `innerHTML` inside a loop (which serializes/deserializes DOM repeatedly), use `insertAdjacentHTML` or `DocumentFragment`.
**Prevention:** Avoid `element.innerHTML +=` completely. Either build an entire string and set `innerHTML` once, or use `insertAdjacentHTML('beforeend', str)` which does not corrupt existing nodes.
