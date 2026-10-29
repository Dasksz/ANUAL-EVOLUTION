const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=v=>v===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);
const num=v=>v===null?'—':new Intl.NumberFormat('pt-BR',{maximumFractionDigits:1}).format(v);
const period=v=>v?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric',timeZone:'UTC'}).format(new Date(v+'-01T12:00:00Z')):'—';
const stamp=v=>v?new Date(v).toLocaleString('pt-BR',{timeZone:'America/Bahia'}):'—';
const date=v=>v?new Date(v+'T12:00:00Z').toLocaleDateString('pt-BR',{timeZone:'UTC'}):'Sem venda';
export function validatePlanning(d,detail=false){
 if(!d||typeof d.version!=='string'||!/^\d{4}-(0[1-9]|1[0-2])$/.test(d.month)||typeof d.historyComplete!=='boolean')throw Error('Dados de planejamento inválidos.');
 const rows=detail?[d]:d.rows;
 if(!Array.isArray(rows)||(!detail&&(!/^\d{4}-\d{2}-\d{2}$/.test(d.planningDate)||!Number.isInteger(d.total)||!Array.isArray(d.supervisors)||!Array.isArray(d.sellers))))throw Error('Carteira inválida.');
 for(const r of rows){
  if(typeof r.code!=='string'||typeof r.name!=='string'||!Array.isArray(r.routes)||!Array.isArray(r.visitDates))throw Error('Cliente inválido.');
  for(const k of ['currentValue','currentMix','currentSalty','currentFoods','missing'])if(!Number.isFinite(r[k]))throw Error('Indicador inválido.');
  for(const k of ['averageValue','averageMix','averageSalty','averageFoods'])if(r[k]!==null&&!Number.isFinite(r[k]))throw Error('Histórico inválido.');
 }
 if(detail){
  if(!Array.isArray(d.skus)||!Array.isArray(d.suggestions))throw Error('Produtos inválidos.');
  for(const s of d.skus)if(typeof s.code!=='string'||typeof s.name!=='string'||!['SALTY','FOODS'].includes(s.family)||typeof s.current!=='boolean'||!Number.isInteger(s.months)||s.months<0||s.months>3)throw Error('Histórico de SKU inválido.');
  for(const s of d.suggestions)if(typeof s.code!=='string'||typeof s.name!=='string'||s.buyers<3||s.peers<5||s.buyers>s.peers)throw Error('Sugestão inválida.');
 }
 return d;
}
export function planSections(d){
 const missing=d.skus.filter(s=>d.salesThrough&&s.months>0&&!s.current).sort((a,b)=>b.months-a.months||(b.averageValue??0)-(a.averageValue??0)||a.code.localeCompare(b.code));
 const maintain=d.skus.filter(s=>s.current).sort((a,b)=>b.currentValue-a.currentValue||a.code.localeCompare(b.code));
 const known=new Set(d.skus.map(s=>s.code));
 const suggestions=d.historyComplete?d.suggestions.filter(s=>!known.has(s.code)):[];
 return {missing,maintain,suggestions};
}
export function planActions(d){
 const {missing,suggestions}=planSections(d),actions=[];
 if(!d.salesThrough)actions.push('Aguardar a carga de vendas do mês antes de confirmar o que falta comprar.');
 else if(!d.currentMix)actions.push('Retomar o atendimento: confirmar estoque, giro e motivo da ausência de compra no mês.');
 if(missing.length)actions.push(`Revisar os ${missing.length} SKUs do histórico ainda sem compra no mês. Priorizar recorrência e giro antes de ampliar o pedido.`);
 if(d.averageSalty>0&&d.currentSalty<d.averageSalty)actions.push(`SALTY: mix atual de ${num(d.currentSalty)} frente à média de ${num(d.averageSalty)} SKUs/mês. Revisar as lacunas da família.`);
 if(d.averageFoods>0&&d.currentFoods<d.averageFoods)actions.push(`FOODS: mix atual de ${num(d.currentFoods)} frente à média de ${num(d.averageFoods)} SKUs/mês. Verificar espaço e demanda.`);
 if(suggestions.length)actions.push(`Testar uma seleção pequena entre as ${suggestions.length} oportunidades do segmento, após validar estoque, perfil e aceitação com o cliente.`);
 if(!d.historyComplete)actions.push('Histórico incompleto: médias e novas sugestões suspensas até a base estar disponível.');
 if(!missing.length&&!suggestions.length&&d.historyComplete)actions.push('Manter o mix com giro comprovado e revisar reposição na próxima visita. Não há novas sugestões com evidência suficiente.');
 return actions;
}
function metrics(d){return [['Média mensal',money(d.averageValue)],['Venda no mês',d.salesThrough?money(d.currentValue):'Sem carga'],['Mix médio',num(d.averageMix)],['Mix atual',d.salesThrough?num(d.currentMix):'Sem carga'],['SALTY · médio / atual',`${num(d.averageSalty)} / ${d.salesThrough?num(d.currentSalty):'Sem carga'}`],['FOODS · médio / atual',`${num(d.averageFoods)} / ${d.salesThrough?num(d.currentFoods):'Sem carga'}`]];}
function skuTable(rows,kind){
 const suggest=kind==='suggestions',current=kind==='maintain';
 return `<div class="pl-table-wrap"><table class="pl-table"><thead><tr><th>SKU / Produto</th><th>Família</th><th>${suggest?'Clientes do segmento':'Meses comprados'}</th><th>${suggest?'Presença no segmento':current?'Venda no mês':'Média mensal'}</th></tr></thead><tbody>${rows.map(s=>`<tr><td><b>${esc(s.code)}</b> · ${esc(s.name)}</td><td>${esc(s.family)}</td><td>${suggest?`${num(s.buyers)} de ${num(s.peers)}`:`${s.months} de 3`}</td><td>${suggest?num(s.penetration)+'%':money(current?s.currentValue:s.averageValue)}</td></tr>`).join('')||'<tr><td colspan="4">Nenhum produto nesta lista.</td></tr>'}</tbody></table></div>`;
}
export function detailHtml(d){
 const s=planSections(d);
 return `<header class="pl-detail-header"><div><span class="pl-eyebrow">PLANO DE VISITA · ${esc(d.planningDate?date(d.planningDate):period(d.month))}</span><h2>${esc(d.name)}</h2><p>${esc(d.code)} · ${esc(d.city)} · ${esc(d.segment)}</p><p>${esc(d.supervisor)} / ${esc(d.seller)}</p></div><button type="button" class="pl-button pl-primary" data-pl="pdf" ${d.salesPending?'disabled':''}>Baixar planejamento em PDF</button></header>
 ${d.salesPending?'<p class="pl-error" role="status">Vendas em atualização. Aguarde o recálculo para baixar este planejamento.</p>':''}<div class="pl-route"><strong>Rota</strong> ${d.routes.map(r=>`${esc(r.day)} · ${esc(r.frequency)}`).join(' / ')||'Não cadastrada'}<br><span>Visitas previstas: ${d.visitDates.map(date).map(esc).join(' · ')||'Sem datas reconhecidas no mês'}</span></div>
 <div class="pl-metrics">${metrics(d).map(([k,v])=>`<div><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('')}</div>
 <section class="pl-block"><h3>Condução da visita</h3><ol class="pl-actions">${planActions(d).map(a=>`<li>${esc(a)}</li>`).join('')}</ol></section>
 <section class="pl-block"><h3><i class="pl-light amber"></i> Recuperar mix <small>${s.missing.length} SKUs</small></h3><p>Comprados no histórico e ainda sem compra positiva neste mês. O valor é referência histórica, não uma meta.</p>${skuTable(s.missing,'missing')}</section>
 <section class="pl-block"><h3><i class="pl-light green"></i> Expandir com evidência <small>${s.suggestions.length} sugestões</small></h3><p>Produtos não comprados neste recorte, vendidos a pelo menos 3 clientes entre 5 ou mais compradores do mesmo segmento, e com venda na base atual. Validar disponibilidade e adequação antes de ofertar.</p>${skuTable(s.suggestions,'suggestions')}</section>
 <section class="pl-block"><h3>Mix já trabalhado no mês <small>${s.maintain.length} SKUs</small></h3>${skuTable(s.maintain,'maintain')}</section>
 <p class="pl-note">${esc(methodology(d))}</p>`;
}
export function methodology(d){return `Histórico: ${period(d.historyStart)} a ${period(d.historyEnd)}. Médias divididas pelos 3 meses, incluindo meses sem compra. Valores líquidos de vendas dos tipos 1 e 9, fornecedores 707, 708, 752 e 1119. Referência por SKU: apenas compras positivas. Mix: SKUs distintos com valor e quantidade positivos, sem bonificação; devoluções não apagam a compra de um SKU. Mês atual até ${d.salesThrough?date(d.salesThrough):'carga ainda indisponível'}; mês parcial não é projeção. Novos SKUs são novos apenas no recorte de 3 meses + mês atual. Farol fornece somente carteira e rotas. Sugestões não garantem venda nem disponibilidade de estoque.`;}
export function exportPlanPdf(d,PDF){
 if(d.salesPending)throw Error('As vendas estão sendo recalculadas. Aguarde a atualização do planejamento antes de baixar o PDF.');
 if(!PDF)throw Error('PDF indisponível. Atualize a página e tente novamente.');
 const pdf=new PDF(),sections=planSections(d);let y=18;
 const header=()=>{pdf.setFillColor(25,24,31);pdf.rect(0,0,210,8,'F');pdf.setTextColor(35,35,40);};header();
 function paragraph(text,size=9){pdf.setFontSize(size);for(const line of pdf.splitTextToSize(String(text),180)){if(y>275){pdf.addPage();header();y=18;}pdf.text(line,15,y);y+=size*.5;}y+=3;}
 paragraph('PLANEJAMENTO COMERCIAL',17);paragraph(`${d.code} · ${d.name}`,13);paragraph(`${d.segment} | ${d.city}`);
 paragraph(`${d.supervisor} / ${d.seller}`);paragraph(`Mês: ${period(d.month)} | Vendas até: ${d.salesThrough?date(d.salesThrough):'sem carga'}`);
 if(d.planningDate)paragraph('Dia do planejamento: '+date(d.planningDate));
 paragraph('Rota: '+d.routes.map(r=>`${r.day} / ${r.frequency}`).join('; '));paragraph('Visitas: '+(d.visitDates.map(date).join(', ')||'Sem datas reconhecidas'));
 pdf.autoTable({startY:y,head:[['Indicador','Valor']],body:metrics(d),styles:{fontSize:9},headStyles:{fillColor:[33,30,39]},margin:{left:15,right:15,top:16,bottom:18}});y=pdf.lastAutoTable.finalY+10;
 paragraph('CONDUÇÃO DA VISITA',12);planActions(d).forEach((a,i)=>paragraph(`${i+1}. ${a}`));
 for(const [key,title] of [['missing','RECUPERAR MIX'],['suggestions','EXPANDIR COM EVIDÊNCIA'],['maintain','MIX JÁ TRABALHADO']]){
  if(y>245){pdf.addPage();header();y=18;}paragraph(`${title} (${sections[key].length} SKUs)`,12);
  const suggestion=key==='suggestions';
  pdf.autoTable({startY:y,head:[['SKU / Produto','Família',suggestion?'Compradores / Base':'Meses / 3',suggestion?'Presença':key==='maintain'?'Venda no mês':'Média mensal']],body:sections[key].length?sections[key].map(s=>[`${s.code} · ${s.name}`,s.family,suggestion?`${s.buyers} / ${s.peers}`:String(s.months),suggestion?num(s.penetration)+'%':money(key==='maintain'?s.currentValue:s.averageValue)]):[['Nenhum produto nesta lista.','','','']],styles:{fontSize:8,cellPadding:2.5,overflow:'linebreak'},headStyles:{fillColor:[33,30,39]},columnStyles:{0:{cellWidth:100}},margin:{left:15,right:15,top:16,bottom:18}});y=pdf.lastAutoTable.finalY+9;
 }
 if(y>235){pdf.addPage();header();y=18;}paragraph('CRITÉRIOS',11);paragraph(methodology(d),8);paragraph(`Carteira do Farol: ${stamp(d.rosterSyncedAt||d.syncedAt)} | Vendas recalculadas: ${stamp(d.salesUpdatedAt||d.syncedAt)}${d.syncError?' · Última tentativa falhou; versão válida preservada.':''}`,8);
 const pages=pdf.getNumberOfPages();for(let i=1;i<=pages;i++){pdf.setPage(i);pdf.setFontSize(8);pdf.text(`Evolução · Planejamento | ${i} / ${pages}`,15,290);}
 pdf.save(`Planejamento_${d.code.replace(/[^a-zA-Z0-9_-]/g,'')}_${d.month}.pdf`);return pdf;
}
export function createPlanningPanel({root,client,document:doc=globalThis.document,window:win=globalThis.window}){
 if(!root)return {activate(){},deactivate(){}};
 let dayMode='today';let active=false,snapshot=null,selected=null,page=0,listController=null,detailController=null,seq=0,detailSeq=0,timer=null,searchTimer=null;
 const f={supervisor:'',seller:'',search:''};
 root.innerHTML=`<style>
 .pl-panel{color:#e2e8f0}.pl-toolbar,.pl-detail-header,.pl-pager{display:flex;justify-content:space-between;align-items:center;gap:14px;flex-wrap:wrap}.pl-toolbar{margin-bottom:20px}.pl-note,.pl-toolbar p,.pl-card p,.pl-detail-header p,.pl-block>p{color:#a5a0af;font-size:12px;line-height:1.7}.pl-button,.pl-input{border:1px solid #ffffff20;background:#201d26;color:#eeeaf2;padding:10px 13px;border-radius:9px;font-size:13px}.pl-button{cursor:pointer}.pl-button:disabled{opacity:.4;cursor:default}.pl-primary{background:#f9731620;border-color:#f9731660;color:#fdba74}.pl-button:focus-visible,.pl-card:focus-visible,.pl-input:focus-visible{outline:2px solid #fb923c;outline-offset:3px}.pl-filters{display:grid;grid-template-columns:1fr 1fr 1.4fr;gap:12px;background:#19171f;padding:16px;border:1px solid #ffffff15;border-radius:12px;margin:18px 0}.pl-filters label{display:grid;gap:7px;font-size:11px;color:#aaa3b4}.pl-input{width:100%;min-width:0}.pl-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:18px 0}.pl-kpi{padding:18px;border:1px solid #ffffff15;border-radius:12px;background:linear-gradient(135deg,#25212c,#19171f)}.pl-kpi span{display:block;color:#aaa3b4;font-size:11px}.pl-kpi strong{display:block;font-size:25px;margin-top:8px;font-variant-numeric:tabular-nums}.pl-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}.pl-card{display:block;text-align:left;width:100%;color:inherit;border:1px solid #ffffff18;background:#1c1922;border-radius:13px;padding:18px;cursor:pointer;min-width:0;transition:border-color .15s}.pl-card:hover{border-color:#fb923c80}.pl-card h3{font-size:14px;line-height:1.5;margin:10px 0 4px;overflow-wrap:anywhere}.pl-card-top{display:flex;justify-content:space-between;align-items:center;gap:8px;font-size:10px;color:#b0a8bd}.pl-badge{border-radius:6px;padding:4px 7px;background:#ffffff0a;color:#c8c0d3}.pl-badge.amber{background:#f59e0b18;color:#fbbf24}.pl-badge.red{background:#ef444418;color:#fca5a5}.pl-card-metrics{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:14px;padding-top:12px;border-top:1px solid #ffffff10;font-size:11px;color:#aaa3b4}.pl-card-metrics b{display:block;color:#e2e8f0;font-size:14px;margin-top:3px}.pl-route{border-left:3px solid #f97316;background:#f9731609;padding:12px 16px;margin:18px 0;font-size:13px;line-height:1.8}.pl-route span{color:#aaa3b4;font-size:11px}.pl-detail-header h2{font-size:24px;font-weight:700;margin:5px 0}.pl-eyebrow{font-size:10px;letter-spacing:.12em;color:#fb923c}.pl-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:18px 0}.pl-metrics>div{border:1px solid #ffffff12;border-radius:10px;padding:14px;background:#19171f}.pl-metrics span{display:block;color:#aaa3b4;font-size:11px}.pl-metrics strong{display:block;font-size:19px;margin-top:6px}.pl-block{margin:24px 0;padding:18px;border:1px solid #ffffff12;background:#19171f;border-radius:12px}.pl-block h3{font-size:16px;font-weight:600;margin-bottom:8px}.pl-block small{color:#aaa3b4;font-size:11px;margin-left:8px}.pl-light{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px}.pl-light.amber{background:#fbbf24}.pl-light.green{background:#34d399}.pl-actions{list-style:decimal;padding-left:22px;font-size:13px;line-height:1.9}.pl-actions li+li{margin-top:6px}.pl-table{width:100%;table-layout:fixed;border-collapse:collapse;font-size:12px}.pl-table th{white-space:normal!important;text-align:left!important;color:#aaa3b4;font-size:10px}.pl-table th,.pl-table td{padding:11px 6px;border-bottom:1px solid #ffffff0d;overflow-wrap:anywhere}.pl-table th:first-child{width:48%}.pl-table-wrap{margin-top:12px}.pl-error{padding:14px;border:1px solid #ef444450;background:#ef444410;color:#fecaca;border-radius:10px;font-size:13px;margin-bottom:15px}.pl-empty{padding:40px;text-align:center;color:#a5a0af}.pl-pager{font-size:12px;color:#aaa3b4;padding:10px 0}.pl-pager>div{display:flex;gap:8px}.pl-back{margin-bottom:18px}
 @media(max-width:1100px){.pl-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.pl-filters{grid-template-columns:1fr 1fr}.pl-kpi strong{font-size:20px}}@media(max-width:650px){.pl-grid{grid-template-columns:1fr}.pl-kpis,.pl-metrics{grid-template-columns:1fr 1fr}.pl-filters{grid-template-columns:1fr}.pl-detail-header h2{font-size:20px}.pl-table{font-size:10px}.pl-table th:first-child{width:43%}.pl-block{padding:12px}.pl-kpi{padding:13px}}
 </style><div class="pl-panel"><div data-pl="error" class="pl-error" role="alert" hidden></div><div data-pl="list">
 <div class="pl-toolbar"><div><span class="pl-eyebrow">FAROL DA CARTEIRA</span><p data-pl="day"></p><p data-pl="updated">Carregando planejamento…</p><p data-pl="sales-status" role="status" aria-live="polite"></p></div><div><button type="button" class="pl-button" data-pl="yesterday">Ver clientes de ontem</button> <button type="button" class="pl-button" data-pl="clear">Limpar filtros</button> <button type="button" class="pl-button pl-primary" data-pl="refresh">Atualizar</button></div></div>
 <div class="pl-filters"><label>SUPERVISOR<select data-pl="supervisor" class="pl-input"><option value="">Todos os supervisores</option></select></label><label>VENDEDOR<select data-pl="seller" class="pl-input"><option value="">Todos os vendedores</option></select></label><label>BUSCAR CLIENTE<input data-pl="search" class="pl-input" placeholder="Código, nome ou cidade" type="search"></label></div>
 <div class="pl-kpis" data-pl="kpis"></div><p class="pl-note" data-pl="period"></p><div class="pl-grid" data-pl="cards" aria-live="polite"></div><div class="pl-pager"><span data-pl="count"></span><div><button type="button" class="pl-button" data-pl="prev">Anterior</button><button type="button" class="pl-button" data-pl="next">Próximo</button></div></div></div>
 <div data-pl="detail" hidden><button type="button" class="pl-button pl-back" data-pl="back">← Voltar à carteira</button><div data-pl="detail-body"></div></div></div>`;
 const $=k=>root.querySelector(`[data-pl="${k}"]`);
 const error=text=>{$('error').hidden=!text;$('error').textContent=text;};
 function options(el,items,first,value){el.innerHTML=`<option value="">${first}</option>`+items.map(i=>`<option value="${esc(i.code)}">${esc(i.code)} · ${esc(i.name)}</option>`).join('');el.value=value;}
 function draw(){
  const d=snapshot;if(!d)return;
  options($('supervisor'),d.supervisors,'Todos os supervisores',f.supervisor);options($('seller'),d.sellers,'Todos os vendedores',f.seller);
  const relativeDay=(d.planningDay||dayMode)==='yesterday'?'ontem':'hoje';
  $('yesterday').textContent=relativeDay==='ontem'?'Voltar para hoje':'Ver clientes de ontem';
  $('yesterday').setAttribute('aria-pressed',String(relativeDay==='ontem'));
  $('day').textContent=`Carteira de ${relativeDay} · ${new Date(d.planningDate+'T12:00:00Z').toLocaleDateString('pt-BR',{weekday:'long',day:'2-digit',month:'2-digit',year:'numeric',timeZone:'UTC'})}`;
  $('updated').textContent=`Carteira do Farol: ${stamp(d.rosterSyncedAt||d.syncedAt)} · Sincronização da carteira a cada hora`;
  $('sales-status').textContent=d.salesPending?'Novas vendas recebidas. Recalculando os clientes; a tela será atualizada automaticamente.':`Vendas recalculadas em ${stamp(d.salesUpdatedAt||d.syncedAt)} · Atualização após cada carga do dashboard`;
  $('period').textContent=`${period(d.month)} · Histórico: ${period(d.historyStart)} a ${period(d.historyEnd)} · Vendas até ${d.salesThrough?date(d.salesThrough):'carga indisponível'}. ${d.historyComplete?'':'Histórico incompleto; médias suspensas.'}`;
  $('kpis').innerHTML=[['Clientes de '+relativeDay,num(d.total)],['Sem compra no mês',d.salesThrough?num(d.kpis.noSale):'Sem carga'],['SKUs a recuperar',d.salesThrough?num(d.kpis.missing):'Sem carga'],['Venda da carteira',d.salesThrough?money(d.kpis.currentValue):'Sem carga']].map(([k,v])=>`<div class="pl-kpi"><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('');
  $('cards').innerHTML=d.rows.map(r=>`<button type="button" class="pl-card" data-client="${esc(r.code)}"><div class="pl-card-top"><span>#${esc(r.code)}</span><span class="pl-badge ${!r.currentMix?'red':r.missing?'amber':''}">${!d.salesThrough?'Aguardando carga':!r.currentMix?'Sem compra no mês':r.missing?`${r.missing} SKUs a recuperar`:'Mix em dia'}</span></div><h3>${esc(r.name)}</h3><p>${esc(r.segment)} · ${esc(r.city)}</p><p>${esc(r.seller)}<br>${r.routes.map(x=>`${esc(x.day)} · ${esc(x.frequency)}`).join(' / ')||'Sem rota cadastrada'}</p><div class="pl-card-metrics"><span>Média mensal<b>${esc(money(r.averageValue))}</b></span><span>Venda no mês<b>${d.salesThrough?esc(money(r.currentValue)):'Sem carga'}</b></span><span>Mix médio → atual<b>${num(r.averageMix)} → ${num(r.currentMix)}</b></span><span>SALTY / FOODS atual<b>${num(r.currentSalty)} / ${num(r.currentFoods)}</b></span></div></button>`).join('')||`<p class="pl-empty">${d.rosterPending?`Carteira de ${relativeDay} aguardando sincronização do Farol.`:`Nenhum cliente previsto para ${relativeDay} com os filtros selecionados.`}</p>`;
  $('count').textContent=d.total?`${page*24+1}–${Math.min(page*24+24,d.total)} de ${d.total} clientes`:'0 clientes';$('prev').disabled=page===0;$('next').disabled=(page+1)*24>=d.total;
 }
 async function load(){
  if(!active)return;listController?.abort();listController=new AbortController();const id=++seq;$('refresh').disabled=true;error('');
  try{const {data,error:e}=await client.rpc('get_planning_day_v1',{p_day:dayMode,p_supervisor:f.supervisor||null,p_seller:f.seller||null,p_search:f.search,p_offset:page*24,p_limit:24}).abortSignal(listController.signal);
   if(!active||id!==seq)return;if(e)throw e;const d=validatePlanning(data);if(snapshot&&snapshot.planningDate!==d.planningDate){back();const reset=page!==0;page=0;snapshot=d;if(reset){await load();return;}}snapshot=d;draw();if(d.syncError)error('A última sincronização falhou. Exibindo a última versão válida.');
   if(selected&&(selected.version!==d.version||!!selected.salesPending!==!!d.salesPending))await open(selected.code);
  }catch(e){if(active&&id===seq&&e.name!=='AbortError')error(e.message||'Não foi possível carregar o planejamento.');}finally{if(id===seq)$('refresh').disabled=false;}
 }
 async function open(code){
  detailController?.abort();detailController=new AbortController();const id=++detailSeq;selected=null;$('list').hidden=true;$('detail').hidden=false;$('detail-body').innerHTML='<p class="pl-empty">Preparando planejamento…</p>';error('');
  try{const {data,error:e}=await client.rpc('get_planning_client_v1',{p_code:code,p_version:snapshot.version}).abortSignal(detailController.signal);if(!active||id!==detailSeq)return;if(e)throw e;selected=validatePlanning({...data,planningDate:snapshot.planningDate},true);$('detail-body').innerHTML=detailHtml(selected);$('pdf').addEventListener('click',()=>{try{exportPlanPdf(selected,win.jspdf?.jsPDF);}catch(e){error(e.message);}});$('back').focus();}
  catch(e){if(active&&id===detailSeq&&e.name!=='AbortError'){error(e.message||'Falha ao abrir o planejamento.');$('detail-body').innerHTML='';}}
 }
 function back(){detailSeq++;detailController?.abort();selected=null;$('detail').hidden=true;$('list').hidden=false;$('detail-body').innerHTML='';error('');}
 for(const k of ['supervisor','seller'])$(k).addEventListener('change',()=>{f[k]=$(k).value;if(k==='supervisor'){f.seller='';$('seller').value='';}page=0;load();});
 $('search').addEventListener('input',()=>{win.clearTimeout(searchTimer);searchTimer=win.setTimeout(()=>{f.search=$('search').value.trim();page=0;load();},250);});
 $('yesterday').addEventListener('click',()=>{dayMode=dayMode==='today'?'yesterday':'today';page=0;back();load();});
 $('clear').addEventListener('click',()=>{win.clearTimeout(searchTimer);Object.keys(f).forEach(k=>f[k]='');$('search').value='';page=0;load();});
 $('prev').addEventListener('click',()=>{if(page>0){page--;load();}});$('next').addEventListener('click',()=>{if(snapshot&&(page+1)*24<snapshot.total){page++;load();}});$('refresh').addEventListener('click',load);$('back').addEventListener('click',back);
 $('cards').addEventListener('click',e=>{const el=e.target.closest('[data-client]');if(el&&snapshot)open(el.dataset.client);});
 function deactivate(){active=false;seq++;detailSeq++;listController?.abort();detailController?.abort();win.clearInterval(timer);win.clearTimeout(searchTimer);timer=null;back();}
 client.auth?.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'){deactivate();snapshot=null;dayMode='today';$('yesterday').textContent='Ver clientes de ontem';$('yesterday').setAttribute('aria-pressed','false');Object.keys(f).forEach(k=>f[k]='');page=0;for(const k of ['cards','kpis','detail-body'])$(k).innerHTML='';$('search').value='';options($('supervisor'),[],'Todos os supervisores','');options($('seller'),[],'Todos os vendedores','');$('day').textContent='';$('period').textContent='';$('updated').textContent='Carregando planejamento…';$('sales-status').textContent='';$('count').textContent='';}});
 return{activate(){if(active)return;active=true;load();timer=win.setInterval(()=>{if(doc.visibilityState==='visible'&&(selected||$('detail').hidden))load();},15000);},deactivate};
}
