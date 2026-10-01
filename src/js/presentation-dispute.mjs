import { isVendorRankingEligible } from "./vendor-ranking.mjs?v=20261001-all-rankings";
const collator = new Intl.Collator('pt-BR', { sensitivity: 'base', numeric: true });
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function growth(current, previous) {
  if (previous == null || current == null || !Number.isFinite(Number(previous)) || !Number.isFinite(Number(current)) || Number(previous) <= 0) return null;
  return (Number(current) / Number(previous) - 1) * 100;
}
export function variations(row, vendor = false) {
  return {
    faturamento: growth(vendor ? row.faturamento : row.fat_atual, row.fat_trim),
    tonelada: growth(vendor ? row.tonelada : row.ton_atual, row.ton_trim),
    posituacao: growth(vendor ? row.posituacoes : row.pos_atual, row.pos_trim),
  };
}
export function ranking(rows, metric, team) {
  return rows.filter(row => row.equipe === team && isVendorRankingEligible(row)).map(row => {
    const values = variations(row, true);
    const all = Object.values(values);
    const score = metric === 'geral' ? (all.every(v => v !== null) ? all.reduce((a,b) => a+b,0) / 3 : null) : values[metric];
    return { ...row, values, score };
  }).filter(row => row.score !== null && row.score > 0)
    .sort((a,b) => b.score-a.score || collator.compare(a.vendedor ?? '', b.vendedor ?? '') || collator.compare(a.codusur ?? '', b.codusur ?? ''))
    .slice(0,3);
}
export function categories(rows) {
  return [...new Set(rows.map(r => r.categoria))].sort(collator.compare).map(categoria => ({
    categoria,
    shark: rows.find(r => r.categoria === categoria && r.equipe === 'SHARK'),
    aguia: rows.find(r => r.categoria === categoria && r.equipe === 'ÁGUIA'),
  }));
}
const percent = v => v === null ? '<span class="dispute-neutral" title="Sem base positiva no trimestre anterior">Sem base</span>' : `<span class="${v > 0 ? 'dispute-positive' : v < 0 ? 'dispute-negative' : 'dispute-neutral'}">${v > 0 ? '+' : ''}${v.toLocaleString('pt-BR',{minimumFractionDigits:1,maximumFractionDigits:1})}%</span>`;
const metrics = [['faturamento','Fat.'],['tonelada','Ton.'],['posituacao','Pos.']];
function metricValues(values, metric) {
  return (metric === 'geral' ? metrics : metrics.filter(([key]) => key === metric)).map(([key,label]) => `<span class="dispute-metric"><small>${label}</small>${percent(values[key])}</span>`).join('');
}
export function renderDispute(data, metric, doc = document) {
  const rows = data.categorias_disputa || [];
  for (const [team,id] of [['SHARK','categorias-sellers-shark'],['ÁGUIA','categorias-sellers-aguia']]) {
    const target = doc.getElementById(id);
    if (!target) continue;
    const top = ranking(data.vendedores_categorias || [], metric, team);
    target.innerHTML = top.length ? top.map((v,i) => `<div class="dispute-vendor ${team === 'SHARK' ? 'dispute-shark' : 'dispute-aguia'}">
      <span class="dispute-place">${i+1}</span><strong class="dispute-vendor-name" title="${escape(v.vendedor)}">${escape(v.vendedor || v.codusur)}</strong>
      <div class="dispute-vendor-result">${metric === 'geral' ? `<div class="dispute-average">Média ${percent(v.score)}</div>` : ''}<div class="dispute-values">${metricValues(v.values,metric)}</div></div>
    </div>`).join('') : '<p class="dispute-empty">Nenhum crescimento positivo com base comparável.</p>';
  }
  const target = doc.getElementById('categorias-comparison-rows');
  if (target) target.innerHTML = categories(rows).map(({categoria,shark,aguia}) => {
    const fatShark = Math.max(0,Number(shark?.fat_atual || 0));
    const fatAguia = Math.max(0,Number(aguia?.fat_atual || 0));
    const total = fatShark+fatAguia;
    const s = total ? fatShark/total*100 : 0, a = total ? fatAguia/total*100 : 0;
    const teamCell = row => row ? metricValues(variations(row),metric) : '<span class="dispute-neutral">Sem dados</span>';
    return `<div class="dispute-comparison-row" data-category="${escape(categoria)}">
      <div class="dispute-share-cell"><strong title="${escape(categoria)}">${escape(categoria)}</strong><div class="dispute-share-track"><div class="dispute-share-labels"><span class="dispute-label-shark">${s.toLocaleString('pt-BR',{minimumFractionDigits:1,maximumFractionDigits:1})}%</span><span class="dispute-label-aguia">${a.toLocaleString('pt-BR',{minimumFractionDigits:1,maximumFractionDigits:1})}%</span></div><div class="dispute-share-bar" aria-label="Shark ${s.toFixed(1)}%; Águia ${a.toFixed(1)}%">${total ? `<span style="width:${s}%" class="dispute-share-shark"></span><span style="width:${a}%" class="dispute-share-aguia"></span>` : '<span class="dispute-neutral">Sem faturamento</span>'}</div></div></div>
      <div class="dispute-growth-cell"><strong title="${escape(categoria)}">${escape(categoria)}</strong><div class="dispute-team-values">${teamCell(shark)}</div><div class="dispute-team-values">${teamCell(aguia)}</div></div>
    </div>`;
  }).join('');
  const label = doc.getElementById('growth-metric-label');
  if (label) label.textContent = 'Vs média mensal dos 3 meses anteriores';
}

