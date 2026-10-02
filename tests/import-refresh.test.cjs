const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8');
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
      if (name === 'refresh_summary_chunk' && opts.chunkError) return { error: {message:'timeout'} };
      return {};
    } }
  });
  let error;
  try { await vm.runInContext('(async()=>{' + code + '})()', ctx); } catch (e) { error = e; }
  return { calls, summaries, error };
}
for (const data of [
  { detailedChunks: {'2026-10': {rows:[]}} },
  { clients: [{}] },
  { newProducts: [{}] },
]) {
  test('partial import refresh retains all historical years: ' + Object.keys(data)[0], async () => {
    const { calls, error } = await run(data);
    assert.equal(error, undefined);
    assert.equal(calls[0][0], 'get_available_years');
    const clears = calls.filter(c => c[0] === 'clear_summary_month');
    assert.equal(clears.length, 36);
    assert.deepEqual([...new Set(clears.map(c=>c[1].p_year))], [2026,2025,2024]);
    for (const [, {p_year, p_month}] of clears) {
      const clearIndex = calls.findIndex(c => c[0] === 'clear_summary_month' && c[1].p_year === p_year && c[1].p_month === p_month);
      const next = calls[clearIndex+1];
      assert.equal(next[0], 'refresh_summary_chunk', 'clear only the month immediately being rebuilt');
      assert.equal(next[1].p_start_date, `${p_year}-${String(p_month).padStart(2,'0')}-01`);
    }
    assert.equal(calls.filter(c=>c[0] === 'refresh_cache_filters').length, 36);
  });
}
test('failed year discovery leaves every existing summary untouched', async () => {
  const {calls,summaries,error} = await run({detailedChunks:{'2026-10':{}}}, {discoveryError:true});
  assert.match(error.message, /discovery failed/);
  assert.equal(calls.length, 1);
  assert.ok([...summaries.values()].every(v=>v==='preserved'));
});
test('ambiguous append timeout is not retried and other periods are untouched', async () => {
  const {calls,summaries,error} = await run({detailedChunks:{'2026-10':{}}}, {chunkError:true});
  assert.match(error.message, /timeout/);
  assert.equal(calls.filter(c=>c[0]==='refresh_summary_chunk').length, 1);
  assert.equal(calls.filter(c=>c[0]==='clear_summary_month').length, 1);
  assert.equal(summaries.get('2025'), 'preserved');
  assert.equal(summaries.get('2024'), 'preserved');
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
