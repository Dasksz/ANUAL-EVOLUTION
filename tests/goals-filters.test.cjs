const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');

const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const setup=source.slice(source.indexOf('async function setupGoalsFilters('),source.indexOf('// --- IMPORT MODAL LOGIC ---'));

function node(id){
  const classes=new Set(id.endsWith('-dropdown')?['hidden']:[]);
  return {
    id,value:'',innerHTML:'',options:[],dataset:{},events:{},
    classList:{contains:name=>classes.has(name),add:name=>classes.add(name),remove:name=>classes.delete(name),toggle(name){classes.has(name)?classes.delete(name):classes.add(name)}},
    querySelector:()=>({textContent:''}),
    addEventListener(type,callback){(this.events[type]??=[]).push(callback)},
    contains(target){return target===this||target?.parentElement===this}
  };
}

function environment(){
  const ids=['goals-filter-ano','goals-filter-mes','goals-filter-filial-btn','goals-filter-filial-dropdown','goals-filter-fornecedor-btn','goals-filter-fornecedor-dropdown','goals-filter-supervisor-btn','goals-filter-supervisor-dropdown','goals-filter-vendedor-btn','goals-filter-vendedor-dropdown','goals-filter-categoria-btn','goals-filter-categoria-dropdown','import-goals-ano','import-goals-mes','goals-view','goals-clear-filters-btn'];
  const nodes=new Map(ids.map(id=>[id,node(id)]));
  const callbacks=new Map();
  const filters={filiais:[],fornecedores:[],supervisores:[],vendedores:[],categorias:[]};
  const dropdowns=ids.filter(id=>id.endsWith('-dropdown')).map(id=>nodes.get(id));
  let renderCalls=0;
  let documentClick;
  const ctx=vm.createContext({
    window:{goalsMultiFilters:filters,setupMultiSelect(btn,dropdown,container,items,selected,callback){
      callbacks.set(btn.id,{items,selected,callback});
      btn.onclick=event=>{
        event?.stopPropagation?.();
        const wasHidden=dropdown.classList.contains('hidden');
        dropdowns.forEach(menu=>menu.classList.add('hidden'));
        if(wasHidden) dropdown.classList.remove('hidden');
      };
    }},
    document:{getElementById:id=>nodes.get(id),querySelectorAll:()=>[],addEventListener(type,callback){if(type==='click')documentClick=callback}},
    supabase:{rpc:async()=>({data:{anos:[2026],filiais:['05','08'],fornecedores:[{cod:'708',name:'Ñ EXTRUSADOS'}],supervisors:['RÔMULO AMADO DA','TIAGO JOSÉ DE S'],vendedores:['282','21'],categorias:['DORITOS']}})},
    getDefaultFilterDates:()=>({currentYear:'2026',currentMonth:'10'}),
    setTimeout:callback=>{callback();return 1},clearTimeout(){},console:{error(){}},
    renderGoalsView(){renderCalls++},renderGoalsChart(){},currentGoalsMetric:'fat',
    handleDropdownsClickaway(event,menus,buttons){
      let anyClosed=false;
      menus.forEach((menu,index)=>{
        if(menu&&!menu.classList.contains('hidden')&&!menu.contains(event.target)&&!buttons[index]?.contains(event.target)){
          menu.classList.add('hidden');
          anyClosed=true;
        }
      });
      return anyClosed;
    }
  });
  vm.runInContext(setup,ctx);
  return {ctx,nodes,callbacks,filters,documentClick:target=>documentClick({target}),renderCalls:()=>renderCalls};
}

test('goals filters retain existing selections when another filter changes',async()=>{
  const e=environment();
  e.filters.fornecedores.push('708');
  e.filters.supervisores.push('RÔMULO AMADO DA');
  e.filters.vendedores.push('282');
  await e.ctx.setupGoalsFilters();

  e.filters.fornecedores.push('707');
  e.callbacks.get('goals-filter-fornecedor-btn').callback();
  assert.deepEqual(e.filters.supervisores,['RÔMULO AMADO DA']);
  assert.deepEqual(e.filters.vendedores,['282']);

  e.filters.categorias.push('DORITOS');
  e.callbacks.get('goals-filter-categoria-btn').callback();
  assert.deepEqual(e.filters.fornecedores,['708','707']);
  assert.deepEqual(e.filters.supervisores,['RÔMULO AMADO DA']);

  e.filters.supervisores.push('TIAGO JOSÉ DE S');
  e.callbacks.get('goals-filter-supervisor-btn').callback();
  assert.deepEqual(e.filters.fornecedores,['708','707']);
  assert.deepEqual(e.filters.categorias,['DORITOS']);
  assert.deepEqual(e.filters.vendedores,['282']);
});

test('selecting filters and switching lists waits for an outside click, then renders once',async()=>{
  const e=environment();
  await e.ctx.setupGoalsFilters();

  const supervisorButton=e.nodes.get('goals-filter-supervisor-btn');
  const supervisorDropdown=e.nodes.get('goals-filter-supervisor-dropdown');
  supervisorButton.onclick({stopPropagation(){}});
  e.filters.supervisores.push('RÔMULO AMADO DA');
  e.callbacks.get(supervisorButton.id).callback();
  assert.equal(e.renderCalls(),0);

  const supplierButton=e.nodes.get('goals-filter-fornecedor-btn');
  const supplierDropdown=e.nodes.get('goals-filter-fornecedor-dropdown');
  supplierButton.onclick({stopPropagation(){}});
  e.documentClick(supplierButton);
  assert.equal(supervisorDropdown.classList.contains('hidden'),true);
  assert.equal(supplierDropdown.classList.contains('hidden'),false);
  assert.equal(e.renderCalls(),0,'switching to another list must not query');

  e.filters.fornecedores.push('708');
  e.callbacks.get(supplierButton.id).callback();
  assert.equal(e.renderCalls(),0,'selecting an item must remain pending while a list is open');

  e.documentClick({id:'empty-dashboard-area'});
  assert.equal(supplierDropdown.classList.contains('hidden'),true);
  assert.equal(e.renderCalls(),1,'all pending filters must be applied together');
});

test('year and month changes apply with closed lists and join pending filters when a list closes',async()=>{
  const e=environment();
  await e.ctx.setupGoalsFilters();
  const yearSelect=e.nodes.get('goals-filter-ano');

  yearSelect.value='2025';
  yearSelect.events.change[0]();
  assert.equal(e.renderCalls(),1,'date changes apply when no multiselect is open');

  const supervisorButton=e.nodes.get('goals-filter-supervisor-btn');
  const supervisorDropdown=e.nodes.get('goals-filter-supervisor-dropdown');
  supervisorButton.onclick({stopPropagation(){}});
  e.filters.supervisores.push('RÔMULO AMADO DA');
  e.callbacks.get(supervisorButton.id).callback();

  e.documentClick(yearSelect);
  assert.equal(supervisorDropdown.classList.contains('hidden'),true);
  assert.equal(e.renderCalls(),1,'clicking another filter control closes the list without an early query');
  yearSelect.value='2026';
  yearSelect.events.change[0]();
  assert.equal(e.renderCalls(),2,'the changed date and pending list selection are applied together');
});
