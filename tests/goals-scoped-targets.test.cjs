const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const render=source.slice(source.indexOf('async function renderGoalsView('),source.indexOf('async function renderGoalsChart(')).replace('tableBody.innerHTML = bodyHTML;', 'auditTotals = grandTotals; tableBody.innerHTML = bodyHTML;');
async function run({filters={},metas=[],growth=30,attribution_version=0,sellers=[{codusur:'1',vendedor_nome:'VENDEDOR',supervisor_nome:'SUP',total_fat_707:300,total_fat_elma:300,total_fat_geral:300,sum_pos_geral:30}]}={}){
 const elements={};const errors=[];const element=()=>({innerHTML:'',classList:{add(){},remove(){},toggle(){}},getAttribute:()=> 'true'});
 const base={scope_version:2,attribution_version,growth,sellers,metas,quarterMonths:[{key:'2026-06',label:'JUN'},{key:'2026-07',label:'JUL'},{key:'2026-08',label:'AGO'}]};
 const ctx={DashboardGoals:require('../src/js/dashboard-goals.mjs'),window:{goalsMultiFilters:filters},document:{getElementById:id=>elements[id]||(elements[id]=element()),querySelectorAll:()=>[]},AbortController,goalsViewAbortController:null,goalsChartAbortController:null,goalsViewRequest:0,setupGoalsDetailToggle(){},currentGoalsAno:2026,currentGoalsMes:9,renderGoalsChart(){},fetchGoalsQuery:async()=>({data:base}),globalRcaCodeByName:new Map(),globalRcaNameByCode:new Map(),globalSupervisors:new Set(),savedMetas:[],goalsData:null,console:{error:(...a)=>errors.push(a)},auditTotals:null};
 vm.createContext(ctx);vm.runInContext(render,ctx);await ctx.renderGoalsView({tableOnly:true,forceDetails:true});assert.deepEqual(errors,[]);
 return {totals:ctx.auditTotals,html:elements['goals-table-body']?.innerHTML||Object.values(elements).map(x=>x.innerHTML).join('')};
}
const meta=(categoria,metrica,valor_ajuste,codusur='1')=>({categoria,metrica,valor_ajuste,codusur});
test('scoped imported totals override history once, preserving explicit zero',async()=>{
 const r=await run({metas:[meta('707','FAT',80),meta('pepsico_all','FAT',75),meta('pepsico_all','POS',0),meta('mix_salty','MIX',12)]});
 assert.equal(r.totals.geral.metaFat,75);assert.equal(r.totals.geral.metaPos,0);assert.equal(r.totals.mix_salty.metaMix,12);
});
test('partial imported roster does not add fallback targets for other sellers',async()=>{
 const r=await run({metas:[meta('707','FAT',80),meta('mix_salty','MIX',12)],sellers:[{codusur:'1',vendedor_nome:'A',supervisor_nome:'SUP',total_fat_707:300},{codusur:'2',vendedor_nome:'B',supervisor_nome:'SUP',total_fat_707:600,sum_mix_salty:60}]});
 assert.equal(r.totals.geral.metaFat,80);assert.equal(r.totals.mix_salty.metaMix,12);
});
test('missing annual growth never invents the previous 10 percent default',async()=>{
 const r=await run({growth:null});assert.equal(r.totals.geral.metaFat,0);assert.equal(r.totals.geral.metaPos,0);
});
test('supplier allocations cannot overwrite integral imported targets',async()=>{
 const r=await run({filters:{fornecedores:['707']},metas:[meta('707','FAT',40),meta('tonelada_elma','VOL',10)]});
 assert.match(r.html,/readonly disabled/);assert.match(r.html,/Meta atribuída à carteira atual/);assert.equal(r.totals.geral.metaFat,40);
});
test('missing imported adjustment preserves derived category totals',async()=>{
 const r=await run({metas:[meta('707','FAT',80),meta('pepsico_all','FAT',null)]});
 assert.equal(r.totals.geral.metaFat,80);
});

test('attributed goals remain read-only without any filters',async()=>{const r=await run({attribution_version:1,metas:[meta('707','FAT',40),meta('tonelada_elma','VOL',10),meta('mix_salty','MIX',5)]});assert.match(r.html,/readonly disabled/);assert.equal(r.totals.mix_salty.metaMix,5);});
