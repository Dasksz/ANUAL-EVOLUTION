2024-05-18: Identified that frontend month dropdowns using 0-indexed values require explicit +1 conversion before passing to PostgreSQL, which expects 1-indexed months.
## 2026-04-17 - Fix CSP blocked CDNs
**Learning:** `connect-src` needs to allow the CDNs explicitly because Web Workers (via `importScripts`) or libraries dynamically load resources. Adding them prevents `fetch` failures for these CDNs.
**Action:** Updated `connect-src` in `index.html` to include `https://cdn.jsdelivr.net` and `https://cdnjs.cloudflare.com`.
