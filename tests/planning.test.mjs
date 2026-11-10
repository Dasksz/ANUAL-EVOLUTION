import test from 'node:test';
import assert from 'node:assert/strict';
import {validatePlanning,planSections,planActions,detailHtml,exportPlanPdf,createPlanningPanel} from '../src/js/planning.mjs';
const sku=(code,months=1,current=false)=>({code,name:'Produto '+code,family:'SALTY',months,current,averageValue:100,currentValue:current?20:0});
const clientRow=()=>({code:'27',name:'Cliente de teste',city:'Gandu',segment:'Mercado',sellerCode:'282',seller:'Matheus',supervisorCode:'12',supervisor:'Gomes',routes:[{day:'SEGUNDA',frequency:'Q1'}],visitDates:['2026-10-12','2026-10-26'],averageValue:300,currentValue:200,averageMix:3,currentMix:1,averageSalty:2,currentSalty:1,averageFoods:1,currentFoods:0,missing:2});
const snapshot=()=>({version:'v1',planningDate:'2026-10-29',month:'2026-10',historyStart:'2026-07',historyEnd:'2026-09',historyComplete:true,salesThrough:'2026-10-28',syncedAt:'2026-10-29T12:00:00Z',syncError:false,routeDates:['2026-10-12'],rows:[clientRow()],total:50,supervisors:[{code:'12',name:'Gomes'}],sellers:[{code:'282',name:'Matheus'}],kpis:{noSale:10,missing:20,currentValue:300}});
const detail=()=>({...snapshot(),...clientRow(),skus:[sku('2',1),sku('1',3),sku('3',2,true)],suggestions:[{code:'4',name:'SKU novo',family:'FOODS',buyers:4,peers:10,penetration:40}]});
test('separates recovery, current purchases and genuinely new SKUs in the period',()=>{const d=detail();d.suggestions.push({...d.suggestions[0],code:'3'});const p=planSections(d);assert.deepEqual(p.missing.map(s=>s.code),['1']);assert.deepEqual(p.maintain.map(s=>s.code),['3']);assert.deepEqual(p.suggestions.map(s=>s.code),['4']);assert.equal(d.skus[0].code,'2');});
test('incomplete history suppresses expansion and explains missing baseline',()=>{const d=detail();d.historyComplete=false;d.averageMix=null;assert.equal(planSections(d).suggestions.length,0);assert.match(planActions(d).join(' '),/Histórico incompleto/);});
test('empty current upload is not interpreted as a confirmed absence of purchases',()=>{const d=detail();d.salesThrough=null;assert.match(planActions(d)[0],/Aguardar a carga/);});
test('detail escapes names, routes and malicious source values',()=>{const d=detail();d.name='<script>alert(1)</script>';d.skus[0].name='<img src=x>';d.routes[0].day='<svg>';const html=detailHtml(d);assert.ok(!html.includes('<script>'));assert.ok(!html.includes('<img'));assert.match(html,/&lt;svg&gt;/);assert.match(html,/3 meses/);assert.match(html,/pelo menos 3 clientes/);});
test('validation rejects missing indicators and inconsistent SKU support',()=>{assert.equal(validatePlanning(snapshot()).total,50);assert.equal(validatePlanning(detail(),true).code,'27');const d=snapshot();d.rows[0].currentValue=NaN;assert.throws(()=>validatePlanning(d));const e=detail();e.suggestions[0].buyers=2;assert.throws(()=>validatePlanning(e,true));e.suggestions[0].buyers=11;assert.throws(()=>validatePlanning(e,true));});
test('PDF exports the selected action order rather than the full history',()=>{const texts=[],tables=[];let saved;class PDF{constructor(){this.lastAutoTable={finalY:50};}setFillColor(){}rect(){}setTextColor(){}setFontSize(){}splitTextToSize(s){return [s];}text(s){texts.push(s);}addPage(){}autoTable(o){tables.push(o);}getNumberOfPages(){return 1;}setPage(){}save(n){saved=n;}}exportPlanPdf(detail(),PDF);assert.match(saved,/Planejamento_27_2026-10.pdf/);assert.equal(tables.length,3);assert.ok(tables[2].body.some(r=>r[0].includes('Produto 1')));assert.ok(!tables[2].body.some(r=>r[0].includes('Produto 3')));assert.ok(texts.some(s=>s.includes('SUGESTÃO DE PEDIDO')));});
test('page and PDF present the same two stages without duplicating selected items',()=>{
 const d=detail();d.skus[0].idealCategory='DORITOS';d.skus[1].idealCategory='CHEETOS';d.averageMix=4;
 const html=detailHtml(d);assert.match(html,/pl-order-stages/);assert.ok(html.indexOf('id="pl-stage-one"')<html.indexOf('id="pl-stage-two"'));
 const texts=[],tables=[];class PDF{constructor(){this.lastAutoTable={finalY:50};}setFillColor(){}rect(){}setTextColor(){}setFontSize(){}splitTextToSize(s){return [s];}text(s){texts.push(s);}addPage(){}autoTable(o){tables.push(o);}getNumberOfPages(){return 1;}setPage(){}save(){}}
 exportPlanPdf(d,PDF);assert.ok(texts.some(s=>s.includes('ETAPA 1 - COMPLETAR MIX IDEAL')));assert.ok(texts.some(s=>s.includes('ETAPA 2 - COMPLEMENTAR PEDIDO')));
 const p=planSections(d).order;assert.equal(tables[1].body.length,2);assert.ok(tables[2].body.some(r=>r[0].includes('SKU novo')));
 for(const row of p.rows){assert.equal(html.split(`${row.code} · ${row.name}</strong>`).length-1,1);assert.equal(tables.slice(1).flatMap(t=>t.body).filter(r=>r[0].includes(`${row.code} · ${row.name}`)).length,1);}
});

