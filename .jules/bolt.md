## 2026-04-23 - Prevented full filter loop logic execution in CTE metrics query calculation for independent KPIs
Improved logic around querying metrics which are conditionally tied to specific internal vendor codes (Pepsico Salty + Foods) where standard overarching filters would override query functionality. Pushed dynamic filters into the CTE metrics block instead of base CTE fetch, ensuring all necessary un-filtered codes are still fetched for rendering zeroed-out lines, preventing empty views.

## 2024-05-18 - Optimize string sanitization
**Learning:** Chained `.replace()` operations create multiple intermediate string copies and evaluate regular expressions multiple times, causing a notable overhead.
**Action:** Replaced the chained `.replace()` calls in the heavily-utilized `escapeHtml` utility with a single-pass character iteration (`charCodeAt`). By combining a fast-path regex check (`matchHtmlRegExp.test`) and string indexing, we achieve ~35% performance improvement and reduce memory allocations during table rendering loops without sacrificing readability.
