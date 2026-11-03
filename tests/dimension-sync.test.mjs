import test from 'node:test';
import assert from 'node:assert/strict';
import {changedDimensionRows,clientSummaryNeedsRefresh} from '../src/js/dimension-sync.mjs';

function database(records, error) {
  const calls=[];
  return {calls,from(table){return {select(columns){return {async in(key,ids){
    calls.push({table,columns,key,ids});
    return {error,data:records.filter(r=>ids.includes(String(r.codigo)))};
  }}}}}};
}
test('sales-carried identical rosters do not become historical changes; renamed and new codes do',async()=>{
  const db=database([{codigo:'1',nome:'Romulo'},{codigo:'2',nome:'Anterior'}]);
  assert.deepEqual(await changedDimensionRows(db,'dim_supervisores',[{codigo:'1',nome:'Romulo'}]),[]);
  const changed=[{codigo:'2',nome:'Atual'},{codigo:'3',nome:'Novo'}];
  assert.deepEqual(await changedDimensionRows(db,'dim_supervisores',[{codigo:'1',nome:'Romulo'},...changed]),changed);
});
test('product comparison normalizes API numeric/date representations and preserves omitted attributes',async()=>{
  const db=database([{codigo:'5',descricao:'Produto',codfor:'707',qtde_embalagem_master:'24.000',dt_cadastro:'2026-10-01',categoria_produto:'RUFFLES'}]);
  const row={codigo:'5',descricao:'Produto',codfor:'707',qtde_embalagem_master:24,dt_cadastro:'2026-10-01T00:00:00.000Z'};
  assert.deepEqual(await changedDimensionRows(db,'dim_produtos',[row]),[]);
  assert.deepEqual(await changedDimensionRows(db,'dim_produtos',[{...row,qtde_embalagem_master:12}]),[{...row,qtde_embalagem_master:12}]);
  assert.deepEqual(await changedDimensionRows(db,'dim_produtos',[{codigo:'5',dt_cadastro:null}]),[{codigo:'5',dt_cadastro:null}]);
  assert.deepEqual(await changedDimensionRows(db,'dim_produtos',[{codigo:'5',descricao:undefined}]),[]);
});
test('every roster key is compared beyond the first API page',async()=>{
  const rows=Array.from({length:1050},(_,i)=>({codigo:String(i),nome:'Vendedor '+i}));
  const db=database(rows);
  assert.deepEqual(await changedDimensionRows(db,'dim_vendedores',rows),[]);
  assert.equal(db.calls.length,6);
  assert.equal(db.calls.flatMap(c=>c.ids).length,1050);
  assert.ok(db.calls.every(c=>c.ids.length<=200));
});
test('failed comparison stops the upload, and missing inputs require no reads',async()=>{
  const db=database([],{message:'offline'});
  await assert.rejects(changedDimensionRows(db,'dim_fornecedores',[{codigo:'1',nome:'Nome'}]),/offline/);
  assert.deepEqual(await changedDimensionRows(db,'dim_produtos',null),[]);
  assert.equal(db.calls.length,1);
});

function clients(records, fail=false) {
  return {from(){return {select(){return {order(){return {async range(start,end){
    return fail?{error:{message:'offline'}}:{data:records.slice(start,end+1)};
  }}}}}}}};
}
test('daily last-purchase/contact changes still sync raw clients without rebuilding historical summaries',async()=>{
  const before={codigo_cliente:'1',rca1:'321',codsupervisor:null,cidade:'ILHEUS',ramo:'MERCADO',ultimacompra:'2026-10-01',telefone:'1'};
  assert.equal(await clientSummaryNeedsRefresh(clients([before]),[{...before,ultimacompra:'2026-11-03',telefone:'2'}]),false);
  for (const update of [{rca1:'78'},{cidade:'ITABUNA'},{ramo:'ATACADO'},{codsupervisor:'12'}]) {
    assert.equal(await clientSummaryNeedsRefresh(clients([before]),[{...before,...update}]),true);
  }
  assert.equal(await clientSummaryNeedsRefresh(clients([before]),[{...before},{...before,codigo_cliente:'2'}]),true);
  assert.equal(await clientSummaryNeedsRefresh(clients([before,{...before,codigo_cliente:'2'}]),[before]),true);
});
test('client projection checks all pages and fails closed on access errors',async()=>{
  const records=Array.from({length:1001},(_,i)=>({codigo_cliente:String(i),rca1:'321',cidade:'A',ramo:'B'}));
  assert.equal(await clientSummaryNeedsRefresh(clients(records),records),false);
  const changed=records.map(r=>({...r}));changed[1000].rca1='78';
  assert.equal(await clientSummaryNeedsRefresh(clients(records),changed),true);
  await assert.rejects(clientSummaryNeedsRefresh(clients([],true),records),/offline/);
});