class El{constructor(){this.value='';this.innerHTML='';this.textContent='';this.hidden=false;this.disabled=false;this.events={};}addEventListener(k,fn){(this.events[k]??=[]).push(fn);}fire(k,e={}){for(const fn of this.events[k]??[])fn({target:this,...e});}focus(){}setAttribute(k,v){this[k]=v;}}
function harness(t,responses=[snapshot()]){const els=new Map(),root=new El(),calls=[],intervals=new Map();let auth,clock=0;root.querySelector=selector=>{const k=selector.match(/data-pl="([^"]+)/)[1];if(!els.has(k))els.set(k,new El());return els.get(k);};const win={setInterval(fn){intervals.set(++clock,fn);return clock;},clearInterval(id){intervals.delete(id);},setTimeout(fn){fn();return 1;},clearTimeout(){}};const client={rpc(name,args){calls.push({name,args});const next=responses.shift();return {abortSignal:()=>next instanceof Promise?next:Promise.resolve(next?.error?next:{data:next})};},auth:{onAuthStateChange(fn){auth=fn;}}};const panel=createPlanningPanel({root,client,window:win,document:{visibilityState:'visible'}});root.querySelector('[data-pl="detail"]').hidden=true;t.after(()=>panel.deactivate());return {panel,calls,els,intervals,win,auth:()=>auth('SIGNED_OUT')};}
const tick=()=>new Promise(r=>setImmediate(r));
test('KPI filters reset pagination, preserve team/search and keep scope counts visible',async t=>{
 const filtered={...snapshot(),scopeTotal:50,total:1,status:'no-sale'};
 const h=harness(t,[snapshot(),snapshot(),snapshot(),snapshot(),snapshot(),filtered,snapshot()]);
 h.panel.activate();await tick();h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();h.els.get('seller').value='282';h.els.get('seller').fire('change');await tick();h.els.get('search').value='Cliente';h.els.get('search').fire('input');await tick();h.els.get('next').fire('click');await tick();
 h.els.get('kpis').fire('click',{target:{closest:()=>({dataset:{kpi:'no-sale'}})}});await tick();
 assert.equal(h.calls[5].args.p_status,'no-sale');assert.equal(h.calls[5].args.p_offset,0);assert.equal(h.calls[5].args.p_supervisor,'12');assert.equal(h.calls[5].args.p_seller,'282');assert.equal(h.calls[5].args.p_search,'Cliente');assert.match(h.els.get('count').textContent,/de 1 clientes/);assert.match(h.els.get('kpis').innerHTML,/data-kpi="all"[^>]*><span>Clientes de hoje<\/span><strong>50/);assert.match(h.els.get('kpis').innerHTML,/data-kpi="no-sale" aria-pressed="true"/);
 h.els.get('kpis').fire('click',{target:{closest:()=>({dataset:{kpi:'all'}})}});await tick();assert.equal(h.calls[6].args.p_status,'all');assert.equal(h.calls[6].args.p_supervisor,'12');
});
test('ideal and purchase KPIs persist through refresh, and orange reset clears every filter',async t=>{
 const h=harness(t,Array.from({length:7},snapshot));h.panel.activate();await tick();
 for(const key of ['ideal','purchased']){h.els.get('kpis').fire('click',{target:{closest:()=>({dataset:{kpi:key}})}});await tick();assert.equal(h.calls.at(-1).args.p_status,key);}
 h.els.get('refresh').fire('click');await tick();assert.equal(h.calls.at(-1).args.p_status,'purchased');h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();h.els.get('clear').fire('click');await tick();assert.equal(h.calls.at(-1).args.p_status,'all');assert.equal(h.calls.at(-1).args.p_supervisor,null);assert.equal(h.calls.at(-1).args.p_seller,null);assert.equal(h.calls.at(-1).args.p_search,'');
});
test('starts globally; supervisor change clears seller; pagination sends offsets',async t=>{const h=harness(t,[snapshot(),snapshot(),snapshot(),snapshot()]);h.panel.activate();await tick();assert.equal(h.calls[0].args.p_supervisor,null);h.els.get('seller').value='282';h.els.get('seller').fire('change');await tick();assert.equal(h.calls[1].args.p_seller,'282');h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();assert.equal(h.calls[2].args.p_seller,null);assert.equal(h.calls[2].args.p_supervisor,'12');h.els.get('next').fire('click');await tick();assert.equal(h.calls[3].args.p_offset,24);});
test('only the server-defined current day is used; the day selector is absent',async t=>{const h=harness(t,[snapshot(),snapshot()]);h.panel.activate();await tick();assert.equal(h.calls[0].name,'get_planning_filtered_v1');assert.equal(h.calls[0].args.p_day,'today');assert.ok(!('p_visit_date' in h.calls[0].args));assert.match(h.els.get('day').textContent,/29\/10\/2026/);assert.ok(!h.els.has('visit'));h.els.get('search').value='Cliente';h.els.get('search').fire('input');await tick();assert.equal(h.calls[1].args.p_search,'Cliente');});
test('stale list responses cannot overwrite newer filters',async t=>{let done;const pending=new Promise(r=>done=r);const fresh=snapshot();fresh.total=1;const h=harness(t,[pending,fresh]);h.panel.activate();h.els.get('refresh').fire('click');await tick();done({data:snapshot()});await tick();assert.match(h.els.get('count').textContent,/de 1 clientes/);});
test('logout clears visible data and stops background polling',async t=>{const h=harness(t);h.panel.activate();await tick();assert.ok(h.els.get('cards').innerHTML.includes('Cliente de teste'));h.auth();assert.equal(h.els.get('cards').innerHTML,'');assert.equal(h.intervals.size,0);});
test('late detail cannot reopen after returning to the portfolio',async t=>{let done;const pending=new Promise(r=>done=r);const h=harness(t,[snapshot(),pending]);h.panel.activate();await tick();h.els.get('cards').fire('click',{target:{closest:()=>({dataset:{client:'27'}})}});h.els.get('back').fire('click');done({data:detail()});await tick();assert.equal(h.els.get('detail').hidden,true);assert.equal(h.els.get('detail-body').innerHTML,'');});
test('portfolio and sales timestamps are distinct and pending calculations refresh automatically',async t=>{const pending={...snapshot(),salesPending:true,rosterSyncedAt:'2026-10-28T20:00:00Z',salesUpdatedAt:'2026-10-29T12:00:00Z'};const h=harness(t,[pending,snapshot()]);h.panel.activate();await tick();assert.match(h.els.get('updated').textContent,/28\/10\/2026/);assert.match(h.els.get('sales-status').textContent,/Recalculando/);for(const fn of h.intervals.values())fn();await tick();assert.equal(h.calls.length,2);assert.match(h.els.get('sales-status').textContent,/após cada carga/);});
test('pending client plans block PDF and refresh their detail when calculations finish',async t=>{const pending={...snapshot(),salesPending:true},pendingDetail={...detail(),salesPending:true},fresh={...snapshot(),version:'v2'},freshDetail={...detail(),version:'v2',currentValue:250};const h=harness(t,[pending,pendingDetail,fresh,freshDetail]);h.panel.activate();await tick();h.els.get('cards').fire('click',{target:{closest:()=>({dataset:{client:'27'}})}});await tick();assert.match(h.els.get('detail-body').innerHTML,/data-pl="pdf" disabled/);assert.throws(()=>exportPlanPdf(pendingDetail,null),/recalculadas/);for(const fn of h.intervals.values())fn();await tick();assert.equal(h.calls[3].args.p_version,'v2');assert.match(h.els.get('detail-body').innerHTML,/250,00/);assert.ok(!h.els.get('detail-body').innerHTML.includes('data-pl="pdf" disabled'));});

