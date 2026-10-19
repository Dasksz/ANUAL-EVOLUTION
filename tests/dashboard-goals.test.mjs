import {test} from 'node:test';
import assert from 'node:assert/strict';
import {targetSeries,targetDatasets,applyOfficialTotals,commercialGroups,attributionNotice,validateImport,importReconciliation} from '../src/js/dashboard-goals.mjs';
test('a missing allocation cannot silently become zero or a partial total',()=>{
 const payload={chart_data:[{mes:10,origem:'planilha',metas:[{metrica:'FAT',valor:10},{metrica:'FAT',valor:null}]},{mes:11,origem:'planilha',metas:[{metrica:'FAT',valor:0}]}]};
 assert.equal(targetSeries(payload,'FAT')[9],null);assert.equal(targetSeries(payload,'FAT')[10],0);
 assert.equal(targetDatasets(payload,'FAT').length,1);
 assert.equal(targetSeries(payload,'FAT',undefined,{month:10})[10],null);
});
test('imported and estimated targets remain distinct and mix never sums both families',()=>{
 const payload={chart_data:[{mes:10,origem:'planilha',metas:[{metrica:'MIX',categoria:'mix_salty',valor:1381},{metrica:'MIX',categoria:'mix_foods',valor:299}]},{mes:11,origem:'estimativa',metas:[{metrica:'FAT',valor:50}]}]};
 assert.equal(targetSeries(payload,'MIX','mix_salty')[9],1381);
 assert.equal(targetSeries(payload,'MIX','mix_foods')[9],299);
 assert.equal(targetDatasets(payload,'FAT')[0].label,'Meta estimada');
});
test('official hierarchy replaces subtotal, never adds to seller totals; PDEV is excluded',()=>{
 const totals={geral:{metaFat:100,metaPos:9},pedev:{metaPos:0}};
 const rows=[{nivel:'empresa',categoria:'pepsico_all',metrica:'FAT',valor:101},{nivel:'supervisor',codigo_entidade:'12',categoria:'pepsico_all',metrica:'FAT',valor:80},{nivel:'empresa',categoria:'pepsico_all',metrica:'POS',valor:0},{nivel:'empresa',categoria:'pedev',metrica:'POS',valor:1686}];
 applyOfficialTotals(totals,rows,'empresa');assert.equal(totals.geral.metaFat,101);assert.equal(totals.geral.metaPos,0);assert.equal(totals.pedev.metaPos,0);
});
test('Quaker and Kerococo form one commercial group',()=>{assert.deepEqual(commercialGroups(['1119_QUAKER','1119_KEROCOCO']),['1119_QUAKER_KEROCOCO']);});

test('pending notice counts portfolios within the selected month, never adds different metrics',()=>{
 const status={pendencias:[{mes:8,source_seller:'1',metrica:'FAT',valor:200},{mes:8,source_seller:'1',metrica:'POS',valor:3},{mes:9,source_seller:'2'}]};
 assert.match(attributionNotice(status,8),/Há 1 carteira/);
 assert.doesNotMatch(attributionNotice(status,10),/pendentes/);
 assert.match(attributionNotice(status),/Há 2 carteira/);
});

test('import preview requires company reference and all commercial targets but permits blank PDEV',()=>{
 const rows=Array.from({length:23},(_,i)=>({nivel:'empresa',codigo_entidade:'GV',category:'metric'+i,type:'rev'}));
 assert.deepEqual(validateImport(rows),[]);
 assert.match(validateImport(rows.map(r=>({...r,nivel:'vendedor'}))).join(' '),/positivação geral/);
 assert.match(validateImport(rows.slice(1)).join(' '),/faltam indicadores/);
 assert.deepEqual(validateImport([...rows,{nivel:'empresa',codigo_entidade:'GV',category:'pedev',type:'pos'}]),[]);
});

test('import reconciliation compares leaf revenue and kg, excludes supervisors and independent POS',()=>{
 const rows=[{nivel:'vendedor',category:'pepsico_all',type:'rev',val:100},{nivel:'supervisor',category:'pepsico_all',type:'rev',val:100},{nivel:'empresa',category:'pepsico_all',type:'rev',val:90},{nivel:'vendedor',category:'pepsico_all',type:'pos',val:500},{nivel:'empresa',category:'pepsico_all',type:'pos',val:9}];
 assert.equal(importReconciliation(rows).length,1);
 assert.equal(rows[2].val,90,'reported company target must never be silently rewritten');
 rows[2].val=100.01;assert.deepEqual(importReconciliation(rows),[]);
});
