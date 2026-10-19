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
  const changedSalesPeriods = opts.changedSalesPeriods || [
    ...Object.keys(data.historyChunks || {}), ...Object.keys(data.detailedChunks || {})
  ];
  const ctx = vm.createContext({ data, Date, Number, Set, Object,
    clientsChanged: opts.clientsChanged ?? false,
    changedSalesPeriods,
    refreshJobId: null,
    updateStatus() {},
    clearTable(table) { throw Error('Global wipe forbidden: ' + table); },
    retryOperation: async fn => { for (let i=0; i<3; i++) { try { return await fn(); } catch (e) { if (i===2) throw e; } } },
    supabase: { functions: { invoke: async () => ({}) }, rpc: async (name, args) => {
      calls.push([name, args]);
      if (name === 'elma_get_dashboard_refresh_periods') return opts.discoveryError
        ? { error: {message:'discovery failed'} }
        : { data: opts.periods || Array.from({length:36},(_,i)=>({ano:2024+Math.floor(i/12),mes:(i%12)+1})) };
      if (name === 'elma_enqueue_dashboard_goal_refresh' && opts.queueError) return { error: {message:opts.queueError} };
      if (name === 'elma_enqueue_dashboard_goal_refresh') return { data: {job_id:'job-1'} };
      return {};
    },
      from: () => ({ select: () => ({ eq: async () => ({data:[],error:null}) }) })
    }
  });
  let error;
  try { await vm.runInContext('(async()=>{' + code + '})()', ctx); } catch (e) { error = e; }
  return { calls, summaries, error };
}
test('monthly sales enqueue only the changed month, without historical discovery', async () => {
  const { calls, error } = await run({ detailedChunks: {'2026-10': {rows:[]}} });
  assert.equal(error, undefined);
  assert.deepEqual(calls.map(c=>c[0]), ['elma_enqueue_dashboard_goal_refresh']);
  assert.deepEqual(JSON.parse(JSON.stringify(calls[0][1].p_periods)), [{year:2026,month:10}]);
});
test('overlapping history and monthly periods are enqueued only once', async () => {
  const { calls, error } = await run({ historyChunks: {'2026-09':{},'2026-10':{}}, detailedChunks: {'2026-10':{}} });
  assert.equal(error, undefined);
  const queue = calls.find(c=>c[0]==='elma_enqueue_dashboard_goal_refresh');
  assert.deepEqual(JSON.parse(JSON.stringify(queue[1].p_periods)), [{year:2026,month:9},{year:2026,month:10}]);
});
for (const key of ['clients','newProducts']) {
  test('cadastro refresh enqueues all existing periods: '+key, async () => {
    const { calls, error } = await run({ [key]: [{}] },{clientsChanged:key==='clients'});
    assert.equal(error, undefined);
    assert.equal(calls[0][0], 'elma_get_dashboard_refresh_periods');
    const queue = calls.find(c=>c[0]==='elma_enqueue_dashboard_goal_refresh');
    assert.equal(queue[1].p_periods.length, 36);
    assert.deepEqual([...new Set(queue[1].p_periods.map(p=>p.year))], [2024,2025,2026]);
  });
}
test('failed discovery does not touch summaries',async()=>{
  const {calls,error}=await run({clients:[{}]},{clientsChanged:true,discoveryError:true});
  assert.match(error.message,/discovery failed/);
  assert.equal(calls.length,1);
});
test('invalid sales period fails before queueing',async()=>{
  const {calls,error}=await run({detailedChunks:{'2026-13':{}}});
  assert.match(error.message,/Período inválido/);
  assert.equal(calls.length,0);
});
test('a successful upload with no changed rows does not enqueue work',async()=>{
  const {calls,error}=await run({detailedChunks:{'2026-10':{}}},{changedSalesPeriods:[]});
  assert.equal(error,undefined);
  assert.equal(calls.length,0);
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

const productStart=source.indexOf('        let existingProductsMap = null;');
const productEnd=source.indexOf("        statusText.textContent = 'Processando...';",productStart);
assert.ok(productStart>=0 && productEnd>productStart);
async function loadPackaging(fail=false) {
  const offsets=[],statusText={},generateBtn={disabled:true};
  const context=vm.createContext({files:{salesCurrMonthFile:{}},statusText,generateBtn,AppLog:{error(){}},
    supabase:{from(table){assert.equal(table,'dim_produtos');return {
      select(fields){assert.equal(fields,'codigo,qtde_embalagem_master');return this;},order(){return this;},
      async range(offset){offsets.push(offset);return fail?{error:{message:'offline'}}:{data:offset===0?
        Array.from({length:1000},(_,i)=>({codigo:String(i),qtde_embalagem_master:28})):
        [{codigo:'last',qtde_embalagem_master:12}]};}
    };}}
  });
  const result=await vm.runInContext('(async()=>{'+source.slice(productStart,productEnd)+';return existingProductsMap})()',context);
  return {result,offsets,statusText,generateBtn};
}
test('packaging lookup fetches every page before processing sales',async()=>{
  const {result,offsets}=await loadPackaging();
  assert.equal(result.length,1001);
  assert.equal(result.at(-1).qtde_embalagem_master,12);
  assert.deepEqual(offsets,[0,1000]);
});
test('packaging lookup failure stops import before a guessed conversion',async()=>{
  const {result,statusText,generateBtn}=await loadPackaging(true);
  assert.equal(result,undefined);
  assert.match(statusText.textContent,/interrompida/);
  assert.equal(generateBtn.disabled,false);
});