test('day rollover closes the old plan and resets pagination to the first page',async t=>{const tomorrow={...snapshot(),planningDate:'2026-10-30',total:1};const h=harness(t,[snapshot(),snapshot(),tomorrow,tomorrow]);h.panel.activate();await tick();h.els.get('next').fire('click');await tick();for(const fn of h.intervals.values())fn();await tick();assert.equal(h.calls[2].args.p_offset,24);assert.equal(h.calls[3].args.p_offset,0);assert.match(h.els.get('day').textContent,/30\/10\/2026/);assert.equal(h.els.get('detail').hidden,true);assert.match(h.els.get('count').textContent,/1–1 de 1/);});

test('yesterday toggles daily scope, resets pagination and preserves supervisor/seller filters',async t=>{const yesterday={...snapshot(),planningDate:'2026-10-28',planningDay:'yesterday'};const h=harness(t,[snapshot(),snapshot(),snapshot(),yesterday,snapshot()]);h.panel.activate();await tick();h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();h.els.get('next').fire('click');await tick();h.els.get('yesterday').fire('click');await tick();assert.equal(h.calls[3].args.p_day,'yesterday');assert.equal(h.calls[3].args.p_offset,0);assert.equal(h.calls[3].args.p_supervisor,'12');assert.match(h.els.get('day').textContent,/Carteira de ontem/);assert.equal(h.els.get('yesterday').textContent,'Voltar para hoje');h.els.get('yesterday').fire('click');await tick();assert.equal(h.calls[4].args.p_day,'today');assert.match(h.els.get('day').textContent,/Carteira de hoje/);});
test('unrouted mode has its own scope, preserves filters, resets pages and can switch to yesterday',async t=>{const unrouted={...snapshot(),planningDay:'unrouted'},yesterday={...snapshot(),planningDate:'2026-10-28',planningDay:'yesterday'};const h=harness(t,[snapshot(),snapshot(),snapshot(),unrouted,yesterday]);h.panel.activate();await tick();h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();h.els.get('next').fire('click');await tick();h.els.get('unrouted').fire('click');await tick();assert.equal(h.calls[3].args.p_day,'unrouted');assert.equal(h.calls[3].args.p_supervisor,'12');assert.equal(h.calls[3].args.p_offset,0);assert.equal(h.els.get('unrouted')['aria-pressed'],'true');assert.match(h.els.get('day').textContent,/Clientes sem roteirização/);assert.match(h.els.get('kpis').innerHTML,/Clientes sem rota/);h.els.get('yesterday').fire('click');await tick();assert.equal(h.calls[4].args.p_day,'yesterday');assert.equal(h.els.get('unrouted')['aria-pressed'],'false');});
test('unrouted client detail identifies its portfolio without suggesting a scheduled visit',async t=>{const d={...detail(),planningDay:'unrouted',routes:[{day:'SEM ROTA',frequency:'SEM ROTA'}],visitDates:[]};const h=harness(t,[snapshot(),{...snapshot(),planningDay:'unrouted'},d]);h.panel.activate();await tick();h.els.get('unrouted').fire('click');await tick();h.els.get('cards').fire('click',{target:{closest:()=>({dataset:{client:'27'}})}});await tick();assert.match(h.els.get('detail-body').innerHTML,/PLANO DE VISITA · SEM ROTEIRIZAÇÃO/);assert.match(h.els.get('detail-body').innerHTML,/Sem datas reconhecidas/);});


