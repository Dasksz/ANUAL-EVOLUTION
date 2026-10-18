import {test} from 'node:test';
import assert from 'node:assert/strict';
import {targetSeries,targetDatasets,applyOfficialTotals,commercialGroups} from '../src/js/dashboard-goals.mjs';
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
