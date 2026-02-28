1. **Understand the problem**: The user wants to improve the contrast of the "Pasta" filter buttons ("ELMA" and "FOODS"). As seen in the provided image, the selected state ("FOODS") has a teal background (#0d9488 or a similar color based on tailwind classes `bg-teal-600` or `bg-emerald-600`) and greyish text, which makes the text somewhat hard to read. The non-selected state ("ELMA") is just dark grey with grey text, which is also a bit low-contrast against the dark background.
2. **Analyze current implementation**:
    - In `index.html`:
      ```html
      <div id="comparison-fornecedor-toggle-container" class="w-full bg-white/5 border border-white/10 rounded-lg p-1 flex justify-center gap-2">
          <button data-fornecedor="ELMA" class="fornecedor-btn flex-1 py-1.5 px-3 text-xs font-bold text-slate-400 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all">ELMA</button>
          <button data-fornecedor="FOODS" class="fornecedor-btn flex-1 py-1.5 px-3 text-xs font-bold text-slate-400 bg-white/5 border border-white/10 rounded-lg hover:bg-white/10 transition-all">FOODS</button>
      </div>
      ```
    - In `src/css/styles.css`:
      ```css
      .fornecedor-btn {
          opacity: 0.5;
          transition: opacity 0.2s;
      }
      .fornecedor-btn.active {
          opacity: 1;
          background-color: #0d9488; /* teal-600 */
      }
      .fornecedor-btn:hover:not(.active) {
          opacity: 0.8;
      }
      ```
3. **Proposed Changes**:
    - For the inactive state, remove the inline CSS opacity (which is `0.5`) because the `text-slate-400` on a dark background is already a bit muted, and making the whole button 50% opacity lowers the contrast significantly.
    - For the active state, `background-color: #0d9488` is applied. When active, we should also change the text color to white (`color: white;`) to improve contrast against the teal background.
    - Update `src/css/styles.css`:
      ```css
      .fornecedor-btn {
          /* Remove opacity to improve baseline contrast */
          transition: all 0.2s;
      }
      .fornecedor-btn.active {
          background-color: #0d9488; /* teal-600 */
          color: #ffffff !important; /* Force white text for better contrast */
          border-color: #0d9488;
      }
      .fornecedor-btn:hover:not(.active) {
          background-color: rgba(255, 255, 255, 0.1); /* Equivalent to hover:bg-white/10 */
      }
      ```
    - Additionally, check `index.html` classes. In `index.html`, the buttons have `text-slate-400` class. When `.active` is added, the CSS `color: white !important;` will override `text-slate-400`.
4. **Pre-commit**: Include a pre-commit step to ensure proper checks.
5. **Submit**: Submit the branch.