test('visit plan and PDF require four Foods brands and explain both remaining gaps',()=>{
 const d=detail();d.mixIdeal={present:['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA','TODDY','TODDYNHO']};
 d.currentMix=7;d.averageMix=7;d.skus=[{...sku('q'),family:'FOODS',idealCategory:'QUAKER'},{...sku('k'),family:'FOODS',idealCategory:'KEROCOCO'}];d.suggestions=[];
 const html=detailHtml(d);assert.match(html,/FOODS: 2\/4/);assert.match(html,/QUAKER pendente/);assert.match(html,/KEROCOCO pendente/);assert.match(html,/As quatro marcas são obrigatórias/);
 assert.equal(planSections(d).order.ideal.achieved,false);assert.deepEqual(planSections(d).order.rows.map(s=>s.code),['k','q']);
 const texts=[],tables=[];class PDF{constructor(){this.lastAutoTable={finalY:50};}setFillColor(){}rect(){}setTextColor(){}setFontSize(){}splitTextToSize(s){return [s];}text(s){texts.push(s);}addPage(){}autoTable(o){tables.push(o);}getNumberOfPages(){return 1;}setPage(){}save(){}}
 exportPlanPdf(d,PDF);assert.ok(texts.some(s=>s.includes('FOODS 2/4')));assert.ok(texts.some(s=>s.includes('As quatro marcas são obrigatórias')));
 assert.equal(tables[1].body.length,2);assert.ok(tables[1].body.some(r=>r.join(' ').includes('QUAKER')));assert.ok(tables[1].body.some(r=>r.join(' ').includes('KEROCOCO')));
});

