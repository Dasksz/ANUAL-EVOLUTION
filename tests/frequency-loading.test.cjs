const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8');
const code = source.slice(source.indexOf('function readFrequencyPanel('), source.indexOf('function renderFrequencyTable('));
const tick = () => new Promise(setImmediate);
function harness({cached = {}, failSave = false} = {}) {
    const calls = [], rendered = [], elements = {};
    const context = vm.createContext({
        Date, Promise, Map, Error, frequencyRequest: 0, frequencyReads: new Map(), frequencyPanelKey: null,
        document: {getElementById: id => elements[id] ||= {innerHTML: ''}},
        AppLog: {log() {}, warn() {}, error() {}},
        generateCacheKey: (type, filters) => type + (filters.p_ano || ''),
        getFromCache: async key => cached[key],
        saveToCache: async (key, data) => {
            if (failSave) throw new Error('Storage unavailable');
            cached[key] = {data, timestamp: Date.now()};
        },
        renderTableEmptyState: (_, message) => message,
        renderFrequencyTable: data => rendered.push(['table', data]),
        renderFrequencyChart: data => rendered.push(['frequency', data]),
        renderMixSaltyFoodsChart: data => rendered.push(['mix', data]),
        DashboardGoals: {targetSeries: goals => goals?.target},
        supabase: {rpc: (name, filters) => new Promise(resolve => calls.push({name, filters, resolve}))},
    });
    vm.runInContext(code, context);
    return {context, calls, rendered, elements};
}
async function run() {
    const h = harness();
    const first = h.context.loadFrequencyTable({p_ano: '2026'}, {target: 1});
    await tick();
    const second = h.context.loadFrequencyTable({p_ano: '2026'}, {target: 2});
    await tick();
    assert.equal(h.calls.length, 2, 'goal updates must share both in-flight reads');
    h.calls.find(c => c.name.includes('mix')).resolve({data: {chart_data: []}});
    await tick();
    assert.deepEqual(h.rendered.map(r => r[0]), ['mix'], 'mix renders before the slow frequency query');
    assert.equal(h.rendered[0][1].goal_series.salty, 2, 'latest goals win');
    h.calls.find(c => c.name.includes('frequency')).resolve({data: {tree_data: []}});
    await Promise.all([first, second]);
    assert.deepEqual(h.rendered.map(r => r[0]), ['mix', 'table', 'frequency']);
    assert.equal(h.context.frequencyReads.size, 0);
    await h.context.loadFrequencyTable({p_ano: '2026'}, {target: 3});
    assert.equal(h.calls.length, 2, 'completed reads reuse cache for later goal updates');

    const failure = harness();
    const failing = failure.context.loadFrequencyTable({}, {});
    await tick();
    failure.calls.find(c => c.name.includes('frequency')).resolve({error: {code: '57014'}});
    failure.calls.find(c => c.name.includes('mix')).resolve({data: {chart_data: []}});
    await failing;
    assert.deepEqual(failure.rendered.map(r => r[0]), ['mix'], 'one panel failure does not discard another');
    assert.match(failure.elements['frequency-table-body'].innerHTML, /Erro/);
    assert.equal(failure.context.frequencyReads.size, 0, 'failed reads can be retried');

    const partial = harness({cached: {frequency_data2026: {data: {cached: true}, timestamp: Date.now()}}, failSave: true});
    const loading = partial.context.loadFrequencyTable({p_ano: '2026'}, {});
    await tick();
    assert.equal(partial.calls.length, 1, 'partial cache fetches only the missing panel');
    assert.equal(partial.rendered[0][1].cached, true);
    partial.calls[0].resolve({data: {chart_data: []}});
    await loading;
    assert.equal(partial.rendered.at(-1)[0], 'mix', 'storage failure must not discard successful data');

    const race = harness();
    const old = race.context.loadFrequencyTable({p_ano: '2025'}, {});
    await tick();
    const current = race.context.loadFrequencyTable({p_ano: '2026'}, {});
    await tick();
    for (const call of race.calls.filter(c => c.filters.p_ano === '2026')) call.resolve({data: {year: 2026}});
    await current;
    for (const call of race.calls.filter(c => c.filters.p_ano === '2025')) call.resolve({data: {year: 2025}});
    await old;
    assert.equal(race.rendered.length, 3);
    assert.ok(race.rendered.every(r => r[1].year === 2026), 'abandoned filters cannot replace current panels');
    assert.doesNotMatch(source.slice(source.indexOf('async function initDashboard()'), source.indexOf('async function checkDataVersion()')), /queueCommonFilters\(\)/);
    console.log('PASS: independent panels, shared reads, partial cache, storage errors, stale response protection');
}
run().catch(error => {console.error(error); process.exitCode = 1;});
