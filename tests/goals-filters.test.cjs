const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');

const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const setup=source.slice(source.indexOf('async function setupGoalsFilters('),source.indexOf('// --- IMPORT MODAL LOGIC ---'));

function node(id){
  return {id,value:'',innerHTML:'',options:[],dataset:{},classList:{contains:()=>true,add(){},remove(){},toggle(){}},querySelector:()=>({textContent:''}),addEventListener(type,callback){this.events??={};this.events[type]=callback},contains:()=>true};
}

test('goals filters retain supervisor and vendor selections when other filters change',async()=>{
  const ids=['goals-filter-ano','goals-filter-mes','goals-filter-filial-btn','goals-filter-filial-dropdown','goals-filter-fornecedor-btn','goals-filter-fornecedor-dropdown','goals-filter-supervisor-btn','goals-filter-supervisor-dropdown','goals-filter-vendedor-btn','goals-filter-vendedor-dropdown','goals-filter-categoria-btn','goals-filter-categoria-dropdown','import-goals-ano','import-goals-mes','goals-view','goals-clear-filters-btn'];
  const nodes=new Map(ids.map(id=>[id,node(id)]));
  const callbacks=new Map();
  const filters={filiais:[],fornecedores:['708'],supervisores:['RÔMULO AMADO DA'],vendedores:['282'],categorias:[]};
  const ctx=vm.createContext({
    window:{goalsMultiFilters:filters,setupMultiSelect(btn,dropdown,container,items,selected,callback){callbacks.set(btn.id,{items,selected,callback})}},
    document:{getElementById:id=>nodes.get(id),querySelectorAll:()=>[],addEventListener(){}},
    supabase:{rpc:async()=>({data:{anos:[2026],filiais:['05','08'],fornecedores:[{cod:'708',name:'Ñ EXTRUSADOS'}],supervisors:['RÔMULO AMADO DA','TIAGO JOSÉ DE S'],vendedores:['282','21'],categorias:['DORITOS']}})},
    getDefaultFilterDates:()=>({currentYear:'2026',currentMonth:'10'}),
    setTimeout:()=>1,clearTimeout(){},console:{error(){}},renderGoalsView(){},renderGoalsChart(){},currentGoalsMetric:'fat'
  });
  vm.runInContext(setup,ctx);
  await ctx.setupGoalsFilters();

  filters.fornecedores.push('707');
  callbacks.get('goals-filter-fornecedor-btn').callback();
  assert.deepEqual(filters.supervisores,['RÔMULO AMADO DA']);
  assert.deepEqual(filters.vendedores,['282']);

  filters.categorias.push('DORITOS');
  callbacks.get('goals-filter-categoria-btn').callback();
  assert.deepEqual(filters.fornecedores,['708','707']);
  assert.deepEqual(filters.supervisores,['RÔMULO AMADO DA']);

  filters.supervisores.push('TIAGO JOSÉ DE S');
  callbacks.get('goals-filter-supervisor-btn').callback();
  assert.deepEqual(filters.fornecedores,['708','707']);
  assert.deepEqual(filters.categorias,['DORITOS']);
  assert.deepEqual(filters.vendedores,['282']);
});