test('SMART VOA without current sales keeps historical metrics and produces a bounded visit order',()=>{
 const d=detail();Object.assign(d,{code:'9639',name:'SMART VOA',historyComplete:true,currentValue:0,currentMix:0,currentSalty:0,currentFoods:0,averageValue:19600.226666666666,averageMix:90.33333333333333,averageSalty:80,averageFoods:10.333333333333334,mixIdeal:{present:[]},suggestions:[]});
 const salty=['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA'],foods=['QUAKER','TODDY','TODDYNHO','KEROCOCO'];
 d.skus=Array.from({length:120},(_,i)=>({...sku(String(i),2,false),idealCategory:i<100?salty[i%5]:foods[i%4],family:i<100?'SALTY':'FOODS',averageQuantity:3}));
 const sections=planSections(d);assert.equal(sections.order.blockedReason,null);assert.equal(sections.order.targetMix,91);assert.equal(sections.order.rows.length,91);assert.equal(sections.order.projectedMix,91);assert.equal(sections.order.ideal.achieved,false);
 assert.match(planActions(d).join(' '),/Retomar a compra/);assert.ok(!planActions(d).join(' ').includes('Histórico incompleto'));
 const html=detailHtml(d);assert.match(html,/19\.600,23/);assert.match(html,/90,3/);assert.match(html,/pl-stage-one/);assert.match(html,/pl-stage-two/);
});


