const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8');
const start = source.indexOf('    function mergeMainDashboardData(');
const end = source.indexOf('\nasync function fetchDashboardData(', start);
const merge = vm.runInNewContext(source.slice(start, end) + '\nmergeMainDashboardData;');
const keyStart = source.indexOf('    function generateCacheKey(');
const keyEnd = source.indexOf('\n    let checkProfileLock', keyStart);
const cacheKey = vm.runInNewContext(source.slice(keyStart, keyEnd) + '\ngenerateCacheKey;');

// Read-only data_summary totals: AMERICANAS / EQLIBRI / 2026, branches 05 and 08.
const branch05 = [[0, 820.26], [1, 2187.36], [2, 820.26], [3, 273.42], [5, 820.26], [7, 2187.36], [8, 4374.72]];
const branch08 = [[0, 820.26], [3, 273.42], [5, 1093.68], [6, 2460.78], [7, 1913.94], [8, 9022.86]];
const monthly = rows => rows.map(([month_index, faturamento]) => ({month_index, faturamento}));
const payload = rows => ({monthly_data_current: monthly(rows), monthly_data_previous: monthly(rows)});
const expected = new Map();
for (const [month, amount] of [...branch05, ...branch08]) expected.set(month, (expected.get(month) || 0) + amount);

for (const branches of [[branch05, branch08], [branch08, branch05]]) {
    const first = payload(branches[0]);
    const second = payload(branches[1]);
    const original = JSON.stringify([first, second]);
    const result = merge(merge(null, first), second);
    for (const field of ['monthly_data_current', 'monthly_data_previous']) {
        const rows = result[field];
        assert.equal(rows.length, expected.size);
        assert.equal(JSON.stringify(rows.map(m => m.month_index)), JSON.stringify([...expected.keys()].sort((a, b) => a - b)));
        for (const row of rows) assert.ok(Math.abs(row.faturamento - expected.get(row.month_index)) < 1e-8);
        assert.ok(Math.abs(rows.find(m => m.month_index === 8).faturamento - 13397.58) < 1e-8);
        assert.ok(Math.abs(rows.reduce((sum, m) => sum + m.faturamento, 0) - 27068.58) < 1e-8);
    }
    assert.equal(JSON.stringify([first, second]), original);
}

const empty = merge(merge(null, payload([])), payload(branch05));
assert.equal(JSON.stringify(empty.monthly_data_current), JSON.stringify(monthly(branch05)));
assert.match(cacheKey('dashboard_data', {p_filial: []}), /^dashboard_data_v2_/);
assert.equal(cacheKey('dashboard_data', {p_filial: ['08', '05']}), cacheKey('dashboard_data', {p_filial: ['05', '08']}));
assert.match(cacheKey('dashboard_filters', {}), /^dashboard_filters_/);
console.log('PASS: sparse months, both years, branch order, empty branch, totals and cache invalidation');
