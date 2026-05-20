import { escapeHtml, TABLE_ICONS } from './utils.js';

let estrelasDetailedData = [];
let estrelasQtdMarcas = 0;

export function setEstrelasDetailedData(data, qtdMarcas) {
    estrelasDetailedData = data || [];
    estrelasQtdMarcas = qtdMarcas || 0;
}

/**
 * Creates a table row for the detailed modal safely using DOM API
 * to prevent XSS and improve performance.
 * @param {Object} row - The data row object
 * @param {number} index - The index for alternating row colors
 * @param {number|string} realizado - The realized amount
 * @param {string} realizedUnit - The unit string for realized amount
 * @param {number|string} meta - The target amount
 * @param {string} metaUnit - The unit string for target amount
 * @param {number|string} share - The share percentage
 * @param {string} shareColorClass - The color class for the share text
 * @returns {string} The constructed HTML string for the table row
 */
function createDetalhadoRow(row, index, realizado, realizedUnit, meta, metaUnit, share, shareColorClass) {
    const bgClass = index % 2 === 0 ? 'bg-transparent' : 'bg-white/[0.02]';
    const realizedUnitHtml = realizedUnit ? `<span class="text-xs text-slate-400">${escapeHtml(realizedUnit)}</span>` : '';
    const metaUnitHtml = metaUnit ? `<span class="text-xs">${escapeHtml(metaUnit)}</span>` : '';

    // ⚡ Bolt Optimization: Return a formatted HTML string instead of using document.createElement for every cell
    return `
        <tr class="border-b border-white/5 hover:bg-white/5 transition-colors ${bgClass}">
            <td class="py-3 px-4 whitespace-nowrap text-slate-200">${escapeHtml(row.vendedor_nome || 'N/D')}</td>
            <td class="py-3 px-4 whitespace-nowrap">
                <span class="px-2 py-1 rounded bg-slate-800 text-slate-300 text-xs border border-slate-700">${escapeHtml(row.filial || 'N/D')}</span>
            </td>
            <td class="py-3 px-4 text-right font-medium text-white">${escapeHtml(realizado)}${realizedUnit ? ' ' : ''}${realizedUnitHtml}</td>
            <td class="py-3 px-4 text-right text-slate-400">${escapeHtml(meta)}${metaUnit ? ' ' : ''}${metaUnitHtml}</td>
            <td class="py-3 px-4 text-right font-bold ${escapeHtml(shareColorClass)}">${escapeHtml(share)}%</td>
        </tr>
    `;
}