test('seven missing categories include five habitual items and two segment tests in stage one and PDF',()=>{
 const d=detail();d.mixIdeal={present:['DORITOS','FANDANGOS']};d.currentMix=4;d.averageMix=42.7;d.averageSalty=null;d.averageFoods=null;
 const known=['CHEETOS','RUFFLES','TORCIDA','QUAKER','TODDY'];
 d.skus=known.map((c,i)=>({...sku('known'+i),idealCategory:c,family:i<3?'SALTY':'FOODS'}));
 d.skus.push(...Array.from({length:40},(_,i)=>({...sku('depth'+i),idealCategory:'OUTROS'})));
 d.suggestions=['TODDYNHO','KEROCOCO'].map(c=>({code:c,name:c,idealCategory:c,family:'FOODS',buyers:4,peers:10,penetration:40}));
 const order=planSections(d).order;assert.equal(order.ideal.missing.length,7);assert.deepEqual(order.uncoveredCategories,[]);
 const actions=planActions(d).join(' ');assert.match(actions,/faltam 7 categorias/);assert.match(actions,/priorizar 7 itens para cobrir 7 das 7 categorias pendentes: 5 já trabalhados pelo cliente e 2 testes/);
 const tables=[],texts=[];class PDF{constructor(){this.lastAutoTable={finalY:50};}setFillColor(){}rect(){}setTextColor(){}setFontSize(){}splitTextToSize(s){return [s];}text(s){texts.push(s);}addPage(){}autoTable(o){tables.push(o);}getNumberOfPages(){return 1;}setPage(){}save(){}}
 exportPlanPdf(d,PDF);assert.equal(tables[1].body.length,7);for(const c of ['TODDYNHO','KEROCOCO'])assert.ok(tables[1].body.some(r=>r[0].includes(c)));
 assert.ok(texts.some(s=>s.includes('priorizar 7 itens')));assert.match(detailHtml(d),/7 itens · Prioridade da visita/);
 d.suggestions=[];assert.match(planActions(d).join(' '),/cobrir 5 das 7 categorias/);assert.match(planActions(d).join(' '),/Sem indicação segura para completar: TODDYNHO, KEROCOCO/);
});


test('tomorrow preserves filters and KPI status, resets pagination and carries its date into detail and PDF',async t=>{
 const next={...snapshot(),planningDate:'2026-10-30',planningDay:'tomorrow'};
 const h=harness(t,[snapshot(),snapshot(),snapshot(),snapshot(),next,{...detail(),planningDate:'2026-10-30'},snapshot()]);
 h.panel.activate();await tick();h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();
 h.els.get('kpis').fire('click',{target:{closest:()=>({dataset:{kpi:'no-sale'}})}});await tick();
 h.els.get('next').fire('click');await tick();h.els.get('tomorrow').fire('click');await tick();
 assert.equal(h.calls[4].args.p_day,'tomorrow');assert.equal(h.calls[4].args.p_offset,0);assert.equal(h.calls[4].args.p_supervisor,'12');assert.equal(h.calls[4].args.p_status,'no-sale');
 assert.match(h.els.get('day').textContent,/Carteira de amanhã/);assert.match(h.els.get('kpis').innerHTML,/Clientes de amanhã/);assert.equal(h.els.get('tomorrow')['aria-pressed'],'true');assert.equal(h.els.get('tomorrow').textContent,'Voltar para hoje');
 h.els.get('cards').fire('click',{target:{closest:()=>({dataset:{client:'27'}})}});await tick();assert.match(h.els.get('detail-body').innerHTML,/PLANO DE VISITA · 30\/10\/2026/);
 h.els.get('tomorrow').fire('click');await tick();assert.equal(h.calls[6].args.p_day,'today');assert.equal(h.els.get('detail').hidden,true);
 h.auth();assert.equal(h.els.get('tomorrow')['aria-pressed'],'false');
});

