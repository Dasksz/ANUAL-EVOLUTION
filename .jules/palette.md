## 2026-06-25 - Sticky Header Overlap Fix

**Learning:** Fixed a CSS `z-index` conflict in `index.html` where progress bar percentages were overflowing over a sticky table header.

**Action:** Adjusted the `.sticky-header th` class to have `z-index: 20` (previously 10) so it layers correctly above the table cell content elements which had `z-10`. This prevents overlap issues during scroll in views containing progress charts within sticky headers (e.g., Ranking de Categorias).
## 2026-06-26 - [Centering Table Headers with Visual Transforms]
**Learning:** Use visual transforms () rather than padding manipulation for precise, pixel-perfect text shifts within tight table cells. Padding alters the box-model width, often causing layout flow disruption or wrapping, while transform only alters the visual render.
**Action:** Add  directly on elements that require small sub-10px centering tweaks.
## 2024-05-15 - [Centering Table Headers with Visual Transforms]
**Learning:** Use visual transforms (`transform: translateX()`) rather than padding manipulation for precise, pixel-perfect text shifts within tight table cells. Padding alters the box-model width, often causing layout flow disruption or wrapping, while transform only alters the visual render.
**Action:** Add `style="transform: translateX(Xpx);"` directly on elements that require small sub-10px centering tweaks.
