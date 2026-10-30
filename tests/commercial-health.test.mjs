import test from 'node:test';
import assert from 'node:assert/strict';
import {mixDetailHtml,syncCountdown,validateSnapshot,filterRows,sortRows,summarize,csvText,exportRows,createCommercialHealthPanel} from '../src/js/commercial-health.mjs';
const periods=['2026-05','2026-06','2026-07','2026-08','2026-09','2026-10'];
const row=(code,status='SEM ALERTA',seller='10',supervisor='1')=>({code:String(code),name:'Cliente '+code,history:[100,200,100,0],average:100,median:100,previous:250,variation:1.5,current:0,positiveMonths:3,excess:150,status,sellerCode:seller,seller:'Vendedor '+seller,supervisorCode:supervisor,supervisor:'Supervisor '+supervisor});
const filters=()=>({supervisors:new Set(),sellers:new Set(),search:'',status:'all'});
const data=()=>({schema_version:1,rows:[row(1,'CRÍTICO'),row(2,'ANALISAR'),row(3,'SEM ALERTA','20','2')],periods:[...periods],asOf:'2026-10-27',syncedAt:'2026-10-27T20:00:00Z',syncError:false});
test('snapshot validation rejects duplicated IDs, invalid money, statuses and periods',()=>{assert.equal(validateSnapshot(data()).rows.length,3);for(const mutate of [d=>d.rows.push(d.rows[0]),d=>d.rows[0].previous=NaN,d=>d.rows[0].status='SAUDÁVEL',d=>d.periods[0]='2026-13']){const d=data();mutate(d);assert.throws(()=>validateSnapshot(d));}});
test('filters combine multiple supervisors and sellers, status and accent-insensitive search',()=>{const d=data();d.rows[0].name='João Comércio';const f=filters();f.supervisors.add('1');f.sellers.add('10');assert.equal(filterRows(d.rows,f).length,2);f.status='CRÍTICO';f.search='joao comercio';assert.deepEqual(filterRows(d.rows,f).map(r=>r.code),['1']);assert.equal(filterRows(d.rows,f,false).length,1);f.search='';f.status='all';f.supervisors.add('2');f.sellers.add('20');assert.equal(filterRows(d.rows,f).length,3);});
test('priority uses classification then excess and counts excess only in attention',()=>{const d=data();d.rows[1].excess=999;d.rows[2].excess=10000;assert.deepEqual(sortRows(d.rows).map(r=>r.code),['1','2','3']);assert.deepEqual(sortRows(d.rows,'excess').map(r=>r.code),['3','2','1']);assert.equal(summarize(d.rows).excess,1149);assert.equal(summarize(d.rows)['SEM ALERTA'],1);});
test('CSV and export rows retain all filtered rows, numbers, monthly values and order, preventing spreadsheet formulas',()=>{const rows=sortRows(data().rows.filter(r=>r.status!=='SEM ALERTA'));rows[0].name='=SUM(1,1)';const out=exportRows(rows,periods);assert.equal(out.length,3);assert.equal(out[1][6],100);const csv=csvText(rows,periods);assert.match(csv,/"'=SUM\(1,1\)"/);assert.ok(!csv.includes('Cliente 3'));assert.match(csv,/mai\/2026|mai de 2026|mai 2026/);});
class El {
 constructor(value=''){this.value=value;this.dataset={};this.events={};this.innerHTML='';this.textContent='';this.hidden=false;this.disabled=false;this.open=false;}
 addEventListener(type,fn){(this.events[type]??=[]).push(fn);}fire(type,event={}){for(const fn of this.events[type]||[])fn({...event,target:event.target||this});}setAttribute(k,v){this[k]=v;}showModal(){this.open=true;}close(){this.open=false;this.fire('close');}contains(){return false;}focus(){}click(){this.fire('click');}
}
function harness(t,responses=[data()]) {
 const els=new Map(),root=new El(),buttons=['CRÍTICO','ANALISAR','SEM ALERTA'].map(status=>{const e=new El();e.dataset.status=status;return e;});
 root.querySelector=selector=>{if(selector.startsWith('[data-status='))return buttons.find(b=>selector.includes(b.dataset.status));const name=selector.match(/data-ch="([^"]+)/)[1];if(!els.has(name))els.set(name,new El(name==='status'?'all':''));return els.get(name);};
 root.querySelectorAll=selector=>selector==='[data-status]'?buttons:selector==='.ch-dropdown'?[new El(),new El()]:[];
 let userEvent;const client={rpc(){const next=responses.shift();return{abortSignal:()=>next instanceof Promise?next:Promise.resolve(next?.error?next:{data:next})};},auth:{onAuthStateChange(fn){userEvent=fn;}}};
 const doc={activeElement:null,visibilityState:'visible',addEventListener(){},createElement(){return new El();}},win={URL:{createObjectURL:()=> 'blob:test',revokeObjectURL(){}}};
 const panel=createCommercialHealthPanel({root,client,document:doc,window:win});t.after(()=>panel.deactivate());
 return {root,els,panel,buttons,responses,win,logout:()=>userEvent('SIGNED_OUT')};
}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
test('panel renders live totals and rows, card filters, clear and supplier-free controls',async t=>{const h=harness(t);h.panel.activate();await tick();assert.match(h.els.get('count').textContent,/3 de 3/);assert.equal(h.els.get('count-0').textContent,'1');assert.match(h.els.get('rows').innerHTML,/Cliente 1/);h.buttons[0].click();assert.match(h.els.get('count').textContent,/1 de 3/);assert.ok(!h.els.get('rows').innerHTML.includes('Cliente 2'));h.els.get('clear').click();assert.match(h.els.get('count').textContent,/3 de 3/);assert.ok(h.root.innerHTML.includes('Sincronização automática em'));assert.match(h.els.get('countdown').textContent,/^\d{2}:\d{2}:\d{2}$/);assert.ok(!h.root.innerHTML.includes('Fornecedor'));});
test('pagination changes pages without another request; CSV exports include every filtered page',async t=>{const d=data();d.rows=Array.from({length:60},(_,i)=>row(i+1,'CRÍTICO'));const h=harness(t,[d]);h.panel.activate();await tick();assert.match(h.els.get('page').textContent,/1 de 3/);const initial=h.els.get('rows').innerHTML;h.els.get('next').click();assert.match(h.els.get('page').textContent,/2 de 3/);assert.notEqual(h.els.get('rows').innerHTML,initial);assert.equal(exportRows(d.rows,periods).length,61);});
test('refresh preserves user filters and shows last good snapshot if the new read fails',async t=>{const h=harness(t,[data(),{error:Error('offline')}]);h.panel.activate();await tick();h.buttons[1].click();await h.els.get('refresh').fire('click');await tick();assert.equal(h.els.get('status').value,'ANALISAR');assert.match(h.els.get('rows').innerHTML,/Cliente 2/);assert.equal(h.els.get('error').hidden,false);assert.equal(h.els.get('csv').disabled,false);});
test('late response from a deactivated page cannot overwrite a newer response',async t=>{let finish;const old=new Promise(resolve=>finish=resolve),newData=data();newData.rows=[row(9,'CRÍTICO')];const h=harness(t,[old,newData]);h.panel.activate();h.panel.deactivate();h.panel.activate();await tick();finish({data:data()});await tick();assert.match(h.els.get('rows').innerHTML,/Cliente 9/);assert.ok(!h.els.get('rows').innerHTML.includes('Cliente 1'));});
test('detail history escapes names and logout clears loaded customer data',async t=>{const d=data();d.rows[0].name='<img src=x onerror=alert(1)>';const h=harness(t,[d]);h.panel.activate();await tick();assert.ok(!h.els.get('rows').innerHTML.includes('<img src=x'));h.root.fire('click',{target:{closest:()=>({dataset:{client:'1'}})}});assert.equal(h.els.get('dialog').open,true);assert.ok(h.els.get('detail-content').innerHTML.includes('<svg'));assert.ok(h.els.get('detail-content').innerHTML.includes('&lt;img'));h.logout();assert.equal(h.els.get('rows').innerHTML,'');assert.equal(h.els.get('dialog').open,false);});

