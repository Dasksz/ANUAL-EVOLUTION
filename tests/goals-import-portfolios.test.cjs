const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const parser=source.slice(source.indexOf('        function parseGoalsSvStructure(text) {'),source.indexOf('        // --- Event Listeners for Import ---'));
function fixture(){
 const rows=Array.from({length:3},()=>Array(51).fill(''));
 const block=(i,cat,metric)=>{rows[0][i]=cat;rows[1][i]=metric;rows[2][i]='Meta';rows[2][i+1]='Ajuste';};
 block(2,'TOTAL ELMA','FATURAMENTO');block(4,'','POSITIVAÇÃO');block(6,'EXTRUSADOS','FATURAMENTO');block(8,'','POSITIVAÇÃO');block(10,'NÃO EXTRUSADOS','FATURAMENTO');block(12,'','POSITIVAÇÃO');block(14,'TORCIDA','FATURAMENTO');block(16,'','POSITIVAÇÃO');
 for(const [i,cat] of [[18,'KG ELMA'],[40,'KG FOODS']]){rows[0][i]=cat;rows[1][i]='MÉDIA TRIM.';rows[2][i]='Volume';rows[1][i+1]='META KG';rows[2][i+1]='Volume';rows[2][i+2]='Ajuste';}
 for(const [i,cat] of [[21,'MIX SALTY'],[43,'MIX FOODS']]){rows[0][i]=cat;rows[1][i]='MÉDIA TRIM.';rows[2][i]='Qtd';rows[1][i+1]='META MIX';rows[2][i+1]='Meta';rows[2][i+2]='Aj.';}
 block(24,'TOTAL FOODS','FATURAMENTO');block(26,'','POSITIVAÇÃO');block(28,'TODDYNHO','FATURAMENTO');block(30,'','POSITIVAÇÃO');block(32,'TODDY','FATURAMENTO');block(34,'','POSITIVAÇÃO');block(36,'QUAKER / KEROCOCO','FATURAMENTO');block(38,'','POSITIVAÇÃO');
 rows[0][46]='GERAL';rows[1][46]='FATURAMENTO';rows[2][46]='Média Trim.';rows[2][47]='Meta';rows[1][48]='TONELADA';rows[2][48]='Meta';rows[1][49]='POSITIVAÇÃO';rows[2][49]='Meta';rows[0][50]='AUDITORIA PEDEV';rows[1][50]='META';
 for(const [code,name,mult] of [[312,'VENDEDOR A',1],[312,'VENDEDOR A',2],[324,'VENDEDOR B',3]])rows.push([code,name,...Array.from({length:49},(_,i)=>(i+1)*mult)]);
 rows.push(['SV2','SUPERVISOR',...Array(49).fill(999999)]);
 return rows;
}
function parse(rows=fixture()){
 const names=new Map([['312','VENDEDOR A'],['324','VENDEDOR B']]);
 const ctx=vm.createContext({console:{log(){},warn(){}},globalRcaNameByCode:names,globalRcaCodeByName:new Map([...names].map(([c,n])=>[n,c])),globalSupervisors:new Set()});vm.runInContext(parser,ctx);
 return ctx.parseGoalsSvStructure(rows.map(r=>r.map(v=>v??'').join('\t')).join('\n'));
}
test('separate portfolios are summed for every category and metric, excluding subtotals',()=>{
 const result=parse();assert.equal(result.length,48);
 const mapping=[['707','rev',7],['707','pos',9],['708','rev',11],['708','pos',13],['752','rev',15],['752','pos',17],['1119_TODDYNHO','rev',29],['1119_TODDYNHO','pos',31],['1119_TODDY','rev',33],['1119_TODDY','pos',35],['1119_QUAKER_KEROCOCO','rev',37],['1119_QUAKER_KEROCOCO','pos',39],['tonelada_elma','vol',20],['tonelada_foods','vol',42],['mix_salty','mix',23],['mix_foods','mix',45],['total_elma','pos',5],['total_foods','pos',27],['pepsico_all','pos',49],['total_elma','rev',3],['total_foods','rev',25],['pepsico_all','rev',47],['pepsico_all','vol',48],['pedev','pos',50]];
 for(const [cat,type,col] of mapping)for(const code of ['312','324']){const r=result.find(r=>r.codusur===code&&r.category===cat&&r.type===type);assert.ok(r,cat+' '+type);assert.equal(r.val,(col-1)*3);}
});
test('blank adjustment falls back to Volume, explicit zero and raw precision are preserved',()=>{
 const rows=fixture();rows[3][20]='';rows[4][20]=0;rows[5][20]=1359.041;
 const result=parse(rows);assert.equal(result.find(r=>r.codusur==='312'&&r.category==='tonelada_elma').val,rows[3][19]);assert.equal(result.find(r=>r.codusur==='324'&&r.category==='tonelada_elma').val,1359.041);
});
test('accented and damaged non-extruded headers cannot overwrite Extrusados',()=>{
 for(const header of ['NÃO EXTRUSADOS','NAO EXTRUSADOS','N�O EXTRUSADOS']){const rows=fixture();rows[0][10]=header;const result=parse(rows);assert.equal(result.find(r=>r.codusur==='312'&&r.category==='707'&&r.type==='rev').val,18);assert.equal(result.find(r=>r.codusur==='312'&&r.category==='708'&&r.type==='rev').val,30);}
});
