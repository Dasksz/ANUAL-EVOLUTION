## 2025-06-05 - Add Evolution Line Chart for KPIs
**Learning:** For layout consistency in dashboards with multiple metric areas, it's a good practice to mimic existing visual styles for analogous data. The new Loja Perfeita annual evolution chart mimics the height styling, single line approach, and legend of the "Mix Salty & Foods" chart, aligning perfectly before the actual KPIs are displayed.
**Action:** Use existing class composition and Tailwind `min-h-[value]` to create proportional empty state/chart containers alongside glass-cards styling.
## 2026-06-22 - Add Category Ranking and Total Salty Positivação in Share View
Implemented a tooltip to the "Positivação Salty Total" indicator using standard Tailwind group-hover and title properties to improve clarity on what the metric signifies.

## 2024-05-18 - [Styling Excel Exports using xlsx-js-style]
**Learning:** The default SheetJS (xlsx) Community Edition doesn't support styling (like bold text, background colors, custom column width). However, replacing the default CDN import with `xlsx-js-style` allows applying rich styling formatting via the `.s` property on cells.
**Action:** Always prefer `xlsx-js-style` if users request Excel formatting without having a paid SheetJS Pro license, and implement standard style-applying helper functions for consistency across multiple export scenarios.
## 2026-06-25 - [Add ACM Column with Custom Color in Pos. Populacional]
**Learning:** Adding new data columns within complex visual tables requires updating headers, content rows, totals rows, and the `colspan` of loading/error state rows. Using a distinct color like `text-purple-400` helps the new "Acumulado" metric stand out against the existing cyan/emerald data points without breaking the existing dark-mode design system.
**Action:** When adding columns, systematically update all five areas of a table (Header, Loading State, Error State, Empty State, Data Rows, and Totals Row) and utilize unique semantic colors for clear differentiation.
