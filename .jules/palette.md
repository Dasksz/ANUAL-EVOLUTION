## 2026-06-25 - Sticky Header Overlap Fix

**Learning:** Fixed a CSS `z-index` conflict in `index.html` where progress bar percentages were overflowing over a sticky table header.

**Action:** Adjusted the `.sticky-header th` class to have `z-index: 20` (previously 10) so it layers correctly above the table cell content elements which had `z-10`. This prevents overlap issues during scroll in views containing progress charts within sticky headers (e.g., Ranking de Categorias).
