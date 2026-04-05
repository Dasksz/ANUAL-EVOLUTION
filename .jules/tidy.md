# Tidy's Journal

This file contains critical learnings from Tidy to avoid making mistakes in this specific codebase.## 2026/04/03 : Extract Date Filter Initialization Logic
**Learning:** Repetitive blocks of logic for initializing default filter dates based on `lastSalesDate` were found across multiple view initialization functions (Innovations, Branch, Estrelas, etc.). This makes updating the fallback logic error-prone if it needs to change in the future.
**Action:** Created a centralized helper function `getDefaultFilterDates(lastSalesDate)` to return `currentYear` and `currentMonth`. This reduced repetition and improved consistency across the application. Replaced inline duplication with standard destructuring `const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);`.
## 2026/04/05 : Prevent Syntax Breakage During Global Injections
**Learning:** Injecting large code blocks (like utility functions) by simply finding the end brace `}` of a target function can be dangerous. In `src/js/app.js`, finding the first `}` after `getDefaultFilterDates` resulted in injecting the utilities *between* an `if` block and its subsequent `else` block, causing a fatal syntax error.
**Action:** When injecting code globally via scripts, always parse carefully or inject near unambiguous top-level markers (e.g., right before `function escapeHtml` or at the very top of the script) to ensure it stays outside of control-flow blocks.

## 2026/04/05 : Extract Data Formatting Utilities
**Learning:** Over 40 repetitive inline calls to `.toLocaleString('pt-BR')` existed for currencies, weights, and numbers, causing scattered visual rules. Additionally, function name collisions can occur during refactoring (e.g., a localized `formatNumber` vs a global one).
**Action:** Created global `formatCurrency`, `formatWeight`, `formatNumber`, and `formatPercent` utilities at the top of `src/js/app.js`. Renamed existing colliding localized functions (e.g. to `formatNumberOrDash`) before injecting the new globals to prevent infinite recursion. Always use these central helpers moving forward.