export function openDetalhadoModal(type) {
    const modal = document.getElementById('modal-resultado-detalhado');
    const title = document.getElementById('modal-detalhado-title');
    const subtitle = document.getElementById('modal-detalhado-subtitle');
    const thead = document.getElementById('modal-detalhado-thead');
    const tbody = document.getElementById('modal-detalhado-tbody');

    // Reset contents
    thead.textContent = '';
    tbody.textContent = '';
    subtitle.classList.add('hidden');

    let totalRealizado = 0;

    if (!estrelasDetailedData || estrelasDetailedData.length === 0) {
        title.textContent = type === 'sellout' ? 'Resultado Detalhado - Sellout' : (type === 'positivacao' ? 'Resultado Detalhado - Positivação' : 'Resultado Detalhado - Aceleradores');
        thead.textContent = '';
        tbody.innerHTML = `
            <tr>
                <td class="py-12 px-4 text-center text-slate-400" colspan="100%">
                    <div class="flex flex-col items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mb-3 text-slate-500 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                        </svg>
                        <span class="text-base font-medium text-slate-300">Nenhum dado encontrado</span>
                        <span class="text-sm mt-1">Ajuste os filtros ou aguarde a sincronização.</span>
                    </div>
                </td>
            </tr>`;
        modal.classList.remove('hidden');
        return;
    }

    if (type === 'sellout') {
        title.innerHTML = `<span class="flex items-center text-indigo-400">${TABLE_ICONS.chart} Resultado Detalhado - Sellout</span>`;
        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.target}Meta Salty</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.chart}Realizado Salty</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.target}Meta Foods</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.chart}Realizado Foods</th>
        `;

        const sortedDataSellout = [...estrelasDetailedData].sort((a, b) => {
            const valA = (a.sellout_salty || 0) + (a.sellout_foods || 0);
            const valB = (b.sellout_salty || 0) + (b.sellout_foods || 0);
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataSellout.map((row, index) => {
            const metaSalty = (row.meta_salty || 0).toFixed(2);
            const realizadoSalty = ((row.sellout_salty || 0) / 1000.0).toFixed(2);
            const metaFoods = (row.meta_foods || 0).toFixed(2);
            const realizadoFoods = ((row.sellout_foods || 0) / 1000.0).toFixed(2);

            const bgClass = index % 2 === 0 ? 'bg-transparent' : 'bg-white/[0.02]';
            return `
                <tr class="hover:bg-white/5 transition-colors border-b border-white/5 ${bgClass}">
                    <td class="py-3 px-4 text-slate-300 font-medium">
                        <div class="flex items-center">
                            <span class="w-6 h-6 rounded-full bg-indigo-500/20 text-indigo-400 flex items-center justify-center text-xs mr-3 shrink-0">${index + 1}</span>
                            <span class="truncate max-w-[200px]" title="${escapeHtml(row.vendedor_nome)}">${escapeHtml(row.vendedor_nome)}</span>
                        </div>
                    </td>
                    <td class="py-3 px-4 text-slate-400 font-mono text-sm">${escapeHtml(row.filial)}</td>
                    <td class="py-3 px-4 text-right font-medium text-slate-400">${escapeHtml(metaSalty)} tons</td>
                    <td class="py-3 px-4 text-right font-bold text-white">${escapeHtml(realizadoSalty)} tons</td>
                    <td class="py-3 px-4 text-right font-medium text-slate-400">${escapeHtml(metaFoods)} tons</td>
                    <td class="py-3 px-4 text-right font-bold text-white">${escapeHtml(realizadoFoods)} tons</td>
                </tr>
            `;
        });
        tbody.innerHTML = htmlArray.join('');

    } else if (type === 'positivacao') {
        title.innerHTML = `<span class="flex items-center text-emerald-400">${TABLE_ICONS.chart} Resultado Detalhado - Positivação</span>`;
        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.chart}Realizado</th>
            <th class="py-3 px-4 text-right bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.target}Meta</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.share}% Share</th>
        `;

        totalRealizado = estrelasDetailedData.reduce((acc, curr) => acc + ((curr.pos_salty || 0) + (curr.pos_foods || 0)), 0);

        const sortedDataPos = [...estrelasDetailedData].sort((a, b) => {
            const valA = (a.pos_salty || 0) + (a.pos_foods || 0);
            const valB = (b.pos_salty || 0) + (b.pos_foods || 0);
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataPos.map((row, index) => {
            const realizado = (row.pos_salty || 0) + (row.pos_foods || 0);
            const meta = row.meta_pos || 0;
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;
            return createDetalhadoRow(row, index, realizado, 'PDV(s)', meta, 'PDV(s)', share, 'text-emerald-400');
        });
        tbody.innerHTML = htmlArray.join('');

    } else if (type === 'aceleradores') {
        title.innerHTML = `<span class="flex items-center text-amber-400">${TABLE_ICONS.target} Resultado Detalhado - Aceleradores</span>`;
        subtitle.textContent = `Total de Marcas Cadastradas: ${estrelasQtdMarcas}`;
        subtitle.classList.remove('hidden');

        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-amber-500/10 text-amber-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-amber-500/10 text-amber-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-amber-500/10 text-amber-200">${TABLE_ICONS.chart}Aceleradores (Realizado)</th>
            <th class="py-3 px-4 text-right bg-amber-500/10 text-amber-200">${TABLE_ICONS.target}Meta (50% da Pos.)</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-amber-500/10 text-amber-200">${TABLE_ICONS.share}% Share</th>
        `;

        totalRealizado = estrelasDetailedData.reduce((acc, curr) => acc + (curr.acel_realizado || 0), 0);

        const sortedDataAcel = [...estrelasDetailedData].sort((a, b) => {
            const valA = a.acel_realizado || 0;
            const valB = b.acel_realizado || 0;
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataAcel.map((row, index) => {
            const realizado = row.acel_realizado || 0;
            const metaPositivação = row.meta_pos || 0;
            const meta = Math.ceil(metaPositivação * 0.5);
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;
            return createDetalhadoRow(row, index, realizado, null, meta, null, share, 'text-amber-400');
        });
        tbody.innerHTML = htmlArray.join('');
    }

    modal.classList.remove('hidden');
}

export function closeDetalhadoModal() {
    const modal = document.getElementById('modal-resultado-detalhado');
    modal.classList.add('hidden');
}

window.openDetalhadoModal = openDetalhadoModal;
window.closeDetalhadoModal = closeDetalhadoModal;
