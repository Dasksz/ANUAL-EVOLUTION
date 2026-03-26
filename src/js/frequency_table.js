async function loadFrequencyTable(filters) {
    const tableBody = document.getElementById('frequency-table-body');
    const tableFooter = document.getElementById('frequency-table-footer');
    if (!tableBody || !tableFooter) return;

    tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-slate-400 text-xs">Carregando Frequência...</td></tr>';
    let mappedRedes = null;
    if (filters.p_rede && filters.p_rede.length) {
        mappedRedes = filters.p_rede.map(r => {
            if (r === 'C/ REDE') return 'com_ramo';
            if (r === 'S/ REDE') return 'sem_ramo';
            return r;
        });
    }


    try {
        const reqFilters = {
            p_filial: (filters.p_filial && filters.p_filial.length) ? filters.p_filial : null,
            p_cidade: (filters.p_cidade && filters.p_cidade.length) ? filters.p_cidade : null,
            p_supervisor: (filters.p_supervisor && filters.p_supervisor.length) ? filters.p_supervisor : null,
            p_vendedor: (filters.p_vendedor && filters.p_vendedor.length) ? filters.p_vendedor : null,
            p_fornecedor: (filters.p_fornecedor && filters.p_fornecedor.length) ? filters.p_fornecedor : null,
            p_ano: filters.p_ano || null,
            p_mes: (filters.p_mes !== null && filters.p_mes !== '') ? (parseInt(filters.p_mes) + 1).toString() : null,
            p_tipovenda: (filters.p_tipovenda && filters.p_tipovenda.length) ? filters.p_tipovenda : null,
            p_rede: mappedRedes,
            p_produto: (filters.p_produto && filters.p_produto.length) ? filters.p_produto : null,
            p_categoria: (filters.p_categoria && filters.p_categoria.length) ? filters.p_categoria : null
        };
        const [freqResponse, mixResponse] = await Promise.all([
            supabase.rpc('get_frequency_table_data', reqFilters),
            supabase.rpc('get_mix_salty_foods_data', reqFilters)
        ]);

        if (freqResponse.error) throw freqResponse.error;
        if (mixResponse.error) throw mixResponse.error;

        renderFrequencyTable(freqResponse.data, tableBody, tableFooter);
        renderFrequencyChart(freqResponse.data);
        renderMixSaltyFoodsChart(mixResponse.data);

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
        totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, positivacao_mensal: 0, sum_skus: 0, total_pedidos: 0, base_total: 0, clientsWithSales: 0, q_meses: 0 }
    };

    treeData.forEach(row => {
        const filial = row.filial || 'SEM FILIAL';
        const cidade = row.cidade || 'SEM CIDADE';
        const vendedor = row.vendedor || 'SEM VENDEDOR';

        const tons = row.tons || 0;
        const faturamento = row.faturamento || 0;
        const faturamento_prev = row.faturamento_prev || 0;
        const positivacao = row.positivacao || 0;
        const positivacao_mensal = row.positivacao_mensal || 0;
        const sum_skus = row.sum_skus || 0;
        const total_pedidos = row.total_pedidos || 0;
        const base_total = row.base_total || 0;
        const q_meses = row.q_meses || 1;
        const clientsWithSales = (faturamento > 0) ? positivacao : 0;

        const rowData = { tons, faturamento, faturamento_prev, positivacao, positivacao_mensal, sum_skus, total_pedidos, base_total, clientsWithSales, q_meses };

        // Rely strictly on ROLLUP flags
        if (row.grp_filial === 1) {
            hierarchy.totals = { ...rowData, base_total: rowData.base_total || 0 };
            return;
        }
        if (row.grp_cidade === 1) {
            if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: rowData };
            else hierarchy.children[filial].totals = rowData;
            return;
        }
        if (row.grp_vendedor === 1) {
            if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
            if (!hierarchy.children[filial].children[cidade]) hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: rowData };
            else hierarchy.children[filial].children[cidade].totals = rowData;
            return;
        }

        // Leaf Node (grp_vendedor === 0)
        if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
        if (!hierarchy.children[filial].children[cidade]) hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: {} };
        
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
        const freq = dataNode.positivacao_mensal > 0 ? ((dataNode.total_pedidos || 0) / dataNode.positivacao_mensal) : 0;

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
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${freq.toFixed(2)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${positStr}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${percPositStr}</td>
            </tr>
        `;
        tableBody.insertAdjacentHTML('beforeend', rowHtml);

        if (hasChildren) {
            Object.values(node.children).forEach(child => createRow(child, level + 1, id));
        }

        return { tons, varYagoStr, varYagoColor, varYagoIcon, skuPdv, freq, positivacao: dataNode.positivacao || 0, percPosit, positivacao_mensal: dataNode.positivacao_mensal || 0, q_meses: dataNode.q_meses };
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
            <td class="px-2 py-3 border-t border-white/20 text-right">${rootData.freq.toFixed(2)}</td>
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

let mixSaltyFoodsChartInstance = null;
function renderMixSaltyFoodsChart(data) {
    const ctx = document.getElementById('mixSaltyFoodsChartContainer');
    if (!ctx) return;

    // Clear existing
    ctx.innerHTML = '<canvas id="mixSaltyFoodsCanvas"></canvas>';
    const canvas = document.getElementById('mixSaltyFoodsCanvas');

    if (mixSaltyFoodsChartInstance) {
        mixSaltyFoodsChartInstance.destroy();
    }

    const chartData = data.chart_data || [];

    // We only have the current year data in chartData because of the SQL constraint
    // Always initialize with 12 months array for the current year
    const monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
    const saltyData = new Array(12).fill(0);
    const foodsData = new Array(12).fill(0);
    const ambasData = new Array(12).fill(0);

    chartData.forEach(row => {
        const monthIndex = row.mes - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
            saltyData[monthIndex] = row.total_salty !== undefined ? row.total_salty : 0;
            foodsData[monthIndex] = row.total_foods !== undefined ? row.total_foods : 0;
            ambasData[monthIndex] = row.total_ambas !== undefined ? row.total_ambas : 0;
        }
    });

    mixSaltyFoodsChartInstance = new Chart(canvas, {
        type: 'line',
        data: {
            labels: monthInitials,
            datasets: [
                {
                    label: 'Salty',
                    data: saltyData,
                    borderColor: '#F97316', // orange-500
                    backgroundColor: 'rgba(249, 115, 22, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#F97316',
                    fill: true,
                },
                {
                    label: 'Foods',
                    data: foodsData,
                    borderColor: '#3B82F6', // blue-500
                    backgroundColor: 'rgba(59, 130, 246, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#3B82F6',
                    fill: true,
                },
                {
                    label: 'Ambas',
                    data: ambasData,
                    borderColor: '#A855F7', // purple-500
                    backgroundColor: 'rgba(168, 85, 247, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#A855F7',
                    fill: true,
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
                    display: false // We use our custom legend in HTML
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    displayColors: true,
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) {
                                label += ': ';
                            }
                            if (context.parsed.y !== null) {
                                label += context.parsed.y + ' Clientes';
                            }
                            return label;
                        }
                    }
                },
                datalabels: {
                    display: false // Hide datalabels for cleaner look since it has area
                }
            },
            scales: {
                x: {
                    grid: { display: false, drawBorder: false },
                    ticks: { color: '#94a3b8', font: { size: 10 } }
                },
                y: {
                    display: false, // Hide Y axis like in frequency chart
                    min: 0,
                    grace: '10%'
                }
            }
        }
    });
}
