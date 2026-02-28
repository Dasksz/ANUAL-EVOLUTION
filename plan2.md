1. **Improve Contrast of "Pasta" Filter**:
    - Update `src/css/styles.css` for `.fornecedor-btn` styles. Remove `opacity: 0.5` from `.fornecedor-btn` and add `color: white !important;` to `.fornecedor-btn.active`.
2. **Move "Produto" Filter on "Caixas" Page**:
    - Open `index.html`.
    - Find the "Boxes View Content" section (`id="boxes-view"`).
    - Find the `<div class="relative">` block that contains the "Produto" filter (`boxes-produto-filter-btn`).
    - Move this entire block to be placed immediately *before* the `<div class="relative">` block that contains the "Categoria" filter (`boxes-categoria-filter-btn`).
    - This will place the "Produto" filter to the left of the "Categoria" filter in the flex wrap layout.
3. **Pre-commit**: Complete pre-commit step.
4. **Submit**: Submit the changes.