test('PDF exports every filtered page in visible order and omits other classifications',async t=>{
 const d=data();d.rows=[...Array.from({length:35},(_,i)=>row(i+1,'CRÍTICO')),row(99,'SEM ALERTA')];
 const h=harness(t,[d]);let captured,saved;
 h.win.jspdf={jsPDF:class{setFontSize(){}text(){}autoTable(config){captured=config;}save(name){saved=name;}}};
 h.panel.activate();await tick();h.buttons[0].click();h.els.get('next').click();h.els.get('pdf').click();
 assert.equal(captured.body.length,35);assert.ok(!captured.body.some(r=>r[0].includes('Cliente 99')));assert.match(saved,/2026-10/);assert.equal(captured.body[0][0],'1 / Cliente 1');
});

test('seller and supervisor filters remain independent and combine without clearing selections',async t=>{
 const h=harness(t);h.panel.activate();await tick();
 h.root.fire('change',{target:{dataset:{chKind:'sellers',chCode:'20'},checked:true}});
 h.root.fire('change',{target:{dataset:{chKind:'supervisors',chCode:'1'},checked:true}});
 assert.match(h.els.get('count').textContent,/0 de 3/);
 assert.match(h.els.get('sellers').innerHTML,/data-ch-code="20" checked/);
 assert.match(h.els.get('sellers').innerHTML,/Vendedor 10/);
 assert.match(h.els.get('supervisors').innerHTML,/Supervisor 2/);
 h.root.fire('change',{target:{dataset:{chKind:'supervisors',chCode:'1'},checked:false}});
 assert.match(h.els.get('count').textContent,/1 de 3/);
 assert.match(h.els.get('rows').innerHTML,/Cliente 3/);
 assert.ok(!h.root.innerHTML.includes('<option value="seller">'));
 assert.ok(!h.root.innerHTML.includes('<option value="supervisor">'));
});

