const fs = require('fs');

const date = new Date().toISOString().split('T')[0];
const docEntry = `
${date} - Optimize Stock Trend and Fix Missing FROM clause error
 Learning: When generating dynamic queries for different paths (e.g. FAST vs SLOW path), if table joins (like dim_produtos as dp) exist in one CTE but not another, pushing filters with explicit table aliases will cause "missing FROM-clause entry" errors on execution paths where the join is absent. Also, row-by-row division in aggregates using correlated subqueries can be severely bottlenecked.
 Action: Ensured both paths exposed the required joined columns (or removed specific prefixes when safe) to prevent runtime syntax errors with dynamic string filters. Pushed aggregate arithmetic (like division) outside the inner SUM(...) to operate only once per product rather than per raw sale record.
`;

fs.appendFileSync('.jules/querytuner.md', docEntry);
