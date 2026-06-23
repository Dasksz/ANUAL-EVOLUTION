## 2025-06-05 - Add Evolution Line Chart for KPIs
**Learning:** For layout consistency in dashboards with multiple metric areas, it's a good practice to mimic existing visual styles for analogous data. The new Loja Perfeita annual evolution chart mimics the height styling, single line approach, and legend of the "Mix Salty & Foods" chart, aligning perfectly before the actual KPIs are displayed.
**Action:** Use existing class composition and Tailwind `min-h-[value]` to create proportional empty state/chart containers alongside glass-cards styling.
## 2026-06-22 - Add Category Ranking and Total Salty Positivação in Share View
Implemented a tooltip to the "Positivação Salty Total" indicator using standard Tailwind group-hover and title properties to improve clarity on what the metric signifies.

## 2024-05-18 - [Styling Excel Exports using xlsx-js-style]
**Learning:** The default SheetJS (xlsx) Community Edition doesn't support styling (like bold text, background colors, custom column width). However, replacing the default CDN import with `xlsx-js-style` allows applying rich styling formatting via the `.s` property on cells.
**Action:** Always prefer `xlsx-js-style` if users request Excel formatting without having a paid SheetJS Pro license, and implement standard style-applying helper functions for consistency across multiple export scenarios.
