1. **Change the Loading Overlay Target:**
   - Update `showDashboardLoading(targetId)` in `src/js/app.js` to instead target the entire application body (or a container that wraps everything, including the navbar), rather than just the active view container (like `main-dashboard-view`).
   - Alternatively, we can make the loading overlay `fixed` position so it covers the entire viewport regardless of which container it's placed in. Let's look at `.dashboard-loading-overlay` in `src/css/styles.css`.

2. **Update CSS for the Loading Overlay:**
   - Change `position: absolute;` to `position: fixed;` in `.dashboard-loading-overlay` within `src/css/styles.css`. This will ensure it covers the entire screen.
   - Increase `z-index` from `50` to `9999` so it's above the navbar (`z-index: 1000`) and the filters (`z-index: 100` / `999`).

3. **Pre-commit:** Verify the changes logic and test if it works via local bash test.
