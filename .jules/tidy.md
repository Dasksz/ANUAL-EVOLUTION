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