test('countdown follows 05:30 and 17:30 Bahia schedule across midnight and browser timezones',()=>{
 assert.equal(syncCountdown(Date.parse('2026-10-28T05:29:59-03:00')),'00:00:01');
 assert.equal(syncCountdown(Date.parse('2026-10-28T05:30:00-03:00')),'12:00:00');
 assert.equal(syncCountdown(Date.parse('2026-10-28T17:00:00-03:00')),'00:30:00');
 assert.equal(syncCountdown(Date.parse('2026-10-28T17:30:00-03:00')),'12:00:00');
 assert.equal(syncCountdown(Date.parse('2026-10-28T23:30:00-03:00')),'06:00:00');
 assert.equal(syncCountdown(Date.parse('2026-10-29T08:29:59Z')),'00:00:01');
});

test('critical excess KPI shows maximum within the filtered portfolio and ignores larger noncritical values',async t=>{
 const d=data();d.rows=[row(1,'CRÍTICO'),row(2,'CRÍTICO','20','2'),row(3,'ANALISAR'),row(4,'SEM ALERTA')];
 d.rows[0].excess=200;d.rows[1].excess=700;d.rows[2].excess=9000;d.rows[3].excess=12000;
 assert.equal(summarize(d.rows).maxCriticalExcess,700);
 assert.equal(summarize([]).maxCriticalExcess,null);
 const h=harness(t,[d]);h.panel.activate();await tick();
 assert.match(h.els.get('excess').textContent,/700,00/);
 h.root.fire('change',{target:{dataset:{chKind:'sellers',chCode:'10'},checked:true}});
 assert.match(h.els.get('excess').textContent,/200,00/);
 h.els.get('search').value='Cliente 3';h.els.get('search').fire('input');
 await new Promise(resolve=>setTimeout(resolve,180));
 assert.equal(h.els.get('excess').textContent,'—');
 assert.ok(h.root.innerHTML.includes('Maior excedente crítico'));
});

const mixFixture=()=>({periods:periods.slice(0,5),monthlyCounts:[2,1,0,0,2],historicalAverage:0.75,previousAverage:2,skus:[{code:'1',name:'<Produto A>',months:[true,true,false,false,true]},{code:'2',name:'Produto B',months:[true,false,false,false,true]}]});
test('mix details explain monthly averaging and list only SKUs in the selected period safely',()=>{
 const d=mixFixture();d.skus.push({code:'3',name:'Só setembro',months:[false,false,false,false,true]});d.monthlyCounts[4]=3;
 const h=mixDetailHtml(d,'history'),p=mixDetailHtml(d,'previous');
 assert.match(h,/0,75/);assert.match(h,/2 \+ 1 \+ 0 \+ 0/);assert.ok(!h.includes('Só setembro'));assert.ok(!h.includes('<Produto A>'));assert.ok(h.includes('&lt;Produto A&gt;'));
 assert.ok(p.includes('Só setembro'));assert.match(p,/3 SKUs distintos/);
 assert.throws(()=>mixDetailHtml({...d,monthlyCounts:[1]}));
});
test('mix columns export their numeric values and detail buttons request matching client/version',async t=>{
 const d=data();d.mixVersion='11111111-1111-1111-1111-111111111111';d.rows[0].mixHistorical=.75;d.rows[0].mixPrevious=2;
 const h=harness(t,[d,mixFixture()]);h.panel.activate();await tick();
 assert.match(h.els.get('rows').innerHTML,/0,75/);assert.ok(h.root.innerHTML.includes('Mix hist.'));
 const out=exportRows([d.rows[0]],periods);assert.equal(out[1][out[0].indexOf('Média mix histórica')],.75);
 h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'1'}}:null}});
 h.root.fire('click',{target:{closest:sel=>sel==='[data-ch-mix]'?{dataset:{chMix:'history'}}:null}});await tick();
 assert.match(h.els.get('mix-content').innerHTML,/0,75/);assert.match(h.els.get('mix-content').innerHTML,/Produto B/);
 h.root.fire('click',{target:{closest:sel=>sel==='[data-ch-mix]'?{dataset:{chMix:'previous'}}:null}});await tick();
 assert.match(h.els.get('mix-content').innerHTML,/2 SKUs distintos/);
});
test('late SKU detail cannot overwrite a different selected client',async t=>{
 let resolve;const pending=new Promise(r=>resolve=r);const h=harness(t,[data(),pending]);h.panel.activate();await tick();
 h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'1'}}:null}});
 h.root.fire('click',{target:{closest:sel=>sel==='[data-ch-mix]'?{dataset:{chMix:'history'}}:null}});
 h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'2'}}:null}});
 resolve({data:mixFixture()});await tick();assert.equal(h.els.get('detail-title').textContent,'Cliente 2');assert.ok(!h.els.get('mix-content').innerHTML.includes('Produto B'));
});

