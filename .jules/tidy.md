## 2024/05/29 : Separated Presentation view to Standalone Page
**Aprendizado:** Moved the Closing Presentation ("Apresentação Fechamento") from a modal into its own standalone HTML page for better layout and presentation flow using Swiper.js, allowing the use of custom slide transitions and a cleaner UI without cluttering the main `app.js` and `index.html`.
**Ação:** Created `presentation.html`, `src/css/presentation.css`, and `src/js/presentation.js`. Replaced modal toggle logic in `app.js` and `index.html` with a direct link opening in a new tab.
## 2026/07/27 : Fix KPIs variations and presentation UI issues
**Aprendizado:** Solved missing Trimestre and Ano variation issues across KPIs which were either returning zero or missing values. Learned how missing data from SQL functions can propagate to UI leading to duplicated supervisor logic.
**Ação:** Updated sql/full_system_v1.sql with correct pos_trim and ton_trim queries and fixed javascript grouping and filters to render the UI components appropriately.
