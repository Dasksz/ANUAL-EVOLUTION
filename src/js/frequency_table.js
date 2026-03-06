async function loadFrequencyTable(filters) {
    const tableBody = document.getElementById('frequency-table-body');
    const tableFooter = document.getElementById('frequency-table-footer');
    if (!tableBody || !tableFooter) return;

    tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-slate-400 text-xs">Carregando Frequência...</td></tr>';

    try {
        const { data, error } = await supabase.rpc('get_frequency_table_data', filters);

        if (error) throw error;

        renderFrequencyTable(data, tableBody, tableFooter);
        renderFrequencyChart(data);

    } catch (err) {
        console.error("Erro ao carregar tabela de frequência:", err);
        tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-red-500 text-xs">Erro ao carregar dados.</td></tr>';
    }
}

function renderFrequencyTable(data, tableBody, tableFooter) {
    tableBody.innerHTML = '';
    tableFooter.innerHTML = '';

    const treeData = data.tree_data || [];

    if (treeData.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-slate-400 text-xs">Nenhum dado encontrado</td></tr>';
        return;
    }

    // Build hierarchy using explicit ROLLUP grp_ flags from backend
    const hierarchy = {
        name: 'PRIME',
        children: {},
        totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, sum_skus: 0, total_pedidos: 0, base_total: 0, clientsWithSales: 0 }
    };

    treeData.forEach(row => {
        const filial = row.filial || 'SEM FILIAL';
        const cidade = row.cidade || 'SEM CIDADE';
        const vendedor = row.vendedor || 'SEM VENDEDOR';

        const tons = row.tons || 0;
        const faturamento = row.faturamento || 0;
        const faturamento_prev = row.faturamento_prev || 0;
        const positivacao = row.positivacao || 0;
        const sum_skus = row.sum_skus || 0;
        const total_pedidos = row.total_pedidos || 0;
        const base_total = row.base_total || 0;
        const clientsWithSales = (faturamento > 0) ? positivacao : 0;

        const rowData = { tons, faturamento, faturamento_prev, positivacao, sum_skus, total_pedidos, base_total, clientsWithSales };

        // Identify node level by explicit ROLLUP output names
        // Prevent pseudo-totals from rendering as valid string names if grp_ flags are somehow missing
        // Explicitly reject pseudo-totals entering the leaf logic
        const isGrandTotal = (filial === 'TOTAL_GERAL' || filial === 'PRIME' || row.grp_filial == 1);
        const isFilialTotal = (cidade === 'TOTAL_CIDADE' || row.grp_cidade == 1);
        const isCidadeTotal = (vendedor === 'TOTAL_VENDEDOR' || row.grp_vendedor == 1);

        if (isGrandTotal) {
            // Grand Total (PRIME)
            hierarchy.totals = { ...rowData, base_total: data.global_base_total || rowData.base_total || 0 };
            return;
        }

        if (isFilialTotal) {
            // Filial Total
            if (filial === 'TOTAL_GERAL') return; // Paranoia check

            if (!hierarchy.children[filial]) {
                hierarchy.children[filial] = { name: filial, children: {}, totals: rowData };
            } else {
                hierarchy.children[filial].totals = rowData;
            }
            return;
        }

        if (isCidadeTotal) {
            // Cidade Total
            if (filial === 'TOTAL_GERAL') return; // Paranoia check

            if (!hierarchy.children[filial]) {
                hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
            }
            if (!hierarchy.children[filial].children[cidade]) {
                hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: rowData };
            } else {
                hierarchy.children[filial].children[cidade].totals = rowData;
            }
            return;
        }

        // Vendedor (Leaf)
        // Extra sanity check: skip insertion if any grouping name somehow sneaked through
        if (filial === 'TOTAL_GERAL' || filial === 'PRIME' || cidade === 'TOTAL_CIDADE' || vendedor === 'TOTAL_VENDEDOR' || row.grp_filial == 1 || row.grp_cidade == 1 || row.grp_vendedor == 1) {
            return;
        }

        if (!hierarchy.children[filial]) {
            hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
        }
        if (!hierarchy.children[filial].children[cidade]) {
            hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: {} };
        }
        hierarchy.children[filial].children[cidade].children[vendedor] = {
            name: vendedor,
            ...rowData
        };
    });

    let rowCounter = 0;

    const createRow = (node, level, parentId = null) => {
        rowCounter++;
        const id = `node-${rowCounter}`;
        const hasChildren = node.children && Object.keys(node.children).length > 0;

        const isRoot = level === 0;
        const indentClass = level === 0 ? '' : (level === 1 ? 'pl-6' : (level === 2 ? 'pl-10' : 'pl-14'));

        const dataNode = isRoot ? node.totals : (hasChildren ? node.totals : node);

        const tons = (dataNode.tons || 0) / 1000;

        let varYago = 0;
        if (dataNode.faturamento_prev > 0) {
            varYago = ((dataNode.faturamento / dataNode.faturamento_prev) - 1) * 100;
        }

        const varYagoStr = (varYago > 0 ? '+' : '') + varYago.toFixed(1) + '%';
        const varYagoColor = varYago > 0 ? 'text-green-500' : (varYago < 0 ? 'text-red-500' : 'text-slate-400');
        const varYagoIcon = varYago > 0 ? '<svg class="w-4 h-4 text-green-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.707l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd"></path></svg>' : (varYago < 0 ? '<svg class="w-4 h-4 text-red-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.707 10.293a1 1 0 00-1.414 0l-3-3a1 1 0 101.414-1.414L9 14.586V11a1 1 0 10-2 0v3.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3z" clip-rule="evenodd"></path></svg>' : '');

        // SKU / PDV
        const skuPdv = dataNode.positivacao > 0 ? ((dataNode.sum_skus || 0) / dataNode.positivacao) : 0;

        // Frequencia
        const freq = dataNode.positivacao > 0 ? ((dataNode.total_pedidos || 0) / dataNode.positivacao) : 0;

        // % Posit
        let percPosit = 0;
        if (dataNode.base_total > 0) {
            percPosit = ((dataNode.positivacao || 0) / dataNode.base_total) * 100;
        }
        if (percPosit > 100) percPosit = 100;

        const positStr = dataNode.positivacao || 0;
        const percPositStr = percPosit.toFixed(1) + '%';
        
        const rowHtml = `
            <tr class="hover:bg-white/5 transition-colors ${level > 0 ? 'hidden freq-child-row' : ''}" id="${id}" data-parent="${parentId}" data-level="${level}">
                <td class="px-2 py-2 border-b border-white/5 w-8 text-center cursor-pointer" onclick="toggleFreqNode('${id}')">
                    ${hasChildren ? '<svg id="icon-' + id + '" class="w-4 h-4 text-slate-400 inline transform transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>' : ''}
                </td>
                <td class="px-2 py-2 border-b border-white/5 font-medium ${indentClass}">${node.name}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${tons.toFixed(1)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold ${varYagoColor}">${varYagoIcon} ${varYagoStr}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${skuPdv.toFixed(1)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${freq.toFixed(1)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${positStr}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${percPositStr}</td>
            </tr>
        `;
        tableBody.insertAdjacentHTML('beforeend', rowHtml);

        if (hasChildren) {
            Object.values(node.children).forEach(child => createRow(child, level + 1, id));
        }

        return { tons, varYagoStr, varYagoColor, varYagoIcon, skuPdv, freq, positivacao: dataNode.positivacao || 0, percPosit };
    };

    const rootData = createRow(hierarchy, 0);

    // Render footer (Totals - same as Root)
    tableFooter.innerHTML = `
        <tr>
            <td class="px-2 py-3 border-t border-white/20 w-8"></td>
            <td class="px-2 py-3 border-t border-white/20">Total</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.tons.toFixed(1)}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right ${rootData.varYagoColor}">${rootData.varYagoIcon} ${rootData.varYagoStr}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.skuPdv.toFixed(1)}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.freq.toFixed(1)}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.positivacao}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.percPosit.toFixed(1)}%</td>
        </tr>
    `;
}

