const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8').replace(/\r\n/g, '\n');
const start = source.indexOf('            // CHUNKED CACHE REFRESH LOGIC');
const end = source.indexOf('\n\n        } catch (error)', start);
assert.ok(start >= 0 && end > start);
const code = source.slice(start, end);
async function run(data, opts = {}) {
  const calls = [];
  const summaries = new Map([['2024', 'preserved'], ['2025', 'preserved'], ['2026', 'preserved']]);
  const ctx = vm.createContext({ data, Date, Number, Set, Object,
    updateStatus() {},
    clearTable(table) { throw Error('Global wipe forbidden: ' + table); },
    retryOperation: async fn => { for (let i=0; i<3; i++) { try { return await fn(); } catch (e) { if (i===2) throw e; } } },
    supabase: { rpc: async (name, args) => {
      calls.push([name, args]);
      if (name === 'get_available_years') return opts.discoveryError ? { error: {message:'discovery failed'} } : { data: opts.years || [2026,2025,2024] };
      if (name === 'clear_summary_month') { summaries.set(String(args.p_year), 'rebuilt'); return {}; }
      if (name === 'refresh_summary_month' && opts.monthError) return { error: {message:'timeout'} };
      return {};
    } }
  });
  let error;
  try { await vm.runInContext('(async()=>{' + code + '})()', ctx); } catch (e) { error = e; }
  return { calls, summaries, error };
}
test('monthly sales refresh only the supplied month, without year discovery', async () => {
  const { calls, error } = await run({ detailedChunks: {'2026-10': {rows:[]}} });
  assert.equal(error, undefined);
  assert.deepEqual(calls.map(c=>c[0]), ['refresh_summary_month','refresh_cache_filters']);
  assert.equal(calls[0][1].p_year, 2026);
  assert.equal(calls[0][1].p_month, 10);
});
test('overlapping history and monthly periods are rebuilt only once', async () => {
  const { calls, error } = await run({ historyChunks: {'2026-09':{},'2026-10':{}}, detailedChunks: {'2026-10':{}} });
  assert.equal(error, undefined);
  const refreshes = calls.filter(c=>c[0]==='refresh_summary_month');
  assert.deepEqual(refreshes.map(c=>c[1].p_month), [9,10]);
});
for (const key of ['clients','newProducts']) {
  test('cadastro refresh preserves historical recalculation: '+key, async () => {
    const { calls, error } = await run({ [key]: [{}] });
    assert.equal(error, undefined);
    assert.equal(calls[0][0], 'get_available_years');
    const refreshes = calls.filter(c=>c[0]==='refresh_summary_month');
    assert.equal(refreshes.length, 36);
    assert.deepEqual([...new Set(refreshes.map(c=>c[1].p_year))], [2024,2025,2026]);
    assert.equal(calls.filter(c=>c[0]==='refresh_cache_filters').length,36);
  });
}
test('failed discovery does not touch summaries',async()=>{
  const {calls,error}=await run({clients:[{}]},{discoveryError:true});
  assert.match(error.message,/discovery failed/);
  assert.equal(calls.length,1);
});
test('invalid sales period fails before any cache calls',async()=>{
  const {calls,error}=await run({detailedChunks:{'2026-13':{}}});
  assert.match(error.message,/Período inválido/);
  assert.equal(calls.length,0);
});
test('atomic month refresh can retry without append duplication',async()=>{
  const {calls,error}=await run({detailedChunks:{'2026-10':{}}},{monthError:true});
  assert.match(error.message,/timeout/);
  assert.equal(calls.filter(c=>c[0]==='refresh_summary_month').length,3);
  assert.equal(calls.filter(c=>c[0]==='refresh_cache_filters').length,0);
});
test('non-sales imports do not rebuild summaries', async () => {
  const {calls,error} = await run({notaPerfeita:[{}]});
  assert.equal(error, undefined);
  assert.equal(calls.length, 0);
});

const rosterStart=source.indexOf('        // Sales imports without a new client file');
const rosterEnd=source.indexOf("        statusText.textContent = 'Processando...';",rosterStart);
assert.ok(rosterStart>=0 && rosterEnd>rosterStart);
const rosterCode=source.slice(rosterStart,rosterEnd);
async function roster(error) {
  const statusText={},progressBar={style:{}},generateBtn={disabled:true},seen=[];
  const context=vm.createContext({files:{salesCurrMonthFile:{}},statusText,progressBar,generateBtn,AppLog:{error(){}},
    supabase: {
      from(table) {
        seen.push(table);
        return {
          select(fields) { seen.push(fields); return this; },
          order() { return this; },
          async range(offset) {
            return error ? {error:{message:'offline'}} : {data:offset ? [] : [{codigo_cliente:'1000',rca1:'100'}]};
          }
        };
      }
    }
  });
  const result=await vm.runInContext('(async()=>{'+rosterCode+';return existingClientsMap})()',context);
  return {result,statusText,generateBtn,seen};
}
test('sales-only import loads complete existing client RCA assignments',async()=>{
  const {result,seen}=await roster(false);
  assert.equal(result[0].rca1,'100');
  assert.ok(seen.some(s=>s.includes('rca1')));
});
test('client lookup failure stops import before creating a worker',async()=>{
  const {result,statusText,generateBtn}=await roster(true);
  assert.equal(result,undefined);
  assert.match(statusText.textContent,/interrompida/);
  assert.equal(generateBtn.disabled,false);
});
