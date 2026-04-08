## 2024-05-19 - Removed innerText in cloned DOM for faster export
**Learning:** `innerText` is styling-aware and triggers expensive layout calculations (reflows) even on detached or cloned DOM nodes.
**Action:** When extracting text from DOM nodes in a loop (like during table export), use `textContent` instead of `innerText` to prevent expensive layout thrashing and significantly improve performance.
