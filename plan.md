1. **Analyze Frontend Performance Opportunities**: Review `src/js/app.js` and other JS files to identify performance bottlenecks. Specifically, look at `mergeBoxesDashboardData` which has `Array.find()` inside loops over `chart_data` and `products_table`. This can be an $O(N^2)$ operation. We can replace it with an $O(N)$ Map-based lookup or similar structure.
2. **Implement Optimization**: Refactor `mergeBoxesDashboardData` to use `new Map()` for O(1) lookups during the merge process.
3. **Verify Optimization**: Run format and lint checks (or syntax checks since this is a simple JS project). Ensure no functionality is broken.
4. **Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.**
5. **Submit PR**: Create a PR with the title '⚡ Bolt: Optimize mergeBoxesDashboardData O(N^2) Array.find to O(N) Map lookup' and include the required description format.
