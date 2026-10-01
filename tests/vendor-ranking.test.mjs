import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {isVendorRankingEligible} from '../src/js/vendor-ranking.mjs';
import {ranking} from '../src/js/presentation-dispute.mjs';
test('excludes seller 190 while retaining supervisor 190 and other sellers',()=>{
 for (const row of [{codusur:190},{codusur:'00190'},{codigo_vendedor:'190'},{vendedor_codigo:'190'},{CODUSUR:'190'},{vendedor:'TIAGO JOSÉ DE SOUZA GOMES'},{vendedor_nome:'TIAGO JOSE DE SOUZA GOMES'}]) assert.equal(isVendorRankingEligible(row),false);
 for(const row of [{codusur:'282',codsupervisor:'190'},{codusur:'2',supervisor_nome:'TIAGO JOSÉ DE SOUZA GOMES'},{codusur:'2',vendedor:'TIAGO JOSÉ DE SOUZA GOMES'},{vendedor:'Outro',supervisor_nome:'TIAGO JOSÉ DE SOUZA GOMES'}]) assert.equal(isVendorRankingEligible(row),true);
});
test('dispute fills the Top 3 from eligible vendors in every metric',()=>{
 const base={equipe:'SHARK',faturamento:200,fat_trim:100,tonelada:200,ton_trim:100,posituacoes:200,pos_trim:100};
 const rows=[{...base,codusur:'190',faturamento:9999},...['1','2','3'].map(codusur=>({...base,codusur}))];
 for(const metric of ['geral','faturamento','tonelada','posituacao'])assert.deepEqual(ranking(rows,metric,'SHARK').map(r=>r.codusur),['1','2','3']);
});
test('all identified vendor ranking entry points use the shared rule',()=>{
 const presentation=fs.readFileSync(new URL('../src/js/presentation.js',import.meta.url),'utf8');
 const app=fs.readFileSync(new URL('../src/js/app.js',import.meta.url),'utf8');
 assert.match(presentation,/globalVendedoresData = \(data.top_vendedores \|\| \[\]\).filter\(isVendorRankingEligible\)/);
 assert.match(presentation,/vendedoresData = vendedoresData.filter\(isVendorRankingEligible\)/);
 assert.equal((app.match(/estrelasDetailedData.filter\(isVendorRankingEligible\).sort/g)||[]).length,3);
});