// Attach toggle function to window so onclick works
window.toggleFreqNode = function(id) {
    const icon = document.getElementById(`icon-${id}`);
    const isExpanded = icon.innerHTML.includes('M20 12H4'); // minus icon

    // Toggle icon
    if (isExpanded) {
        icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>';
        hideChildren(id);
    } else {
        icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path>';
        showDirectChildren(id);
    }
};

function showDirectChildren(parentId) {
    const rows = document.querySelectorAll(`tr[data-parent="${parentId}"]`);
    rows.forEach(row => {
        row.classList.remove('hidden');
    });
}

function hideChildren(parentId) {
    const rows = document.querySelectorAll(`tr[data-parent="${parentId}"]`);
    rows.forEach(row => {
        row.classList.add('hidden');
        const childIcon = document.getElementById(`icon-${row.id}`);
        if (childIcon && childIcon.innerHTML.includes('M20 12H4')) {
            // Collapse recursive
            childIcon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>';
        }
        hideChildren(row.id);
    });
}

let frequencyChartInstance = null;
function renderFrequencyChart(data) {
    const ctx = document.getElementById('frequencyChartContainer');
    if (!ctx) return;

    // Clear existing
    ctx.innerHTML = '<canvas id="freqCanvas"></canvas>';
    const canvas = document.getElementById('freqCanvas');

    if (frequencyChartInstance) {
        frequencyChartInstance.destroy();
    }

    const chartData = data.chart_data || [];
    const currentYear = data.current_year;
    const previousYear = data.previous_year;

    document.getElementById('freq-chart-legend-curr').textContent = currentYear;
    document.getElementById('freq-chart-legend-prev').textContent = previousYear;

    const monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];

    const currDataArray = new Array(12).fill(null);
    const prevDataArray = new Array(12).fill(null);

    chartData.forEach(row => {
        const freq = row.total_clientes > 0 ? (row.total_pedidos / row.total_clientes) : null;
        if (row.ano == currentYear) {
            currDataArray[row.mes - 1] = freq ? parseFloat(freq.toFixed(2)) : null;
        } else if (row.ano == previousYear) {
            prevDataArray[row.mes - 1] = freq ? parseFloat(freq.toFixed(2)) : null;
        }
    });

    frequencyChartInstance = new Chart(canvas, {
        type: 'line',
        data: {
            labels: monthInitials,
            datasets: [
                {
                    label: previousYear.toString(),
                    data: prevDataArray,
                    borderColor: '#CBD5E1', // slate-300
                    backgroundColor: '#CBD5E1',
                    borderDash: [5, 5],
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#CBD5E1',
                    spanGaps: true
                },
                {
                    label: currentYear.toString(),
                    data: currDataArray,
                    borderColor: '#1A73E8', // Blue
                    backgroundColor: '#1A73E8',
                    tension: 0.4,
                    borderWidth: 3,
                    pointRadius: 4,
                    pointBackgroundColor: '#1A73E8',
                    spanGaps: true
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    display: false // Use custom HTML legend
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    callbacks: {
                        label: function(context) {
                            let val = context.raw;
                            if (val !== null) {
                                return context.dataset.label + ': ' + val.toFixed(2);
                            }
                            return context.dataset.label + ': -';
                        }
                    }
                },
                datalabels: {
                    display: false
                }
            },
            scales: {
                x: {
                    grid: { display: false, drawBorder: false },
                    ticks: { color: '#94a3b8', font: { size: 10 } }
                },
                y: {
                    display: false, // hide Y axis
                    min: 0,
                    grace: '10%'
                }
            }
        }
    });
}
