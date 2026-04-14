# Tidy's Journal

This file contains critical learnings from Tidy to avoid making mistakes in this specific codebase.## 2026/04/03 : Extract Date Filter Initialization Logic
**Learning:** Repetitive blocks of logic for initializing default filter dates based on `lastSalesDate` were found across multiple view initialization functions (Innovations, Branch, Estrelas, etc.). This makes updating the fallback logic error-prone if it needs to change in the future.
**Action:** Created a centralized helper function `getDefaultFilterDates(lastSalesDate)` to return `currentYear` and `currentMonth`. This reduced repetition and improved consistency across the application. Replaced inline duplication with standard destructuring `const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);`.

## 2026/04/04 : Extract Duplicated DOM Row Generation Logic
**Learning:** Found massive duplicated blocks of `innerHTML` row string generation in `src/js/app.js` within `openDetalhadoModal`. In addition to making the code unnecessarily long, it violated memory directives to use safer DOM construction.
**Action:** Created `createDetalhadoRow(row, index, realizado, realizedUnit, meta, metaUnit, share, shareColorClass)` to safely generate `<tr>` rows using `document.createElement` and `textContent` rather than interpolating data into `innerHTML` strings. Replaced the 3 duplicate iteration blocks within `openDetalhadoModal` to map to this single helper, reducing repetition while adhering to the app's safety constraints.

## 2026/04/06 : Extract Number and Currency Formatting Logic
**Learning:** Found numerous duplicate instances of `.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })` and `(val / 1000).toLocaleString('pt-BR', ...) + ' Ton'` across the codebase. These inline string manipulations obscure business logic and make UI formatting updates tedious.
**Action:** Centralized these formatters into `formatCurrency` and `formatTons` in `src/js/utils.js`. Replaced all repetitive string operations to use these standard utility functions to enforce DRY principles and improve code readability.

## 2025/02/25 : (Extract formatInteger Utility) **Aprendizado:** (Formatting boilerplate like `Math.round(val).toLocaleString('pt-BR')` occurs frequently in frontend tables and dashboards, cluttering logic) **Ação:** (Extracted `formatInteger` to `src/js/utils.js` to standardize integer formatting, similar to `formatCurrency` and `formatTons`.)

## 2026/04/10 : Extract Button Loading State Logic
**Learning:** Found repetitive instances of button loading state logic across the codebase (export PDF/Excel, sign-in, sign-up, forgot password). Each instance duplicated a long `<svg class="animate-spin...` string, `btn.disabled = true/false`, and manual `btn.innerHTML` assignment, cluttering business logic.
**Action:** Created centralized utility functions `setButtonLoading(btn, text)` and `restoreButtonState(btn, originalHtml)` in `src/js/utils.js`. Replaced all repetitive loading spinner injections to use these functions, reducing code duplication and improving readability while ensuring XSS safety via `escapeHtml`.

## 2026/04/11 : Extract and Standardize Inline Number and Integer Formatting
**Learning:** Found multiple remaining instances of `.toLocaleString('pt-BR')` applied directly on metrics values, especially for counts (integers) and fractional numbers (like mix_pdv). This clutters the UI rendering logic, makes the code repetitive, and increases the chance of localization inconsistencies.
**Action:** Substituted all remaining occurrences of inline `.toLocaleString('pt-BR', ...)` formatting for metric outputs with the centralized `formatInteger(value)` and `formatNumber(value, decimals)` utility functions from `src/js/utils.js`. Only `new Date().toLocaleString('pt-BR')` statements were preserved.

## 2026/04/12 : (Extract Dropdown Clickaway Logic)
**Aprendizado:** (Found 8 repetitive loops checking if a click event target is outside an array of dropdowns and buttons to close the dropdowns. This repetitive boilerplate cluttering the UI interaction code violates DRY principles and makes the code difficult to read.)
**Ação:** (Extracted this into a centralized `handleDropdownsClickaway(e, dropdowns, btns)` utility function in `src/js/utils.js`. Replaced all repetitive loops with this single utility call, returning a boolean indicating if any dropdown was closed, allowing further downstream logic to run cleanly.)

## 2026-04-13 : Extract Active View Export Logic
**Learning:** Found duplicate logic to determine the currently active view and its name for Excel and PDF exports, violating DRY and cluttering the listeners.
**Action:** Extracted the logic into a `getActiveExportView()` function that returns `{ activeView, viewName }`. Replaced both sets of duplicated view-finding loops with a single call to this helper function.

## 2026/04/14 : Extract Dropdown Closing Logic
**Aprendizado:** Found 5 repetitive occurrences of DOM querying and loops (`document.querySelectorAll('.absolute.z-\\[50\\], .absolute.z-\\[999\\]').forEach(...)`) to close absolute dropdown menus. This duplication clutters the UI interaction code and makes it harder to maintain or modify the dropdown closing behavior.
**Ação:** Extracted this logic into a centralized `closeAllDropdowns` function in `src/js/utils.js`. Replaced all repetitive occurrences in `src/js/app.js` with this simple function call, significantly improving readability and code maintainability.
