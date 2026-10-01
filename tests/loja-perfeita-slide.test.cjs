const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../src/js/presentation.js'),'utf8').split('// --- Loja Perfeita Slide Logic ---')[1];
function setup(){
 const ids=['filial','supervisor','vendedor','rede','cidade','pesquisador','cliente','reset-btn','loading','content','ranking-tbody','kpi-nota','kpi-auditorias','kpi-perfeitas','tbody','table-count'];
 const els=Object.fromEntries(ids.map(id=>['lp-slide-'+id,{value:'',dataset:{},classList:{add(){},remove(){}},innerHTML:'',textContent:'',events:{},addEventListener(k,cb){this.events[k]=cb;}}]));
 const calls=[];let pending=[];let delayed=false;
 const payload=(name='MAX')=>({filter_options:{combinations:[{filiais:'05',supervisores:'RÔMULO',vendedores:'GIULIANO',redes:'REDE X',cidades:'ILHEUS',pesquisadores:'MAX'},{filiais:'08',supervisores:'TIAGO',vendedores:'DEVISON',redes:null,cidades:'ITABUNA',pesquisadores:'<x>'}],filiais:['05','08'],supervisores:['RÔMULO'],vendedores:['GIULIANO'],redes:['REDE X'],cidades:['ILHEUS'],pesquisadores:['MAX','<x>']},researcher_ranking:[{researcher:name,clients:2,avg_score:75}],kpis:{avg_score:75,total_audits:2,perfect_stores:1},chart_data:[],clients:[]});
 const context={window:{},document:{getElementById:id=>els[id]||null},console,setTimeout,clearTimeout,Date,supabase:{rpc:async(name,params)=>{calls.push({name,params});if(delayed)return await new Promise(resolve=>pending.push(resolve));return {data:payload()};}}};
 const helper=fs.readFileSync(path.join(__dirname,'../src/js/loja-perfeita-filters.mjs'),'utf8').replace(/export /g,'');
 vm.runInNewContext(helper+'\n'+source,context);
 return {els,calls,context,payload,pending,delay:()=>{delayed=true;}};
}
test('survey filter options, actual values and new period are used by existing listeners',async()=>{
 const t=setup();await t.context.window.initLojaPerfeitaSlide(2026,9);
 assert.match(t.els['lp-slide-supervisor'].innerHTML,/RÔMULO/);
 assert.match(t.els['lp-slide-pesquisador'].innerHTML,/&lt;x&gt;/);
 t.els['lp-slide-pesquisador'].value='MAX';await t.els['lp-slide-pesquisador'].events.change();
 assert.equal(t.calls.at(-1).params.p_pesquisador[0],'MAX');
 await t.context.window.initLojaPerfeitaSlide(2026,8);
 await t.els['lp-slide-filial'].events.change();
 assert.equal(t.calls.at(-1).params.p_mes,8);
 assert.match(t.els['lp-slide-ranking-tbody'].innerHTML,/75,0/);
 await t.els['lp-slide-reset-btn'].events.click();
 assert.equal(t.calls.at(-1).params.p_pesquisador,null);
});
test('slow older filter response cannot overwrite the latest ranking',async()=>{
 const t=setup();await t.context.window.initLojaPerfeitaSlide(2026,9);t.delay();
 const first=t.els['lp-slide-cidade'].events.change();const second=t.els['lp-slide-cidade'].events.change();
 t.pending[1]({data:t.payload('NEW')});await second;
 t.pending[0]({data:t.payload('OLD')});await first;
 assert.match(t.els['lp-slide-ranking-tbody'].innerHTML,/NEW/);assert.doesNotMatch(t.els['lp-slide-ranking-tbody'].innerHTML,/OLD/);
});

test('supervisor cascades vendors and clears an incompatible previous vendor before RPC',async()=>{
 const t=setup();await t.context.window.initLojaPerfeitaSlide(2026,9);
 t.els['lp-slide-vendedor'].value='DEVISON';await t.els['lp-slide-vendedor'].events.change({target:t.els['lp-slide-vendedor']});
 t.els['lp-slide-supervisor'].value='RÔMULO';await t.els['lp-slide-supervisor'].events.change({target:t.els['lp-slide-supervisor']});
 assert.match(t.els['lp-slide-vendedor'].innerHTML,/GIULIANO/);
 assert.doesNotMatch(t.els['lp-slide-vendedor'].innerHTML,/DEVISON/);
 assert.equal(t.calls.at(-1).params.p_vendedor,null);
 assert.equal(t.calls.at(-1).params.p_supervisor[0],'RÔMULO');
 await t.els['lp-slide-reset-btn'].events.click();
 await new Promise(resolve=>setImmediate(resolve));
 assert.match(t.els['lp-slide-vendedor'].innerHTML,/DEVISON/);
});
