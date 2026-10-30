import {buildSuggestedOrder,idealState,IDEAL_SALTY,IDEAL_FOODS,orderReason} from './planning-order.mjs?v=20261030-action-order';
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
 const order=buildSuggestedOrder(d);
 return {missing:order.rows.filter(s=>s.kind==='habitual'),suggestions:order.rows.filter(s=>s.kind==='segmento'),maintain:d.skus.filter(s=>s.current).sort((a,b)=>b.currentValue-a.currentValue),order};
}
export function planActions(d){
 const order=buildSuggestedOrder(d),actions=[];
 if(order.blockedReason)return [order.blockedReason];
 if(order.ideal.achieved&&!order.rows.length)return ['Mix ideal alcançado. Manter o giro e revisar o estoque do cliente antes de negociar reposição.'];
 if(order.ideal.achieved)actions.push('Mix ideal alcançado. A sugestão abaixo busca apenas recompor a profundidade histórica do mix.');
 if(!d.currentMix)actions.push('Retomar a compra do mês: confirmar estoque, giro e motivo da ausência de compra.');
 if(order.rows.length)actions.push(`Negociar os ${order.rows.length} itens sugeridos: ${order.rows.filter(s=>s.kind==='habitual').length} já trabalhados pelo cliente e ${order.rows.filter(s=>s.kind==='segmento').length} testes apoiados pelo segmento.`);
 actions.push(`Mix atual: ${num(d.currentMix)} SKUs; média histórica: ${num(d.averageMix)}. O pedido busca cobrir as categorias faltantes e recompor a profundidade habitual, sem repetir SKUs já comprados no mês.`);
 if(order.rows.some(s=>s.kind==='habitual'))actions.push('Entre os produtos conhecidos, começar pelas categorias de menor positivação no Share do vendedor neste mês; recorrência e valor histórico desempataram a seleção.');
 if(order.unfilled)actions.push(`Restam ${order.unfilled} posições de mix sem indicação segura dentro do perfil SALTY/FOODS do cliente.`);
 if(order.uncoveredCategories.length)actions.push(`Sem indicação segura para completar: ${order.uncoveredCategories.join(', ')}. Validar adequação e disponibilidade desses grupos com o cliente.`);
 if(!order.rows.length)actions.push('Não há itens elegíveis com evidência suficiente para sugerir um pedido.');
 return actions;
}
function metrics(d){return [['Média mensal',money(d.averageValue)],['Venda no mês',d.salesThrough?money(d.currentValue):'Sem carga'],['Mix médio',num(d.averageMix)],['Mix atual',d.salesThrough?num(d.currentMix):'Sem carga'],['SALTY · médio / atual',`${num(d.averageSalty)} / ${d.salesThrough?num(d.currentSalty):'Sem carga'}`],['FOODS · médio / atual',`${num(d.averageFoods)} / ${d.salesThrough?num(d.currentFoods):'Sem carga'}`]];}
function skuTable(rows,kind){
 const suggest=kind==='suggestions',current=kind==='maintain';
 return `<div class="pl-table-wrap"><table class="pl-table"><thead><tr><th>SKU / Produto</th><th>Família</th><th>${suggest?'Clientes do segmento':'Meses comprados'}</th><th>${suggest?'Presença no segmento':current?'Venda no mês':'Média mensal'}</th></tr></thead><tbody>${rows.map(s=>`<tr><td><b>${esc(s.code)}</b> · ${esc(s.name)}</td><td>${esc(s.family)}</td><td>${suggest?`${num(s.buyers)} de ${num(s.peers)}`:`${s.months} de 3`}</td><td>${suggest?num(s.penetration)+'%':money(current?s.currentValue:s.averageValue)}</td></tr>`).join('')||'<tr><td colspan="4">Nenhum produto nesta lista.</td></tr>'}</tbody></table></div>`;
}
function idealHtml(d){
 const ideal=idealState(d);
 const chips=items=>items.map(c=>`<span class="pl-badge ${ideal.present.includes(c)?'green':''}">${esc(c)} ${ideal.present.includes(c)?'✓':'pendente'}</span>`).join(' ');
 return `<section class="pl-block"><h3>${ideal.achieved?'Mix ideal alcançado':'Completar mix ideal'}</h3><p>SALTY: ${ideal.saltyCount}/5 categorias · FOODS: ${ideal.foodsCount}/2 categorias. A classificação considera as vendas efetivas do mês.</p><p>${chips(IDEAL_SALTY)}</p><p>${chips(IDEAL_FOODS)}</p></section>`;
}
function suggestedOrderHtml(order){
 return `<div class="pl-table-wrap"><table class="pl-table pl-order-table"><thead><tr><th>SKU / Produto e ação</th><th>Qtd. ref.<br>(un.)</th><th>Share da<br>categoria</th></tr></thead><tbody>${order.rows.map((s,i)=>`<tr><td><strong>${i+1}. ${esc(s.code)} · ${esc(s.name)}</strong><p class="pl-note">${esc(s.family)} · ${esc(s.category||'Categoria não informada')} · ${esc(s.kind==='habitual'?'Já trabalhado':'Teste de segmento')}<br>${esc(orderReason(s))}</p></td><td>${s.quantityReference===null?'Negociar':num(s.quantityReference)}</td><td>${s.sharePositivity===null||s.sharePositivity===undefined?'Sem base':num(s.sharePositivity)+'%'}<br><small>${s.shareBase?`${num(s.shareBuyers)} / ${num(s.shareBase)} PDVs`:''}</small></td></tr>`).join('')||'<tr><td colspan="3">Nenhum item a sugerir neste momento.</td></tr>'}</tbody></table></div>`;
}
export function detailHtml(d){
 const sections=planSections(d),order=sections.order;
 return `<header class="pl-detail-header"><div><span class="pl-eyebrow">PLANO DE VISITA · ${esc(d.planningDay==='unrouted'?'SEM ROTEIRIZAÇÃO':d.planningDate?date(d.planningDate):period(d.month))}</span><h2>${esc(d.name)}</h2><p>${esc(d.code)} · ${esc(d.city)} · ${esc(d.segment)}</p><p>${esc(d.supervisor)} / ${esc(d.seller)}</p></div><button type="button" class="pl-button pl-primary" data-pl="pdf" ${d.salesPending?'disabled':''}>Baixar planejamento em PDF</button></header>
 ${d.salesPending?'<p class="pl-error" role="status">Vendas em atualização. Aguarde o recálculo para baixar este planejamento.</p>':''}<div class="pl-route"><strong>Rota</strong> ${d.routes.map(r=>`${esc(r.day)} · ${esc(r.frequency)}`).join(' / ')||'Não cadastrada'}<br><span>Visitas previstas: ${d.visitDates.map(date).map(esc).join(' · ')||'Sem datas reconhecidas no mês'}</span></div>
 <div class="pl-metrics">${metrics(d).map(([k,v])=>`<div><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('')}</div>${idealHtml(d)}
 <section class="pl-block"><h3>Condução da visita</h3><ol class="pl-actions">${planActions(d).map(a=>`<li>${esc(a)}</li>`).join('')}</ol></section>
 <section class="pl-block"><h3><i class="pl-light amber"></i> Sugestão de pedido <small>${order.rows.length} itens selecionados</small></h3>
 <p>${esc(order.blockedReason||!order.rows.length?'':`Mix após a venda dos itens sugeridos: ${num(order.projectedMix)} SKUs distintos. A média histórica é referência de profundidade; as categorias do ideal também são consideradas.`)}</p>
 ${order.blockedReason?`<p>${esc(order.blockedReason)}</p>`:suggestedOrderHtml(order)}
 <p>Quantidades de referência dos itens conhecidos: média mensal de unidades compradas nos 3 meses históricos, arredondada para cima. Ajustar ao estoque e ao giro no PDV. Para novos SKUs, negociar a quantidade.</p></section>
 <details class="pl-block"><summary>Ver os ${sections.maintain.length} SKUs já comprados no mês</summary>${skuTable(sections.maintain,'maintain')}</details>
 <details class="pl-block"><summary>Critérios do planejamento</summary><p class="pl-note">${esc(methodology(d))}</p></details>`;
}
export function methodology(d){return `Histórico: ${period(d.historyStart)} a ${period(d.historyEnd)}. Médias divididas pelos 3 meses, incluindo meses sem compra. Mix ideal deste painel: CHEETOS, DORITOS, FANDANGOS, RUFFLES e TORCIDA em SALTY; TODDY e TODDYNHO em FOODS. Quaker e Kerococo não são exigidos para classificar o ideal FOODS. O pedido começa com um item por categoria faltante, preferindo produtos conhecidos, e recompõe a média mix arredondada para cima, preservando o perfil SALTY/FOODS do cliente. As metas inteiras por família usam o maior resto; categorias do ideal podem exigir itens adicionais. A classificação usa compras efetivas, nunca o pedido sugerido. Prioridade dos itens conhecidos: menor Share da categoria no vendedor, depois recorrência e valor histórico. Share segue a aba Share: clientes com venda líquida de pelo menos R$1 na categoria / clientes positivados em Salty do vendedor, no mês atual; base inexistente não vira zero. Novos itens exigem venda a pelo menos 3 clientes entre 5 ou mais compradores do mesmo segmento. Mix de SKUs usa compras positivas dos tipos 1 e 9; valores líquidos usam os fornecedores 707, 708, 752 e 1119. Mês até ${d.salesThrough?date(d.salesThrough):'carga indisponível'}. Quantidades são referências históricas, sem garantia de estoque ou preço. Farol fornece carteira e rotas.`;}
export function exportPlanPdf(d,PDF){
 if(d.salesPending)throw Error('As vendas estão sendo recalculadas. Aguarde a atualização do planejamento antes de baixar o PDF.');
 if(!PDF)throw Error('PDF indisponível. Atualize a página e tente novamente.');
 const pdf=new PDF(),sections=planSections(d);let y=18;
 const header=()=>{pdf.setFillColor(25,24,31);pdf.rect(0,0,210,8,'F');pdf.setTextColor(35,35,40);};header();
 function paragraph(text,size=9){pdf.setFontSize(size);for(const line of pdf.splitTextToSize(String(text),180)){if(y>275){pdf.addPage();header();y=18;}pdf.text(line,15,y);y+=size*.5;}y+=3;}
 paragraph('PLANEJAMENTO COMERCIAL',17);paragraph(`${d.code} · ${d.name}`,13);paragraph(`${d.segment} | ${d.city}`);
 paragraph(`${d.supervisor} / ${d.seller}`);paragraph(`Mês: ${period(d.month)} | Vendas até: ${d.salesThrough?date(d.salesThrough):'sem carga'}`);
 if(d.planningDay==='unrouted')paragraph('Carteira sem roteirização');
 if(d.planningDate)paragraph((d.planningDay==='unrouted'?'Data da consulta: ':'Dia do planejamento: ')+date(d.planningDate));
 paragraph('Rota: '+d.routes.map(r=>`${r.day} / ${r.frequency}`).join('; '));paragraph('Visitas: '+(d.visitDates.map(date).join(', ')||'Sem datas reconhecidas'));
 pdf.autoTable({startY:y,head:[['Indicador','Valor']],body:metrics(d),styles:{fontSize:9},headStyles:{fillColor:[33,30,39]},margin:{left:15,right:15,top:16,bottom:18}});y=pdf.lastAutoTable.finalY+10;
 paragraph('CONDUÇÃO DA VISITA',12);planActions(d).forEach((a,i)=>paragraph(`${i+1}. ${a}`));
 const order=sections.order;paragraph(`STATUS: ${order.ideal.achieved?'Mix ideal alcançado':'Mix ideal pendente'} | SALTY ${order.ideal.saltyCount}/5 | FOODS ${order.ideal.foodsCount}/2`,11);
 if(y>235){pdf.addPage();header();y=18;}paragraph(`SUGESTÃO DE PEDIDO (${order.rows.length} itens)`,12);
 pdf.autoTable({startY:y,head:[['SKU / Produto e ação','Qtd. ref. (un.)','Share categoria']],body:order.rows.length?order.rows.map((s,i)=>[`${i+1}. ${s.code} · ${s.name}\n${s.category||s.family} · ${s.kind==='habitual'?`Habitual ${s.months}/3 meses`:'Teste de segmento'} · ${s.purpose==='ideal'?'Completar ideal':'Mix habitual'}`,s.quantityReference===null?'Negociar':num(s.quantityReference),s.sharePositivity===null||s.sharePositivity===undefined?'Sem base':num(s.sharePositivity)+'%']):[[order.blockedReason||(order.ideal.achieved?'Mix ideal alcançado. Manter giro e revisar reposição.':'Sem indicação segura de pedido.'),'','']],styles:{fontSize:8,cellPadding:3,overflow:'linebreak'},headStyles:{fillColor:[33,30,39]},columnStyles:{0:{cellWidth:126}},margin:{left:15,right:15,top:16,bottom:18}});y=pdf.lastAutoTable.finalY+9;
 paragraph('Quantidades de referência: média mensal de unidades dos últimos 3 meses, arredondada para cima. Ajustar ao estoque e giro do cliente. Novos itens: negociar a quantidade.',8);
 if(y>235){pdf.addPage();header();y=18;}paragraph('CRITÉRIOS',11);paragraph(methodology(d),8);paragraph(`Carteira do Farol: ${stamp(d.rosterSyncedAt||d.syncedAt)} | Vendas recalculadas: ${stamp(d.salesUpdatedAt||d.syncedAt)}${d.syncError?' · Última tentativa falhou; versão válida preservada.':''}`,8);
 const pages=pdf.getNumberOfPages();for(let i=1;i<=pages;i++){pdf.setPage(i);pdf.setFontSize(8);pdf.text(`Evolução · Planejamento | ${i} / ${pages}`,15,290);}
 pdf.save(`Planejamento_${d.code.replace(/[^a-zA-Z0-9_-]/g,'')}_${d.month}.pdf`);return pdf;
}
export function createPlanningPanel({root,client,document:doc=globalThis.document,window:win=globalThis.window}){
 if(!root)return {activate(){},deactivate(){}};
 let dayMode='today';let active=false,snapshot=null,selected=null,page=0,listController=null,detailController=null,seq=0,detailSeq=0,timer=null,searchTimer=null;
 const f={supervisor:'',seller:'',search:''};
 root.innerHTML=`<style>
 .pl-panel{color:#e2e8f0}.pl-toolbar,.pl-detail-header,.pl-pager{display:flex;justify-content:space-between;align-items:center;gap:14px;flex-wrap:wrap}.pl-toolbar{margin-bottom:20px}.pl-note,.pl-toolbar p,.pl-card p,.pl-detail-header p,.pl-block>p{color:#a5a0af;font-size:12px;line-height:1.7}.pl-button,.pl-input{border:1px solid #ffffff20;background:#201d26;color:#eeeaf2;padding:10px 13px;border-radius:9px;font-size:13px}.pl-button{cursor:pointer}.pl-button[aria-pressed="true"]{background:#f9731620;border-color:#f9731660;color:#fdba74}.pl-button:disabled{opacity:.4;cursor:default}.pl-primary{background:#f9731620;border-color:#f9731660;color:#fdba74}.pl-button:focus-visible,.pl-card:focus-visible,.pl-input:focus-visible{outline:2px solid #fb923c;outline-offset:3px}.pl-filters{display:grid;grid-template-columns:1fr 1fr 1.4fr;gap:12px;background:#19171f;padding:16px;border:1px solid #ffffff15;border-radius:12px;margin:18px 0}.pl-filters label{display:grid;gap:7px;font-size:11px;color:#aaa3b4}.pl-input{width:100%;min-width:0}.pl-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:18px 0}.pl-kpi{padding:18px;border:1px solid #ffffff15;border-radius:12px;background:linear-gradient(135deg,#25212c,#19171f)}.pl-kpi span{display:block;color:#aaa3b4;font-size:11px}.pl-kpi strong{display:block;font-size:25px;margin-top:8px;font-variant-numeric:tabular-nums}.pl-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0}.pl-card{display:block;text-align:left;width:100%;color:inherit;border:1px solid #ffffff18;background:#1c1922;border-radius:13px;padding:18px;cursor:pointer;min-width:0;transition:border-color .15s}.pl-card:hover{border-color:#fb923c80}.pl-card h3{font-size:14px;line-height:1.5;margin:10px 0 4px;overflow-wrap:anywhere}.pl-card-top{display:flex;justify-content:space-between;align-items:center;gap:8px;font-size:10px;color:#b0a8bd}.pl-badge{border-radius:6px;padding:4px 7px;background:#ffffff0a;color:#c8c0d3}.pl-badge.amber{background:#f59e0b18;color:#fbbf24}.pl-badge.green{background:#10b98118;color:#6ee7b7}.pl-order-table th:first-child{width:70%}.pl-order-table td{vertical-align:top}.pl-order-table .pl-note{margin-top:5px}.pl-block summary{cursor:pointer;font-size:13px;color:#c4bdcf}.pl-badge.red{background:#ef444418;color:#fca5a5}.pl-card-metrics{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:14px;padding-top:12px;border-top:1px solid #ffffff10;font-size:11px;color:#aaa3b4}.pl-card-metrics b{display:block;color:#e2e8f0;font-size:14px;margin-top:3px}.pl-route{border-left:3px solid #f97316;background:#f9731609;padding:12px 16px;margin:18px 0;font-size:13px;line-height:1.8}.pl-route span{color:#aaa3b4;font-size:11px}.pl-detail-header h2{font-size:24px;font-weight:700;margin:5px 0}.pl-eyebrow{font-size:10px;letter-spacing:.12em;color:#fb923c}.pl-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:18px 0}.pl-metrics>div{border:1px solid #ffffff12;border-radius:10px;padding:14px;background:#19171f}.pl-metrics span{display:block;color:#aaa3b4;font-size:11px}.pl-metrics strong{display:block;font-size:19px;margin-top:6px}.pl-block{margin:24px 0;padding:18px;border:1px solid #ffffff12;background:#19171f;border-radius:12px}.pl-block h3{font-size:16px;font-weight:600;margin-bottom:8px}.pl-block small{color:#aaa3b4;font-size:11px;margin-left:8px}.pl-light{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px}.pl-light.amber{background:#fbbf24}.pl-light.green{background:#34d399}.pl-actions{list-style:decimal;padding-left:22px;font-size:13px;line-height:1.9}.pl-actions li+li{margin-top:6px}.pl-table{width:100%;table-layout:fixed;border-collapse:collapse;font-size:12px}.pl-table th{white-space:normal!important;text-align:left!important;color:#aaa3b4;font-size:10px}.pl-table th,.pl-table td{padding:11px 6px;border-bottom:1px solid #ffffff0d;overflow-wrap:anywhere}.pl-table th:first-child{width:48%}.pl-table-wrap{margin-top:12px}.pl-error{padding:14px;border:1px solid #ef444450;background:#ef444410;color:#fecaca;border-radius:10px;font-size:13px;margin-bottom:15px}.pl-empty{padding:40px;text-align:center;color:#a5a0af}.pl-pager{font-size:12px;color:#aaa3b4;padding:10px 0}.pl-pager>div{display:flex;gap:8px}.pl-back{margin-bottom:18px}
 @media(max-width:1100px){.pl-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.pl-filters{grid-template-columns:1fr 1fr}.pl-kpi strong{font-size:20px}}@media(max-width:650px){.pl-grid{grid-template-columns:1fr}.pl-kpis,.pl-metrics{grid-template-columns:1fr 1fr}.pl-filters{grid-template-columns:1fr}.pl-detail-header h2{font-size:20px}.pl-table{font-size:10px}.pl-table th:first-child{width:43%}.pl-block{padding:12px}.pl-kpi{padding:13px}}
 </style><div class="pl-panel"><div data-pl="error" class="pl-error" role="alert" hidden></div><div data-pl="list">
 <div class="pl-toolbar"><div><span class="pl-eyebrow">FAROL DA CARTEIRA</span><p data-pl="day"></p><p data-pl="updated">Carregando planejamento…</p><p data-pl="sales-status" role="status" aria-live="polite"></p></div><div><button type="button" class="pl-button" data-pl="unrouted" aria-pressed="false">Sem roteirização</button> <button type="button" class="pl-button" data-pl="yesterday">Ver clientes de ontem</button> <button type="button" class="pl-button" data-pl="clear">Limpar filtros</button> <button type="button" class="pl-button pl-primary" data-pl="refresh">Atualizar</button></div></div>
 <div class="pl-filters"><label>SUPERVISOR<select data-pl="supervisor" class="pl-input"><option value="">Todos os supervisores</option></select></label><label>VENDEDOR<select data-pl="seller" class="pl-input"><option value="">Todos os vendedores</option></select></label><label>BUSCAR CLIENTE<input data-pl="search" class="pl-input" placeholder="Código, nome ou cidade" type="search"></label></div>
 <div class="pl-kpis" data-pl="kpis"></div><p class="pl-note" data-pl="period"></p><div class="pl-grid" data-pl="cards" aria-live="polite"></div><div class="pl-pager"><span data-pl="count"></span><div><button type="button" class="pl-button" data-pl="prev">Anterior</button><button type="button" class="pl-button" data-pl="next">Próximo</button></div></div></div>
 <div data-pl="detail" hidden><button type="button" class="pl-button pl-back" data-pl="back">← Voltar à carteira</button><div data-pl="detail-body"></div></div></div>`;
 const $=k=>root.querySelector(`[data-pl="${k}"]`);
 const error=text=>{$('error').hidden=!text;$('error').textContent=text;};
 function options(el,items,first,value){el.innerHTML=`<option value="">${first}</option>`+items.map(i=>`<option value="${esc(i.code)}">${esc(i.code)} · ${esc(i.name)}</option>`).join('');el.value=value;}
 function draw(){
  const d=snapshot;if(!d)return;
  options($('supervisor'),d.supervisors,'Todos os supervisores',f.supervisor);options($('seller'),d.sellers,'Todos os vendedores',f.seller);
  const isUnrouted=(d.planningDay||dayMode)==='unrouted';
  const relativeDay=(d.planningDay||dayMode)==='yesterday'?'ontem':'hoje';
  $('unrouted').setAttribute('aria-pressed',String(isUnrouted));
  $('yesterday').textContent=relativeDay==='ontem'?'Voltar para hoje':'Ver clientes de ontem';
  $('yesterday').setAttribute('aria-pressed',String(relativeDay==='ontem'));
  $('day').textContent=isUnrouted?'Clientes sem roteirização':`Carteira de ${relativeDay} · ${new Date(d.planningDate+'T12:00:00Z').toLocaleDateString('pt-BR',{weekday:'long',day:'2-digit',month:'2-digit',year:'numeric',timeZone:'UTC'})}`;
  $('updated').textContent=`Carteira do Farol: ${stamp(d.rosterSyncedAt||d.syncedAt)} · Sincronização da carteira a cada hora`;
  $('sales-status').textContent=d.salesPending?'Novas vendas recebidas. Recalculando os clientes; a tela será atualizada automaticamente.':`Vendas recalculadas em ${stamp(d.salesUpdatedAt||d.syncedAt)} · Atualização após cada carga do dashboard`;
  $('period').textContent=`${period(d.month)} · Histórico: ${period(d.historyStart)} a ${period(d.historyEnd)} · Vendas até ${d.salesThrough?date(d.salesThrough):'carga indisponível'}. ${d.historyComplete?'':'Histórico incompleto; médias suspensas.'}`;
  $('kpis').innerHTML=[[isUnrouted?'Clientes sem rota':'Clientes de '+relativeDay,num(d.total)],['Sem compra no mês',d.salesThrough?num(d.kpis.noSale):'Sem carga'],['Mix ideal alcançado',d.salesThrough?num(d.kpis.mixIdealCount??0):'Sem carga'],['Venda da carteira',d.salesThrough?money(d.kpis.currentValue):'Sem carga']].map(([k,v])=>`<div class="pl-kpi"><span>${esc(k)}</span><strong>${esc(v)}</strong></div>`).join('');
  $('cards').innerHTML=d.rows.map(r=>`<button type="button" class="pl-card" data-client="${esc(r.code)}"><div class="pl-card-top"><span>#${esc(r.code)}</span><span class="pl-badge ${r.mixIdeal?.achieved?'green':!r.currentMix?'red':'amber'}">${!d.salesThrough?'Aguardando carga':r.mixIdeal?.achieved?'Mix ideal alcançado':!r.currentMix?'Sem compra no mês':'Mix ideal pendente'}</span></div><h3>${esc(r.name)}</h3><p>${esc(r.segment)} · ${esc(r.city)}</p><p>${esc(r.seller)}<br>${r.routes.map(x=>`${esc(x.day)} · ${esc(x.frequency)}`).join(' / ')||'Sem rota cadastrada'}</p><div class="pl-card-metrics"><span>Média mensal<b>${esc(money(r.averageValue))}</b></span><span>Venda no mês<b>${d.salesThrough?esc(money(r.currentValue)):'Sem carga'}</b></span><span>Mix médio → atual<b>${num(r.averageMix)} → ${num(r.currentMix)}</b></span><span>SALTY / FOODS atual<b>${num(r.currentSalty)} / ${num(r.currentFoods)}</b></span></div></button>`).join('')||`<p class="pl-empty">${isUnrouted?'Nenhum cliente sem roteirização com os filtros selecionados.':d.rosterPending?`Carteira de ${relativeDay} aguardando sincronização do Farol.`:`Nenhum cliente previsto para ${relativeDay} com os filtros selecionados.`}</p>`;
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
  try{const {data,error:e}=await client.rpc('get_planning_client_v1',{p_code:code,p_version:snapshot.version}).abortSignal(detailController.signal);if(!active||id!==detailSeq)return;if(e)throw e;selected=validatePlanning({...data,planningDate:snapshot.planningDate,planningDay:snapshot.planningDay||dayMode},true);$('detail-body').innerHTML=detailHtml(selected);$('pdf').addEventListener('click',()=>{try{exportPlanPdf(selected,win.jspdf?.jsPDF);}catch(e){error(e.message);}});$('back').focus();}
  catch(e){if(active&&id===detailSeq&&e.name!=='AbortError'){error(e.message||'Falha ao abrir o planejamento.');$('detail-body').innerHTML='';}}
 }
 function back(){detailSeq++;detailController?.abort();selected=null;$('detail').hidden=true;$('list').hidden=false;$('detail-body').innerHTML='';error('');}
 for(const k of ['supervisor','seller'])$(k).addEventListener('change',()=>{f[k]=$(k).value;if(k==='supervisor'){f.seller='';$('seller').value='';}page=0;load();});
 $('search').addEventListener('input',()=>{win.clearTimeout(searchTimer);searchTimer=win.setTimeout(()=>{f.search=$('search').value.trim();page=0;load();},250);});
 $('unrouted').addEventListener('click',()=>{dayMode=dayMode==='unrouted'?'today':'unrouted';page=0;back();load();});
 $('yesterday').addEventListener('click',()=>{dayMode=dayMode==='yesterday'?'today':'yesterday';page=0;back();load();});
 $('clear').addEventListener('click',()=>{win.clearTimeout(searchTimer);Object.keys(f).forEach(k=>f[k]='');$('search').value='';page=0;load();});
 $('prev').addEventListener('click',()=>{if(page>0){page--;load();}});$('next').addEventListener('click',()=>{if(snapshot&&(page+1)*24<snapshot.total){page++;load();}});$('refresh').addEventListener('click',load);$('back').addEventListener('click',back);
 $('cards').addEventListener('click',e=>{const el=e.target.closest('[data-client]');if(el&&snapshot)open(el.dataset.client);});
 function deactivate(){active=false;seq++;detailSeq++;listController?.abort();detailController?.abort();win.clearInterval(timer);win.clearTimeout(searchTimer);timer=null;back();}
 client.auth?.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'){deactivate();snapshot=null;dayMode='today';$('unrouted').setAttribute('aria-pressed','false');$('yesterday').textContent='Ver clientes de ontem';$('yesterday').setAttribute('aria-pressed','false');Object.keys(f).forEach(k=>f[k]='');page=0;for(const k of ['cards','kpis','detail-body'])$(k).innerHTML='';$('search').value='';options($('supervisor'),[],'Todos os supervisores','');options($('seller'),[],'Todos os vendedores','');$('day').textContent='';$('period').textContent='';$('updated').textContent='Carregando planejamento…';$('sales-status').textContent='';$('count').textContent='';}});
 return{activate(){if(active)return;active=true;load();timer=win.setInterval(()=>{if(doc.visibilityState==='visible'&&(selected||$('detail').hidden))load();},15000);},deactivate};
}