test('mix-reclassified clients affect cards, filtering, critical maximum, details and exports consistently',async t=>{
 const d=data();Object.assign(d.rows[0],{status:'ANALISAR',sourceStatus:'CRÍTICO',mixReclassified:true,mixHistorical:20,mixPrevious:50,excess:9999});d.rows[1].status='CRÍTICO';
 const h=harness(t,[d]);h.panel.activate();await tick();
 assert.equal(h.els.get('count-0').textContent,'1');assert.equal(h.els.get('count-1').textContent,'1');assert.match(h.els.get('excess').textContent,/150,00/);
 h.buttons[0].click();assert.ok(!h.els.get('rows').innerHTML.includes('Cliente 1'));h.els.get('clear').click();
 h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'1'}}:null}});
 assert.match(h.els.get('detail-content').innerHTML,/reclassificado para Analisar por expansão de mix/);
 assert.match(h.els.get('detail-content').innerHTML,/2,50 vezes/);assert.match(h.els.get('detail-content').innerHTML,/pelo menos 1,5 vez/);
 assert.equal(exportRows([d.rows[0]],periods)[1].at(-1),'ANALISAR');
});

test('critical client details also explain the 1.5x mix reclassification requirement',async t=>{
 const h=harness(t);h.panel.activate();await tick();
 h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'1'}}:null}});
 assert.match(h.els.get('detail-content').innerHTML,/precisa atingir pelo menos 1,5 vez a média mix histórica/);
});

test('every classification displays the current 1.5x rule separately from the actual client ratio',async t=>{
 for(const status of ['CRÍTICO','ANALISAR','SEM ALERTA']){
  const d=data();d.rows[0].status=status;const h=harness(t,[d]);h.panel.activate();await tick();
  h.root.fire('click',{target:{closest:sel=>sel==='[data-client]'?{dataset:{client:'1'}}:null}});
  const html=h.els.get('detail-content').innerHTML;
  assert.match(html,/data-health-rule="mix-1.5"/);assert.match(html,/pelo menos 1,5 vez a média mix histórica \(50% maior\)/);
  assert.match(html,/A proporção observada no cliente não altera esse limite/);
 }
});

test('responsive client table preserves all ten labeled fields with widths totaling 100 percent',async t=>{
 const h=harness(t);h.panel.activate();await tick();
 const widths=[...h.root.innerHTML.matchAll(/<col style="width:(\d+)%">/g)].map(m=>Number(m[1]));
 assert.equal(widths.length,10);assert.equal(widths.reduce((a,b)=>a+b,0),100);
 assert.equal((h.els.get('rows').innerHTML.match(/data-label=/g)||[]).length,30);
 for(const label of ['Cliente','Vendedor','Mediana histórica','Média mix histórica','Variação','Excedente','Classificação'])assert.ok(h.els.get('rows').innerHTML.includes('data-label="'+label+'"'));
 assert.ok(h.root.innerHTML.includes('ch-client-table-wrap'));assert.ok(h.root.innerHTML.includes('grid-template-columns:repeat(2,minmax(0,1fr))'));
});

test('client headers use single-line abbreviations with full meaning in tooltips',async t=>{
 const h=harness(t);h.panel.activate();await tick();
 assert.ok(h.root.innerHTML.includes('Mediana hist.'));assert.ok(h.root.innerHTML.includes('Mix hist.'));assert.ok(!h.root.innerHTML.includes('ch-th-line'));
 assert.equal(h.els.get('mix-previous-header').textContent,'Mix set/26');assert.equal(h.els.get('previous-header').textContent,'set/2026');assert.match(h.els.get('mix-previous-header').title,/Média mix/);
});
