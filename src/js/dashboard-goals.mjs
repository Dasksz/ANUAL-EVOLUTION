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