test('portfolio button exists below day controls and is unavailable for yesterday, unrouted and pending sales',async t=>{
 const h=harness(t,[snapshot(),{...snapshot(),planningDay:'yesterday'},{...snapshot(),planningDay:'unrouted'},{...snapshot(),planningDay:'tomorrow',salesPending:true}]);h.panel.activate();await tick();assert.equal(h.els.get('portfolio-pdf').disabled,false);
 h.els.get('yesterday').fire('click');await tick();assert.equal(h.els.get('portfolio-pdf').hidden,true);
 h.els.get('unrouted').fire('click');await tick();assert.equal(h.els.get('portfolio-pdf').hidden,true);
 h.els.get('tomorrow').fire('click');await tick();assert.equal(h.els.get('portfolio-pdf').hidden,false);assert.equal(h.els.get('portfolio-pdf').disabled,true);
});
test('multiple sellers use union RPC and preserve day, supervisor and KPI scope',async t=>{
 const h=harness(t,Array.from({length:7},snapshot));h.panel.activate();await tick();
 h.els.get('supervisor').value='12';h.els.get('supervisor').fire('change');await tick();
 for(const sellerCode of ['282','321']){h.els.get('seller').fire('change',{target:{dataset:{sellerCode},checked:true}});await tick();}
 assert.equal(h.calls.at(-1).name,'get_planning_portfolio_v1');assert.deepEqual(h.calls.at(-1).args.p_sellers,['282','321']);assert.equal(h.calls.at(-1).args.p_supervisor,'12');
 h.els.get('tomorrow').fire('click');await tick();assert.equal(h.calls.at(-1).args.p_day,'tomorrow');assert.deepEqual(h.calls.at(-1).args.p_sellers,['282','321']);
 h.els.get('clear').fire('click');await tick();assert.equal(h.calls.at(-1).args.p_seller,null);
});


test('portfolio download requests all filtered clients and names the single seller PDF',async t=>{
 const snap=snapshot();const row={...clientRow(),categoryPresence:[]};const payload={...snap,planningDay:'today',rows:[row],total:1,categoryCatalog:[]};
 const h=harness(t,[snap,payload]);const saved=[];class PDF{constructor(){this.lastAutoTable={finalY:50};}setFont(){}setFillColor(){}rect(){}setTextColor(){}setFontSize(){}splitTextToSize(s){return [s];}text(){}addPage(){}autoTable(){}getNumberOfPages(){return 1;}setPage(){}save(n){saved.push(n);}}
 h.win.jspdf={jsPDF:PDF};h.panel.activate();await tick();h.els.get('portfolio-pdf').fire('click');await tick();assert.equal(h.calls[1].name,'get_planning_portfolio_v1');assert.equal(h.calls[1].args.p_export,true);assert.equal(h.calls[1].args.p_offset,undefined);assert.deepEqual(h.calls[1].args.p_sellers,[]);assert.match(saved[0],/282_Matheus_2026-10-29.pdf/);
});
test('changing filters during export cannot download a stale portfolio',async t=>{
 let done;const pending=new Promise(r=>done=r);const h=harness(t,[snapshot(),pending,snapshot()]);let saved=0;h.win.jspdf={jsPDF:class{constructor(){saved++;}}};h.panel.activate();await tick();h.els.get('portfolio-pdf').fire('click');h.els.get('search').value='Outro';h.els.get('search').fire('input');await tick();done({data:{...snapshot(),planningDay:'today',rows:[],total:0,categoryCatalog:[]}});await tick();assert.equal(saved,0);assert.match(h.els.get('error').textContent,/filtros mudaram/);
});
