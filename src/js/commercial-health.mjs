const STATUS = ['CRÍTICO', 'ANALISAR', 'SEM ALERTA'];
const PT = new Intl.NumberFormat('pt-BR', {style:'currency',currency:'BRL'});
const INTEGER = new Intl.NumberFormat('pt-BR');
const MIX = new Intl.NumberFormat('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:2});
const mixNumber = value => value==null?'—':MIX.format(value);
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const normal = value => String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
const money = value => PT.format(Number(value)||0);
const percent = value => value == null ? '—' : new Intl.NumberFormat('pt-BR',{style:'percent',minimumFractionDigits:1,maximumFractionDigits:1}).format(value);
const label = period => new Date(`${period}-02T12:00:00Z`).toLocaleDateString('pt-BR',{month:'short',year:'numeric',timeZone:'UTC'}).replace('.','');
const tone = status => status === 'CRÍTICO' ? 'critical' : status === 'ANALISAR' ? 'review' : 'clear';
// Cron runs at 08:30 and 20:30 UTC (05:30 and 17:30 America/Bahia).
export function syncCountdown(now=Date.now()) {
  const cadence=12*60*60*1000,offset=(8*60+30)*60*1000;
  const seconds=Math.ceil(((Math.floor((now-offset)/cadence)+1)*cadence+offset-now)/1000);
  return [Math.floor(seconds/3600),Math.floor(seconds/60)%60,seconds%60].map(n=>String(n).padStart(2,'0')).join(':');
}
export function validateSnapshot(data) {
  if (!data || data.schema_version !== 1 || !Array.isArray(data.rows)) throw Error('Resposta inválida');
  if (data.rows.length && (!Array.isArray(data.periods) || data.periods.length!==6 || data.periods.some(p=>!/^\d{4}-(0[1-9]|1[0-2])$/.test(p)))) throw Error('Períodos inválidos');
  const seen=new Set();
  for (const r of data.rows) {
    if (!/^\d+$/.test(r.code) || seen.has(r.code) || typeof r.name!=='string' || !r.name || ['seller','sellerCode','supervisor','supervisorCode'].some(k=>typeof r[k]!=='string') || !STATUS.includes(r.status) || !Array.isArray(r.history) || r.history.length!==4 || r.history.some(n=>!Number.isFinite(n)) || ['average','median','previous','current','positiveMonths','excess'].some(k=>!Number.isFinite(r[k])) || (r.variation!==null && !Number.isFinite(r.variation))) throw Error('Cliente inválido');
    for(const key of ['mixHistorical','mixPrevious'])if(r[key]!=null&&(!Number.isFinite(r[key])||r[key]<0))throw Error('Mix inválido');
    seen.add(r.code);
  }
  return data;
}
export function filterRows(rows, filters, includeStatus=true) {
  const term=normal(filters.search).trim();
  return rows.filter(r=>(!filters.supervisors.size || filters.supervisors.has(r.supervisorCode)) && (!filters.sellers.size || filters.sellers.has(r.sellerCode)) && (!term || normal([r.code,r.name,r.seller,r.supervisor].join(' ')).includes(term)) && (!includeStatus || filters.status==='all' || (filters.status==='attention' ? r.status!=='SEM ALERTA' : r.status===filters.status)));
}
export function sortRows(rows, sort='priority') {
  return [...rows].sort((a,b)=>{
    let diff=0;
    if (sort==='priority') diff=STATUS.indexOf(a.status)-STATUS.indexOf(b.status) || b.excess-a.excess;
    if (sort==='excess') diff=b.excess-a.excess;
    if (sort==='previous') diff=b.previous-a.previous;
    if (sort==='current') diff=a.current-b.current;
    if (sort==='variation') diff=(b.variation??-Infinity)-(a.variation??-Infinity);
    return diff || a.name.localeCompare(b.name,'pt-BR') || a.code.localeCompare(b.code,undefined,{numeric:true});
  });
}
export function summarize(rows) {
  return rows.reduce((a,r)=>{a[r.status]++;if(r.status!=='SEM ALERTA')a.excess+=r.excess;if(r.status==='CRÍTICO')a.maxCriticalExcess=a.maxCriticalExcess===null?r.excess:Math.max(a.maxCriticalExcess,r.excess);return a;},{'CRÍTICO':0,'ANALISAR':0,'SEM ALERTA':0,excess:0,maxCriticalExcess:null});
}
export function exportRows(rows, periods) {
  const headers=['Código','Cliente','Vendedor','Supervisor',...periods.slice(0,4).map(label),'Média histórica','Mediana histórica','Média mix histórica',label(periods[4]),'Média mix '+label(periods[4]),'Variação',label(periods[5]),'Meses positivos','Excedente','Classificação'];
  return [headers,...rows.map(r=>[r.code,r.name,r.seller,r.supervisor,...r.history,r.average,r.median,r.mixHistorical??null,r.previous,r.mixPrevious??null,r.variation,r.current,r.positiveMonths,r.excess,r.status])];
}
export function csvText(rows,periods) {
  const safe=v=>{if(typeof v==='number')return String(v).replace('.',',');const s=String(v??'');return /^[=+\-@\t\r]/.test(s)?"'"+s:s;};
  return '\uFEFF'+exportRows(rows,periods).map(row=>row.map(v=>'"'+safe(v).replace(/"/g,'""')+'"').join(';')).join('\r\n');
}
export function mixDetailHtml(data,mode='history') {
  if(!data||!Array.isArray(data.periods)||data.periods.length!==5||!Array.isArray(data.monthlyCounts)||data.monthlyCounts.length!==5||!Array.isArray(data.skus)||data.periods.some(p=>!/^\d{4}-(0[1-9]|1[0-2])$/.test(p))||data.monthlyCounts.some(n=>n!==null&&(!Number.isInteger(n)||n<0)))throw Error('Detalhamento de mix inválido');
  for(const r of data.skus)if(typeof r.code!=='string'||typeof r.name!=='string'||!Array.isArray(r.months)||r.months.length!==5||r.months.some(v=>typeof v!=='boolean'))throw Error('SKU inválido');
  const indexes=mode==='previous'?[4]:[0,1,2,3];
  const rows=data.skus.filter(r=>indexes.some(i=>r.months[i])).sort((a,b)=>a.name.localeCompare(b.name,'pt-BR')||a.code.localeCompare(b.code));
  const counts=indexes.map(i=>data.monthlyCounts[i]),missing=counts.some(n=>n===null);
  const average=missing?null:counts.reduce((a,b)=>a+b,0)/indexes.length;
  const formula=missing?'Base de vendas indisponível para parte do período.':mode==='previous'?`${counts[0]} SKUs distintos vendidos no mês.`:`(${counts.join(' + ')}) ÷ ${indexes.length} meses = ${mixNumber(average)} SKUs/mês. Meses sem compra entram com zero.`;
  return `<p class="ch-dialog-explanation"><strong>${mode==='previous'?'Mix de '+escape(label(data.periods[4])):'Média mix histórica'}: ${mixNumber(average)}</strong><br>${escape(formula)}<br>SKUs distintos com venda positiva; bonificações e devoluções não entram. Repetições do mesmo SKU no mês contam uma vez.</p><div class="ch-table-scroll"><table class="ch-table"><thead><tr><th>SKU / Produto</th>${indexes.map(i=>`<th>${escape(label(data.periods[i]))}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr><td style="white-space:normal;min-width:210px;">${escape(r.code)} · ${escape(r.name)}</td>${indexes.map(i=>`<td>${r.months[i]?'✓':'—'}</td>`).join('')}</tr>`).join('')||`<tr><td colspan="${indexes.length+1}" class="ch-empty">${missing?'Sem base disponível para o período.':'Nenhum SKU vendido neste período.'}</td></tr>`}</tbody><tfoot><tr><th>SKUs distintos</th>${counts.map(n=>`<th>${n===null?'—':INTEGER.format(n)}</th>`).join('')}</tr></tfoot></table></div>`;
}
function historySvg(row, periods) {
  const values=[...row.history,row.previous,row.current], max=Math.max(1,row.median,...values),min=Math.min(0,...values),span=max-min||1;
  const y=n=>190-(n-min)/span*150,zero=y(0),median=y(row.median);
  return `<svg viewBox="0 0 660 240" role="img" aria-label="Compras mensais de ${escape(row.name)}"><line x1="25" x2="650" y1="${zero}" y2="${zero}" stroke="#64748b"/><line x1="25" x2="650" y1="${median}" y2="${median}" stroke="#cbd5e1" stroke-dasharray="5 5"/><text x="650" y="${Math.max(13,median-7)}" text-anchor="end" fill="#cbd5e1" font-size="11">Mediana: ${escape(money(row.median))}</text>${values.map((v,i)=>`<g><rect x="${45+i*100}" y="${Math.min(zero,y(v))}" width="52" height="${Math.max(1,Math.abs(y(v)-zero))}" rx="4" fill="${v<0?'#f87171':i===5?'#34d399':i===4?'#fb923c':'#64748b'}"><title>${escape(label(periods[i]))}: ${escape(money(v))}</title></rect><text x="${71+i*100}" y="216" text-anchor="middle" fill="#94a3b8" font-size="11">${escape(label(periods[i]))}</text></g>`).join('')}</svg>`;
}
export function createCommercialHealthPanel({root,client,document:doc=globalThis.document,window:win=globalThis.window}) {
  if(!root)return {activate(){},deactivate(){}};
  const filters={supervisors:new Set(),sellers:new Set(),status:'all',search:''};
  let mixController=null,mixSequence=0;const mixCache=new Map();
  let snapshot=null,active=false,interval=null,countdownInterval=null,controller=null,sequence=0,page=1,pageSize=25,sort='priority',selected=null,searchTimer=null;
  root.innerHTML=`<style>
  .ch-panel{color:#e2e8f0}.ch-toolbar{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;margin-bottom:18px}.ch-muted{color:#94a3b8;font-size:12px}.ch-actions{display:flex;gap:8px;flex-wrap:wrap}.ch-button,.ch-select,.ch-search{background:#19181f;color:#e2e8f0;border:1px solid #ffffff1a;border-radius:8px;padding:9px 12px;font-size:13px}.ch-button{cursor:pointer}.ch-button:hover{border-color:#64748b}.ch-button:disabled{opacity:.4;cursor:default}.ch-button:focus-visible,.ch-select:focus-visible,.ch-search:focus-visible,.ch-card:focus-visible,.ch-link:focus-visible{outline:2px solid #fb923c;outline-offset:3px}.ch-error{padding:12px 16px;background:#7f1d1d30;border:1px solid #f8717150;border-radius:10px;margin-bottom:16px;font-size:13px;color:#fecaca}.ch-period{font-size:13px;color:#cbd5e1;margin-bottom:18px}.ch-filters{background:#151419cc;border:1px solid #ffffff1a;padding:16px;border-radius:12px;display:flex;gap:12px;flex-wrap:wrap;align-items:end;margin-bottom:20px}.ch-field{display:flex;flex-direction:column;gap:6px;font-size:12px;color:#94a3b8}.ch-field.search{flex:1;min-width:210px}.ch-field .ch-search{width:100%}.ch-dropdown{position:relative;min-width:170px}.ch-dropdown summary{list-style:none;cursor:pointer;color:#e2e8f0}.ch-options{position:absolute;z-index:30;top:calc(100% + 7px);left:0;width:340px;max-width:85vw;max-height:320px;overflow:auto;background:#19181f;border:1px solid #ffffff26;box-shadow:0 14px 30px #0008;border-radius:10px;padding:7px}.ch-options label{display:flex;gap:9px;align-items:center;font-size:12px;color:#e2e8f0;padding:10px;cursor:pointer;justify-content:flex-start;text-align:left;line-height:1.4}.ch-options label:hover{background:#ffffff08}.ch-options input[type="checkbox"]{accent-color:#f97316;width:15px;height:15px;flex:0 0 15px;margin:0}.ch-option-name{flex:1;min-width:0;white-space:normal;overflow-wrap:break-word}.ch-cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:22px}.ch-card{border:1px solid #ffffff14;border-radius:12px;background:#151419cc;padding:18px;text-align:left;min-width:0;color:#e2e8f0}.ch-card[data-status]{cursor:pointer}.ch-card[aria-pressed=true]{outline:1px solid currentColor}.ch-card.critical{color:#fca5a5;background:#7f1d1d18;border-color:#ef444430}.ch-card.review{color:#fcd34d;background:#78350f18;border-color:#f59e0b30}.ch-card.clear{color:#6ee7b7;background:#064e3b18;border-color:#10b98130}.ch-card-label{font-size:12px;font-weight:600}.ch-card-value{display:block;font-size:28px;line-height:1.3;font-weight:700;margin-top:9px}.ch-card.excess .ch-card-value{font-size:23px}.ch-card-note{font-size:11px;color:#94a3b8;margin-top:6px}.ch-surface{background:#151419cc;border:1px solid #ffffff14;border-radius:12px;overflow:hidden;margin-bottom:20px}.ch-table-heading{padding:18px;display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap}.ch-table-heading h2{font-size:15px;font-weight:600;color:#fff}.ch-table-scroll{overflow:auto}.ch-table{width:100%;border-collapse:collapse;font-size:12px;white-space:nowrap}.ch-table th{background:#1e1c24;color:#94a3b8;padding:12px;text-align:right;font-weight:600}.ch-table th:first-child,.ch-table td:first-child{text-align:left}.ch-table td{padding:13px 12px;text-align:right;border-top:1px solid #ffffff08}.ch-table tbody tr:nth-child(even){background:#ffffff02}.ch-table tbody tr[data-client]{cursor:pointer}.ch-table tbody tr:hover{background:#ffffff06}.ch-link{color:#f1f5f9;text-align:left;background:none;border:0;cursor:pointer;white-space:normal;min-width:220px;max-width:330px;line-height:1.45}.ch-link small{display:block;color:#64748b;font-size:10px;margin-top:3px}.ch-badge{font-size:10px;font-weight:600;display:inline-block;padding:5px 8px;border-radius:6px}.ch-badge.critical{background:#ef44441a;color:#fca5a5}.ch-badge.review{background:#f59e0b1a;color:#fcd34d}.ch-badge.clear{background:#10b9811a;color:#6ee7b7}.ch-footer{padding:14px 18px;display:flex;gap:14px;justify-content:space-between;align-items:center;flex-wrap:wrap;border-top:1px solid #ffffff0d}.ch-pagination{display:flex;align-items:center;gap:10px}.ch-team summary{cursor:pointer;padding:17px;font-size:14px;font-weight:600}.ch-empty{text-align:center!important;padding:42px!important;color:#94a3b8}.ch-dialog{color:#e2e8f0;background:#151419;border:1px solid #ffffff26;border-radius:16px;width:min(820px,calc(100vw - 24px));max-height:90vh;padding:22px;box-shadow:0 30px 80px #0009}.ch-dialog::backdrop{background:#000a;backdrop-filter:blur(4px)}.ch-dialog-head{display:flex;justify-content:space-between;gap:16px;align-items:start}.ch-dialog h2{font-size:18px;color:#fff;font-weight:700}.ch-dialog-explanation{font-size:13px;color:#cbd5e1;line-height:1.65;margin:18px 0}.ch-dialog svg{width:100%;height:auto}.ch-dialog-meta{display:flex;gap:20px;flex-wrap:wrap;font-size:12px;color:#94a3b8;margin:12px 0}.ch-sr{position:absolute;left:-10000px}.ch-panel [hidden]{display:none!important}@media(max-width:950px){.ch-cards{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:560px){.ch-cards{gap:10px}.ch-card{padding:13px}.ch-card-value{font-size:24px}.ch-card.excess .ch-card-value{font-size:18px}.ch-toolbar{align-items:start}.ch-dropdown{min-width:145px}.ch-filters{padding:12px}.ch-actions .ch-button{padding:8px 10px}}
  </style><div class="ch-panel">
  <div class="ch-toolbar"><div><p data-ch="updated" class="ch-muted" aria-live="polite">Carregando dados…</p><p class="ch-muted">Sincronização automática em <span data-ch="countdown" style="font-variant-numeric:tabular-nums;">—</span></p></div><div class="ch-actions"><button class="ch-button" data-ch="refresh">Atualizar</button><button class="ch-button" data-ch="csv" disabled>Baixar CSV</button><button class="ch-button" data-ch="pdf" disabled>Baixar PDF</button></div></div>
  <p data-ch="error" class="ch-error" role="alert" hidden></p><p data-ch="period" class="ch-period"></p>
  <div class="ch-filters"><label class="ch-field search">Cliente<input class="ch-search" data-ch="search" type="search" placeholder="Buscar por código ou nome" autocomplete="off"></label>
  <div class="ch-field"><span>Supervisor</span><details class="ch-dropdown ch-button" data-ch="supervisor-details"><summary data-ch="supervisor-label">Todos os supervisores ▾</summary><div class="ch-options" data-ch="supervisors"></div></details></div>
  <div class="ch-field"><span>Vendedor</span><details class="ch-dropdown ch-button" data-ch="seller-details"><summary data-ch="seller-label">Todos os vendedores ▾</summary><div class="ch-options" data-ch="sellers"></div></details></div>
  <label class="ch-field">Classificação<select class="ch-select" data-ch="status"><option value="all">Todas</option><option value="attention">Crítico e Analisar</option><option value="CRÍTICO">Crítico</option><option value="ANALISAR">Analisar</option><option value="SEM ALERTA">Sem alerta</option></select></label><button class="ch-button" data-ch="clear">Limpar filtros</button></div>
  <div class="ch-cards">${STATUS.map((status,i)=>`<button class="ch-card ${tone(status)}" data-status="${status}" aria-pressed="false"><span class="ch-card-label">${['Críticos','Para analisar','Sem alerta'][i]}</span><strong class="ch-card-value" data-ch="count-${i}">—</strong><p class="ch-card-note">clientes na carteira filtrada</p></button>`).join('')}<div class="ch-card excess"><span class="ch-card-label">Maior excedente crítico</span><strong class="ch-card-value" data-ch="excess">—</strong><p class="ch-card-note">acima da mediana • somente clientes Críticos</p></div></div>
  <section class="ch-surface"><div class="ch-table-heading"><div><h2>Prioridades por cliente</h2><p data-ch="count" class="ch-muted" aria-live="polite"></p></div><label class="ch-field">Ordenar por<select class="ch-select" data-ch="sort"><option value="priority">Classificação e maior excedente</option><option value="excess">Maior excedente</option><option value="previous">Maior compra no mês anterior</option><option value="current">Menor compra no mês atual</option><option value="variation">Maior variação</option><option value="name">Nome do cliente</option></select></label></div><div class="ch-table-scroll"><table class="ch-table"><thead><tr><th>Cliente</th><th>Vendedor</th><th>Mediana histórica</th><th title="Média mensal de SKUs distintos no histórico, incluindo meses sem compra">Média mix histórica</th><th data-ch="previous-header">Mês anterior</th><th data-ch="mix-previous-header">Média mix mês anterior</th><th>Variação</th><th data-ch="current-header">Mês atual</th><th>Excedente</th><th>Classificação</th></tr></thead><tbody data-ch="rows"><tr><td colspan="10" class="ch-empty">Carregando dados…</td></tr></tbody></table></div><div class="ch-footer"><label class="ch-field">Linhas por página<select class="ch-select" data-ch="page-size"><option>25</option><option>50</option><option>100</option></select></label><div class="ch-pagination"><button class="ch-button" data-ch="prev">Anterior</button><span class="ch-muted" data-ch="page"></span><button class="ch-button" data-ch="next">Próxima</button></div></div></section>
  <details class="ch-surface ch-team"><summary>Resumo por vendedor</summary><div class="ch-table-scroll"><table class="ch-table"><thead><tr><th>Vendedor</th><th>Supervisor</th><th>Críticos</th><th>Analisar</th><th>Sem alerta</th><th>Excedente em atenção</th></tr></thead><tbody data-ch="teams"></tbody></table></div></details>
  <dialog class="ch-dialog" data-ch="dialog" aria-labelledby="ch-detail-title"><div class="ch-dialog-head"><div><h2 id="ch-detail-title" data-ch="detail-title"></h2><p data-ch="detail-subtitle" class="ch-muted"></p></div><button class="ch-button" data-ch="close" aria-label="Fechar histórico">✕</button></div><div data-ch="detail-content"></div></dialog></div>`;
  const $=name=>root.querySelector(`[data-ch="${name}"]`);
  const dialog=$('dialog');
  function visibleRows(){return snapshot?sortRows(filterRows(snapshot.rows,filters),sort):[];}
  function updateFilterOptions(){
    const all=snapshot?.rows||[];
    const focus=doc.activeElement?.dataset?.chCode,kind=doc.activeElement?.dataset?.chKind;
    for(const [name,rows,key,text,chosen] of [['supervisors',all,'supervisorCode','supervisor',filters.supervisors],['sellers',all,'sellerCode','seller',filters.sellers]]){
      const options=[...new Map(rows.map(r=>[r[key],r[text]])).entries()].sort((a,b)=>a[1].localeCompare(b[1],'pt-BR'));
      $(name).innerHTML=options.map(([code,nameText])=>`<label><input type="checkbox" data-ch-kind="${name}" data-ch-code="${escape(code)}" ${chosen.has(code)?'checked':''}><span class="ch-option-name">${escape(nameText)}</span></label>`).join('')||'<p class="ch-muted">Sem opções</p>';
      $(name==='sellers'?'seller-label':'supervisor-label').textContent=chosen.size?`${chosen.size} selecionado${chosen.size>1?'s':''} ▾`:name==='sellers'?'Todos os vendedores ▾':'Todos os supervisores ▾';
    }
    if(focus!==undefined)for(const input of root.querySelectorAll('input[data-ch-code]'))if(input.dataset.chCode===focus&&input.dataset.chKind===kind)input.focus();
  }
  function render(){
    if(!snapshot)return;
    const context=filterRows(snapshot.rows,filters,false),summary=summarize(context),rows=visibleRows();
    STATUS.forEach((status,i)=>{$('count-'+i).textContent=INTEGER.format(summary[status]);root.querySelector(`[data-status="${status}"]`).setAttribute('aria-pressed',String(filters.status===status));});
    $('excess').textContent=summary.maxCriticalExcess===null?'—':money(summary.maxCriticalExcess);$('status').value=filters.status;
    $('count').textContent=`${INTEGER.format(rows.length)} de ${INTEGER.format(snapshot.rows.length)} clientes`;
    const pages=Math.max(1,Math.ceil(rows.length/pageSize));page=Math.min(page,pages);const slice=rows.slice((page-1)*pageSize,page*pageSize);
    $('rows').innerHTML=slice.map(r=>`<tr data-client="${r.code}"><td><button class="ch-link" data-client="${r.code}">${escape(r.name)}<small>Cód. ${r.code}</small></button></td><td>${escape(r.seller)}</td><td>${money(r.median)}</td><td>${mixNumber(r.mixHistorical)}</td><td>${money(r.previous)}</td><td>${mixNumber(r.mixPrevious)}</td><td>${percent(r.variation)}</td><td>${money(r.current)}</td><td>${money(r.excess)}</td><td><span class="ch-badge ${tone(r.status)}">${escape(r.status==='SEM ALERTA'?'Sem alerta':r.status==='ANALISAR'?'Analisar':'Crítico')}</span></td></tr>`).join('')||'<tr><td colspan="10" class="ch-empty">Nenhum cliente encontrado para os filtros selecionados.</td></tr>';
    $('page').textContent=`Página ${page} de ${pages}`;$('prev').disabled=page===1;$('next').disabled=page===pages;
    $('csv').disabled=!rows.length;$('pdf').disabled=!rows.length;
    const groups=new Map();for(const r of rows){const key=r.sellerCode+'|'+r.supervisorCode;if(!groups.has(key))groups.set(key,{seller:r.seller,supervisor:r.supervisor,rows:[]});groups.get(key).rows.push(r);}
    const teams=[...groups.values()].map(g=>({...g,summary:summarize(g.rows)})).sort((a,b)=>b.summary['CRÍTICO']-a.summary['CRÍTICO']||b.summary.excess-a.summary.excess||a.seller.localeCompare(b.seller,'pt-BR'));
    $('teams').innerHTML=teams.map(g=>`<tr><td>${escape(g.seller)}</td><td>${escape(g.supervisor)}</td><td>${g.summary['CRÍTICO']}</td><td>${g.summary.ANALISAR}</td><td>${g.summary['SEM ALERTA']}</td><td>${money(g.summary.excess)}</td></tr>`).join('')||'<tr><td colspan="6" class="ch-empty">Nenhum vendedor para os filtros selecionados.</td></tr>';
    if(snapshot.periods){const p=snapshot.periods;$('previous-header').textContent=label(p[4]);$('mix-previous-header').textContent='Média mix '+label(p[4]);$('current-header').textContent=label(p[5]);$('period').textContent=`Histórico: ${label(p[0])} a ${label(p[3])} · Mês anterior: ${label(p[4])} · Acompanhamento: ${label(p[5])}${snapshot.asOf?' · Vendas na fonte até '+new Date(snapshot.asOf+'T12:00:00Z').toLocaleDateString('pt-BR',{timeZone:'UTC'}):''}`;}
    if(selected&&dialog.open)renderDetail(selected);
  }
  function renderDetail(code){
    const r=snapshot?.rows.find(r=>r.code===code);if(!r){dialog.close();return;}
    mixController?.abort();mixSequence++;selected=code;$('detail-title').textContent=r.name;$('detail-subtitle').textContent=`Cód. ${r.code} · ${r.seller} · ${r.supervisor}`;
    const explanation=r.mixReclassified?`A regra de faturamento apontava Crítico, mas o mix de ${label(snapshot.periods[4])} (${mixNumber(r.mixPrevious)} SKUs) é ${mixNumber(r.mixPrevious/r.mixHistorical)} vezes a média mix histórica (${mixNumber(r.mixHistorical)}). Como atingiu pelo menos 1,9 vez, o cliente foi reclassificado para Analisar por expansão de mix.`:r.status==='CRÍTICO'?`A compra em ${label(snapshot.periods[4])} superou em pelo menos 30% o maior mês do histórico, e não há movimento de pelo menos R$ 0,01 no mês acompanhado.`:r.status==='ANALISAR'?`A compra em ${label(snapshot.periods[4])} superou a mediana histórica em pelo menos 30%, sem movimento de pelo menos R$ 0,01 no mês acompanhado. O valor não atingiu o limite de classificação como crítico.`:`Cliente sem o sinal de alerta definido na planilha para este período.`;
    $('detail-content').innerHTML=`<p class="ch-dialog-explanation"><span class="ch-badge ${tone(r.status)}">${escape(r.status)}</span> ${escape(explanation)}</p><div class="ch-dialog-meta"><span>Mediana: <strong>${money(r.median)}</strong></span><span>Média: <strong>${money(r.average)}</strong></span><span>Meses positivos no histórico: <strong>${r.positiveMonths}/4</strong></span></div>${historySvg(r,snapshot.periods)}<div class="ch-table-scroll"><table class="ch-table"><thead><tr>${snapshot.periods.map(p=>`<th>${escape(label(p))}</th>`).join('')}</tr></thead><tbody><tr>${[...r.history,r.previous,r.current].map(v=>`<td>${money(v)}</td>`).join('')}</tr></tbody></table></div><div class="ch-actions" style="margin-top:18px;"><button class="ch-button" data-ch-mix="history">Ver média mix histórica (${mixNumber(r.mixHistorical)})</button><button class="ch-button" data-ch-mix="previous">Ver mix de ${escape(label(snapshot.periods[4]))} (${mixNumber(r.mixPrevious)})</button></div><div data-ch="mix-content"></div>`;
  }
  async function showMix(mode){
    if(!selected||!snapshot)return;
    const code=selected,version=snapshot.mixVersion,key=code+'|'+version,id=++mixSequence;
    mixController?.abort();mixController=new AbortController();
    $('mix-content').textContent='Carregando SKUs…';
    try{
      let data=mixCache.get(key);
      if(!data){const result=await client.rpc('get_commercial_health_mix_v1',{p_client_code:code,p_version:version||null}).abortSignal(mixController.signal);if(result.error)throw result.error;data=result.data;}
      if(!active||selected!==code||id!==mixSequence)return;
      const html=mixDetailHtml(data,mode);mixCache.set(key,data);$('mix-content').innerHTML=html;
    }catch(error){if(active&&selected===code&&id===mixSequence)$('mix-content').textContent='Não foi possível consultar os SKUs. Clique em Atualizar no painel e tente novamente.';}
  }
  async function refresh(){
    if(!active)return;const id=++sequence;controller?.abort();controller=new AbortController();$('refresh').disabled=true;
    try{
      const {data,error}=await client.rpc('get_commercial_health_v1').abortSignal(controller.signal);
      if(id!==sequence||!active)return;if(error)throw error;
      const next=validateSnapshot(data);if(!next.syncedAt||!next.rows.length)throw Error('Aguardando sincronização');if(snapshot?.mixVersion!==next.mixVersion)mixCache.clear();snapshot=next;
      $('updated').textContent='Última sincronização: '+new Date(next.syncedAt).toLocaleString('pt-BR');
      $('error').hidden=!next.syncError;$('error').textContent=next.syncError?'A última sincronização não foi concluída. Os últimos dados válidos continuam disponíveis.':'';
      updateFilterOptions();render();
    }catch(error){if(id!==sequence||!active)return;$('error').hidden=false;$('error').textContent=snapshot?'Não foi possível atualizar agora. Mantivemos os últimos dados disponíveis.':'Não foi possível carregar Saúde Comercial. Clique em Atualizar para tentar novamente.';if(!snapshot)$('rows').innerHTML='<tr><td colspan="10" class="ch-empty">Dados indisponíveis no momento.</td></tr>';}
    finally{if(id===sequence)$('refresh').disabled=false;}
  }
  function resetFilters(){filters.supervisors.clear();filters.sellers.clear();filters.status='all';filters.search='';$('search').value='';page=1;updateFilterOptions();render();}
  root.addEventListener('change',event=>{const target=event.target;if(target.dataset.chKind){const set=filters[target.dataset.chKind];target.checked?set.add(target.dataset.chCode):set.delete(target.dataset.chCode);page=1;updateFilterOptions();render();}});
  $('search').addEventListener('input',()=>{clearTimeout(searchTimer);searchTimer=setTimeout(()=>{filters.search=$('search').value;page=1;render();},160);});
  $('status').addEventListener('change',()=>{filters.status=$('status').value;page=1;render();});
  $('sort').addEventListener('change',()=>{sort=$('sort').value;page=1;render();});
  $('page-size').addEventListener('change',()=>{pageSize=Number($('page-size').value);page=1;render();});
  $('clear').addEventListener('click',resetFilters);$('refresh').addEventListener('click',refresh);
  $('prev').addEventListener('click',()=>{page=Math.max(1,page-1);render();});$('next').addEventListener('click',()=>{page++;render();});
  for(const button of root.querySelectorAll('[data-status]'))button.addEventListener('click',()=>{filters.status=filters.status===button.dataset.status?'all':button.dataset.status;page=1;render();});
  root.addEventListener('click',event=>{const mix=event.target.closest('[data-ch-mix]');if(mix?.dataset.chMix){void showMix(mix.dataset.chMix);return;}const button=event.target.closest('[data-client]');if(button){renderDetail(button.dataset.client);dialog.showModal();}});
  $('close').addEventListener('click',()=>dialog.close());dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});dialog.addEventListener('close',()=>{selected=null;mixController?.abort();mixSequence++;});
  doc.addEventListener('click',event=>{for(const details of root.querySelectorAll('.ch-dropdown'))if(!details.contains(event.target))details.open=false;});
  $('csv').addEventListener('click',()=>{if(!snapshot)return;const url=win.URL.createObjectURL(new Blob([csvText(visibleRows(),snapshot.periods)],{type:'text/csv;charset=utf-8;'}));const a=doc.createElement('a');a.href=url;a.download=`Saude_Comercial_${snapshot.periods[5]}.csv`;a.click();setTimeout(()=>win.URL.revokeObjectURL(url),1000);});
  $('pdf').addEventListener('click',()=>{
    if(!snapshot)return;const PDF=win.jspdf?.jsPDF;if(!PDF){$('error').hidden=false;$('error').textContent='Exportação PDF indisponível. Atualize a página e tente novamente.';return;}
    const pdf=new PDF({orientation:'landscape'});pdf.setFontSize(15);pdf.text('Saúde Comercial',14,16);pdf.setFontSize(9);pdf.text(`Histórico: ${label(snapshot.periods[0])} a ${label(snapshot.periods[3])} | Anterior: ${label(snapshot.periods[4])} | Atual: ${label(snapshot.periods[5])}`,14,23);
    const rows=visibleRows();pdf.text(`${rows.length} clientes | Classificação: ${filters.status==='all'?'Todas':filters.status==='attention'?'Crítico e Analisar':filters.status}`,14,29);
    pdf.autoTable({startY:34,head:[['Código / Cliente','Vendedor','Mediana','Mix histórico',label(snapshot.periods[4]),'Mix '+label(snapshot.periods[4]),'Variação',label(snapshot.periods[5]),'Excedente','Classificação']],body:rows.map(r=>[r.code+' / '+r.name,r.seller,money(r.median),mixNumber(r.mixHistorical),money(r.previous),mixNumber(r.mixPrevious),percent(r.variation),money(r.current),money(r.excess),r.status]),styles:{fontSize:6.5,cellPadding:2},headStyles:{fillColor:[30,28,36]},columnStyles:{0:{cellWidth:48},1:{cellWidth:34}},didParseCell:cell=>{if(cell.section==='body'&&cell.column.index===9){const status=rows[cell.row.index]?.status;cell.cell.styles.textColor=status==='CRÍTICO'?[180,30,30]:status==='ANALISAR'?[155,95,0]:[15,110,75];}}});pdf.save(`Saude_Comercial_${snapshot.periods[5]}.pdf`);
  });
  client.auth?.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'){deactivate();snapshot=null;filters.supervisors.clear();filters.sellers.clear();filters.search='';filters.status='all';$('rows').innerHTML='';$('teams').innerHTML='';$('search').value='';$('detail-content').innerHTML='';$('supervisors').innerHTML='';$('sellers').innerHTML='';$('updated').textContent='Carregando dados…';$('period').textContent='';STATUS.forEach((_,i)=>$('count-'+i).textContent='—');$('excess').textContent='—';$('csv').disabled=true;$('pdf').disabled=true;if(dialog.open)dialog.close();}});
  function updateCountdown(){if(active)$('countdown').textContent=syncCountdown();}
  function deactivate(){active=false;mixController?.abort();mixSequence++;mixCache.clear();clearInterval(countdownInterval);countdownInterval=null;clearInterval(interval);interval=null;clearTimeout(searchTimer);controller?.abort();sequence++;}
  return {activate(){active=true;updateCountdown();clearInterval(countdownInterval);countdownInterval=setInterval(updateCountdown,1000);void refresh();clearInterval(interval);interval=setInterval(()=>{if(doc.visibilityState!=='hidden')void refresh();},300000);},deactivate};
}
