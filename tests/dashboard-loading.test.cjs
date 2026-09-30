const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8');
function section(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}
const fetchCode = section('async function fetchDashboardData(', '    async function loadMainDashboardData(');
const keyCode = section('    function generateCacheKey(', '    let checkProfileLock');
const log = { log() {}, warn() {}, error() {} };

async function run() {
  const calls = [], saved = [];
  const consolidated = { kpi_clients_base: 2739, monthly_data_current: [
    { month_index: 8, faturamento: 13397.58, mix_pdv: 17.8158047646717 }
  ] };
  let response = { data: consolidated, error: null };
  const ctx = vm.createContext({ AppLog: log, Date, Error,
    getFromCache: async () => null,
    saveToCache: async (...args) => saved.push(args),
    supabase: { rpc: async (...args) => { calls.push(args); return response; } },
    // Available options intentionally incomplete: they must never narrow Todas.
    availableFiltersState: { filiais: ['05'] },
  });
  vm.runInContext(keyCode + fetchCode, ctx);
  for (const filial of [[], null, ['05','08']]) {
    const result = await ctx.fetchDashboardData({ p_filial: filial }, false, true);
    assert.equal(result.data, consolidated);
    assert.deepEqual(calls.at(-1), ['get_main_dashboard_data', { p_filial: filial }]);
  }
  assert.equal(calls.length, 3);
  assert.equal(saved.length, 3);
  response = { data: { partial: true }, error: { message: 'timeout' } };
  const failure = await ctx.fetchDashboardData({ p_filial: [] }, false, true);
  assert.equal(failure.data, null);
  assert.equal(saved.length, 3, 'failed response must not be cached');
  assert.match(ctx.generateCacheKey('dashboard_data', {}), /^dashboard_data_v3_/);
  assert.match(ctx.generateCacheKey('dashboard_filters', {}), /^dashboard_filters_v2_/);
  assert.equal(ctx.generateCacheKey('dashboard_data', {p_filial:['08','05']}), ctx.generateCacheKey('dashboard_data', {p_filial:['05','08']}));

  const pending = [], rendered = [];
  const race = vm.createContext({ AppLog: log, Date, Promise,
    mainDashboardRequest: 0, lastDashboardData: null,
    getCurrentFilters: () => ({p_filial:[]}), generateCacheKey: () => 'test',
    getFromCache: async () => null,
    fetchDashboardData: () => new Promise(resolve => pending.push(resolve)),
    fetchLastSalesDate: async () => {}, loadFrequencyTable: async () => {}, prefetchViews: () => {},
    renderDashboard: value => rendered.push(value),
    window: {showDashboardLoading() {}, hideDashboardLoading() {}, showToast() {}},
  });
  vm.runInContext(section('    async function loadMainDashboardData(', '    // Prefetch Background Logic'), race);
  const first = race.loadMainDashboardData(true), second = race.loadMainDashboardData(true);
  pending[1]({data:{version:'new'}}); await second;
  pending[0]({data:{version:'old'}}); await first;
  assert.deepEqual(rendered, [{version:'new'}]);
  console.log('PASS: consolidated RPC, complete cache, cache revisions, stale-response protection');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
