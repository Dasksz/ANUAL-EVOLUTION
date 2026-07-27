## 2024/05/29 : Separated Presentation view to Standalone Page
**Aprendizado:** Moved the Closing Presentation ("Apresentação Fechamento") from a modal into its own standalone HTML page for better layout and presentation flow using Swiper.js, allowing the use of custom slide transitions and a cleaner UI without cluttering the main `app.js` and `index.html`.
**Ação:** Created `presentation.html`, `src/css/presentation.css`, and `src/js/presentation.js`. Replaced modal toggle logic in `app.js` and `index.html` with a direct link opening in a new tab.
## 2024/07/27 : (Presentation Page Enhancements)
**Aprendizado:** Chart.js has an extensive plugin system that allows drawing custom shapes (like stars) directly onto the canvas in `afterDatasetsDraw`. Circular progress elements can be elegantly rendered purely with SVG using `stroke-dasharray`, avoiding the need for heavy external libraries.
**Ação:** Implemented a Monthly Evolution chart with a custom plugin to dynamically calculate and place a '⭐' over the best month. Built lightweight SVG circular charts to track product category performance vs historical targets.
