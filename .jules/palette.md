## 2025-06-05 - Add Evolution Line Chart for KPIs
**Learning:** For layout consistency in dashboards with multiple metric areas, it's a good practice to mimic existing visual styles for analogous data. The new Loja Perfeita annual evolution chart mimics the height styling, single line approach, and legend of the "Mix Salty & Foods" chart, aligning perfectly before the actual KPIs are displayed.
**Action:** Use existing class composition and Tailwind `min-h-[value]` to create proportional empty state/chart containers alongside glass-cards styling.
## 2026-06-22 - Add Category Ranking and Total Salty Positivação in Share View
Implemented a tooltip to the "Positivação Salty Total" indicator using standard Tailwind group-hover and title properties to improve clarity on what the metric signifies.
## 2026-06-22 - Styled Category Ranking with Progress Bars
**Learning:** Replaced raw percentage text numbers with dynamically sized progress bars overlaying the percentage for Share metric displays. This gives users an immediate visual comparison across categories instead of having to mentally process each number. Used Tailwind `bg-[#1c84c6]` for the bar fill. Added `w-1/2` to the percentage cell to constrain the bar correctly.

**Action:** Whenever building ranking tables where the primary metric is a percentage of total, prefer inline progress bars (using relative/absolute positioned divs and width bindings) to improve scannability.
