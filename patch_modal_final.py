import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

# Make sure we didn't miss replacing the `const fragment = document.createDocumentFragment();` and old `.forEach` blocks
# Let's clean up the modal implementations one by one properly.

# We will just rewrite the openDetalhadoModal function completely to be sure.
pattern = re.compile(r"""window\.openDetalhadoModal = function\(type\) \{.*?    modal\.classList\.remove\('hidden'\);\n\};""", re.DOTALL)

replacement = """window.openDetalhadoModal = function(type) {
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

    const iconVendedor = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>`;
    const iconFilial = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1v1H9V7zm5 0h1v1h-1V7zm-5 4h1v1H9v-1zm5 0h1v1h-1v-1zm-5 4h1v1H9v-1zm5 0h1v1h-1v-1z" /></svg>`;
    const iconChart = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>`;
    const iconTarget = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>`;
    const iconShare = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" /></svg>`;

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
        title.innerHTML = `<span class="flex items-center text-indigo-400">${iconChart} Resultado Detalhado - Sellout</span>`;
        thead.innerHTML = `
            <tr>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconVendedor} Vendedor</th>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconFilial} Filial</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconTarget} Meta Salty</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconChart} Real Salty</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconTarget} Meta Foods</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconChart} Real Foods</th>
            </tr>
        `;

        const sortedData = [...estrelasDetailedData].sort((a, b) => {
            const sumA = (a.sellout_salty || 0) + (a.sellout_foods || 0);
            const sumB = (b.sellout_salty || 0) + (b.sellout_foods || 0);
            return sumB - sumA;
        });

        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        tbody.innerHTML = sortedData.map((row, index) => {
            const realizadoSalty = row.sellout_salty || 0;
            const metaSalty = row.meta_salty || 0;
            const realizadoFoods = row.sellout_foods || 0;
            const metaFoods = row.meta_foods || 0;

            const trClass = `hover:bg-white/5 transition-colors border-b border-white/5 ${index % 2 === 0 ? 'bg-transparent' : 'bg-white/[0.02]'}`;
            return `
            <tr class="${trClass}">
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
        }).join('');

    } else if (type === 'positivacao') {
        title.innerHTML = `<span class="flex items-center text-emerald-400">${iconChart} Resultado Detalhado - Positivação</span>`;
        thead.innerHTML = `
            <tr>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconVendedor} Vendedor</th>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconFilial} Filial</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconChart} Realizado</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconTarget} Meta</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconShare} Share</th>
            </tr>
        `;

        totalRealizado = estrelasDetailedData.reduce((sum, row) => sum + (row.pos_salty || 0) + (row.pos_foods || 0), 0);

        const sortedDataPos = [...estrelasDetailedData].sort((a, b) => {
            const sumA = (a.pos_salty || 0) + (a.pos_foods || 0);
            const sumB = (b.pos_salty || 0) + (b.pos_foods || 0);
            return sumB - sumA;
        });

        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose createDetalhadoRow in loop
        tbody.innerHTML = sortedDataPos.map((row, index) => {
            const realizado = (row.pos_salty || 0) + (row.pos_foods || 0);
            const meta = row.meta_pos || 0;
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;

            const trClass = `border-b border-white/5 hover:bg-white/5 transition-colors ${index % 2 === 0 ? '' : 'bg-white/[0.02]'}`;
            return `
            <tr class="${trClass}">
                <td class="py-3 px-4 whitespace-nowrap text-slate-200">${escapeHtml(row.vendedor_nome || 'N/D')}</td>
                <td class="py-3 px-4 whitespace-nowrap"><span class="px-2 py-1 rounded bg-slate-800 text-slate-300 text-xs border border-slate-700">${escapeHtml(row.filial || 'N/D')}</span></td>
                <td class="py-3 px-4 text-right font-medium text-white">${escapeHtml(realizado)} <span class="text-xs text-slate-400">PDV(s)</span></td>
                <td class="py-3 px-4 text-right text-slate-400">${escapeHtml(meta)} <span class="text-xs">PDV(s)</span></td>
                <td class="py-3 px-4 text-right font-bold text-emerald-400">${escapeHtml(share)}%</td>
            </tr>
            `;
        }).join('');

    } else if (type === 'aceleradores') {
        title.innerHTML = `<span class="flex items-center text-amber-400">${iconTarget} Resultado Detalhado - Aceleradores</span>`;
        subtitle.classList.remove('hidden');
        document.getElementById('modal-detalhado-qtd-marcas').textContent = estrelasQtdMarcas;

        thead.innerHTML = `
            <tr>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconVendedor} Vendedor</th>
                <th class="py-3 px-4 text-left font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconFilial} Filial</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconChart} Realizado</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconTarget} Meta</th>
                <th class="py-3 px-4 text-right font-semibold text-slate-400 uppercase tracking-wider text-xs">${iconShare} Share</th>
            </tr>
        `;

        totalRealizado = estrelasDetailedData.reduce((sum, row) => sum + (row.acel_realizado || 0), 0);

        const sortedDataAcel = [...estrelasDetailedData].sort((a, b) => {
            return (b.acel_realizado || 0) - (a.acel_realizado || 0);
        });

        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose createDetalhadoRow in loop
        tbody.innerHTML = sortedDataAcel.map((row, index) => {
            const realizado = row.acel_realizado || 0;
            const metaPositivação = row.meta_pos || 0;
            const meta = Math.ceil(metaPositivação * 0.5);
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;

            const trClass = `border-b border-white/5 hover:bg-white/5 transition-colors ${index % 2 === 0 ? '' : 'bg-white/[0.02]'}`;
            return `
            <tr class="${trClass}">
                <td class="py-3 px-4 whitespace-nowrap text-slate-200">${escapeHtml(row.vendedor_nome || 'N/D')}</td>
                <td class="py-3 px-4 whitespace-nowrap"><span class="px-2 py-1 rounded bg-slate-800 text-slate-300 text-xs border border-slate-700">${escapeHtml(row.filial || 'N/D')}</span></td>
                <td class="py-3 px-4 text-right font-medium text-white">${escapeHtml(realizado)}</td>
                <td class="py-3 px-4 text-right text-slate-400">${escapeHtml(meta)}</td>
                <td class="py-3 px-4 text-right font-bold text-amber-400">${escapeHtml(share)}%</td>
            </tr>
            `;
        }).join('');
    }

    modal.classList.remove('hidden');
};"""

content = pattern.sub(replacement, content)

with open('src/js/app.js', 'w') as f:
    f.write(content)
