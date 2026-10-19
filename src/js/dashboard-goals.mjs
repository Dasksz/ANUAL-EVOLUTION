// Null means unavailable, never an implicit zero target.
export function targetSeries(payload, metric, category, {month, divisor = 1, source} = {}) {
    const result = Array(12).fill(null);
    for (const row of payload?.chart_data || []) {
        if (month && Number(month) !== Number(row.mes)) continue;
        if (source && row.origem !== source) continue;
        const metas = (row.metas || []).filter(t => t.metrica === metric && (!category || t.categoria === category));
        if (!metas.length || metas.some(t => t.valor === null || t.valor === undefined || !Number.isFinite(Number(t.valor)))) continue;
        result[Number(row.mes) - 1] = metas.reduce((sum, t) => sum + Number(t.valor), 0) / divisor;
    }
    return result;
}

export function commercialGroups(suppliers = []) {
    return [...new Set(suppliers.map(s => ['1119_QUAKER', '1119_KEROCOCO'].includes(s) ? '1119_QUAKER_KEROCOCO' : s))];
}

export function targetDatasets(payload, metric, options = {}) {
    return [['planilha', 'Meta importada', '#FBBF24'], ['estimativa', 'Meta estimada', '#94A3B8']].map(([source, label, color]) => ({
        label, type: 'line', data: targetSeries(payload, metric, undefined, {...options, source}),
        borderColor: color, backgroundColor: color, borderWidth: 2, borderDash: [6, 4],
        fill: false, tension: 0, pointRadius: 3, order: -1, datalabels: {display: false}
    })).filter(d => d.data.some(v => v !== null));
}

export function applyOfficialTotals(totals, rows, level, code) {
    for (const r of Array.isArray(rows) ? rows : []) {
        if (r.nivel !== level || (code !== undefined && String(r.codigo_entidade) !== String(code)) || r.categoria === 'pedev') continue;
        const col = totals[r.categoria === 'pepsico_all' ? 'geral' : r.categoria];
        const field = {FAT:'metaFat', VOL:'metaVol', POS:'metaPos', MIX:'metaMix'}[r.metrica];
        if (col && field && r.valor !== null && Number.isFinite(Number(r.valor))) col[field] = Number(r.valor);
    }
}

export function attributionNotice(status, month) {
    const pending = (status?.pendencias || []).filter(row => !month || Number(row.mes) === Number(month));
    const portfolios = new Set(pending.map(row => `${row.mes}:${row.source_seller}`));
    return 'Metas dos vendedores atribuídas conforme o cadastro atual de clientes, com os valores históricos preservados.'
        + (portfolios.size ? ` Há ${portfolios.size} carteira(s) com parcelas pendentes de vínculo; elas permanecem identificadas na tabela de metas.` : '');
}

export function validateImport(rows) {
    const issues = [];
    const companies = new Set(rows.filter(row => row.nivel === 'empresa').map(row => row.codigo_entidade));
    if (companies.size !== 1) issues.push('A planilha precisa de uma única linha GV / GERAL PRIME, incluindo a positivação geral da empresa. Esse valor não pode ser obtido somando vendedores ou supervisores.');
    const entities = new Map();
    for (const row of rows) {
        const key = `${row.nivel}:${row.codigo_entidade}`;
        if (!entities.has(key)) entities.set(key, new Set());
        if (row.category !== 'pedev') entities.get(key).add(`${row.category}:${row.type}`);
    }
    for (const [entity, metrics] of entities) {
        if (metrics.size !== 23) issues.push(`${entity}: faltam indicadores obrigatórios. Confira as colunas de ajuste e as metas gerais.`);
    }
    return issues;
}

export function importReconciliation(rows) {
    const warnings = [];
    const labels = {pepsico_all:'Geral',total_elma:'Total Elma',total_foods:'Total Foods',tonelada_elma:'KG Elma',tonelada_foods:'KG Foods'};
    for (const company of rows.filter(row => row.nivel === 'empresa' && ['rev','vol'].includes(row.type) && labels[row.category])) {
        const sellers = rows.filter(row => row.nivel === 'vendedor' && row.category === company.category && row.type === company.type);
        if (!sellers.length) continue;
        const sum = sellers.reduce((total,row) => total + row.val, 0);
        const unit = company.type === 'rev' ? 'R$' : 'kg';
        const fmt = value => value.toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:company.type === 'rev' ? 2 : 3});
        if (Math.abs(company.val - sum) > (company.type === 'rev' ? .02 : .015)) {
            warnings.push(`${labels[company.category]} (${unit}): GV ${fmt(company.val)}; soma dos vendedores ${fmt(sum)}.`);
        }
    }
    return warnings;
}
