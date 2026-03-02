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

    // Build hierarchy
    const hierarchy = {
        name: 'PRIME',
        children: {},
        totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, sum_skus: 0, total_pedidos: 0, base_total: 0, clientsWithSales: 0 }
    };

    treeData.forEach(row => {
        const filial = row.filial || 'SEM FILIAL';
        const cidade = row.cidade || 'SEM CIDADE';
        const vendedor = row.vendedor || 'SEM VENDEDOR';

        if (!hierarchy.children[filial]) {
            hierarchy.children[filial] = {
                name: filial,
                children: {},
                totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, sum_skus: 0, total_pedidos: 0, base_total: 0, clientsWithSales: 0 }
            };
        }

        if (!hierarchy.children[filial].children[cidade]) {
            hierarchy.children[filial].children[cidade] = {
                name: cidade,
                children: {},
                totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, sum_skus: 0, total_pedidos: 0, base_total: 0, clientsWithSales: 0 }
            };
        }

        const leaf = {
            name: vendedor,
            tons: row.tons || 0,
            faturamento: row.faturamento || 0,
            faturamento_prev: row.faturamento_prev || 0,
            positivacao: row.positivacao || 0,
            sum_skus: row.sum_skus || 0,
            total_pedidos: row.total_pedidos || 0,
            base_total: row.base_total || 0,
            clientsWithSales: (row.faturamento > 0) ? row.positivacao : 0
        };

        hierarchy.children[filial].children[cidade].children[vendedor] = leaf;

        // Roll up totals
        [hierarchy, hierarchy.children[filial], hierarchy.children[filial].children[cidade]].forEach(node => {
            node.totals.tons += leaf.tons;
            node.totals.faturamento += leaf.faturamento;
            node.totals.faturamento_prev += leaf.faturamento_prev;
            node.totals.positivacao += leaf.positivacao;
            node.totals.sum_skus += leaf.sum_skus;
            node.totals.total_pedidos += leaf.total_pedidos;
            // Base total is an approximation at higher levels, but for now we sum it.
            // A more accurate base total requires distinct counting at each level in SQL.
            // We'll use the SQL supplied base_total for branches/cities, but here we sum them.
        });
    });

    // Quick fix for base_total aggregation issues (distinct client counting is hard in JS without raw data):
    // For simplicity, we just sum them. It might over-count if a client buys in multiple cities, but usually they don't.

    let rowCounter = 0;

    const createRow = (node, level, parentId = null) => {
        rowCounter++;
        const id = `node-${rowCounter}`;
        const hasChildren = node.children && Object.keys(node.children).length > 0;

        const isRoot = level === 0;
        const indentClass = level === 0 ? '' : (level === 1 ? 'pl-6' : (level === 2 ? 'pl-10' : 'pl-14'));

        const dataNode = isRoot ? node.totals : (hasChildren ? node.totals : node);

        const tons = dataNode.tons / 1000;

        let varYago = 0;
        if (dataNode.faturamento_prev > 0) {
            varYago = ((dataNode.faturamento / dataNode.faturamento_prev) - 1) * 100;
        }

        const varYagoStr = (varYago > 0 ? '+' : '') + varYago.toFixed(1) + '%';
        const varYagoColor = varYago > 0 ? 'text-green-500' : (varYago < 0 ? 'text-red-500' : 'text-slate-400');
        const varYagoIcon = varYago > 0 ? '<svg class="w-4 h-4 text-green-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.707l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd"></path></svg>' : (varYago < 0 ? '<svg class="w-4 h-4 text-red-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.707 10.293a1 1 0 00-1.414 0l-3-3a1 1 0 101.414-1.414L9 14.586V11a1 1 0 10-2 0v3.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3z" clip-rule="evenodd"></path></svg>' : '');

        // SKU / PDV
        const skuPdv = dataNode.positivacao > 0 ? (dataNode.sum_skus / dataNode.positivacao) : 0;

        // Frequencia
        const freq = dataNode.positivacao > 0 ? (dataNode.total_pedidos / dataNode.positivacao) : 0;

        // % Posit
        let percPosit = 0;
        if (isRoot) {
            // For root, total base comes from the top SQL if possible. But here we sum the city bases.
            let rootBase = 0;
            treeData.forEach(r => rootBase += (r.base_total || 0));
            // Use total clients attended from dashboard data as Posit if we want to be exact with Main Dashboard, but here we use table data
             let distinctPosit = dataNode.positivacao;
             percPosit = rootBase > 0 ? (distinctPosit / rootBase) * 100 : 0;
        } else {
             // Let's use node.base_total if it was a leaf, or sum of leaves.
             // But wait, base_total for leaves is 0 in SQL. Let's adjust logic.
             // City has base_total.
             let nodeBase = dataNode.base_total || 0;
             if(level === 1) { // Filial
                  nodeBase = 0;
                  Object.values(node.children).forEach(city => {
                      // Sum the first leaf's base_total
                      const leaves = Object.values(city.children);
                      if(leaves.length > 0) nodeBase += leaves[0].base_total;
                  });
             } else if (level === 2) { // City
                  const leaves = Object.values(node.children);
                  if(leaves.length > 0) nodeBase = leaves[0].base_total;
             }

             if (nodeBase > 0) {
                 percPosit = (dataNode.positivacao / nodeBase) * 100;
             }
        }

        // Failsafe for % posit > 100
        if(percPosit > 100) percPosit = 100;

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
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${dataNode.positivacao}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${percPosit.toFixed(1)}%</td>
            </tr>
        `;
        tableBody.insertAdjacentHTML('beforeend', rowHtml);

        if (hasChildren) {
            Object.values(node.children).forEach(child => createRow(child, level + 1, id));
        }

        return { tons, varYagoStr, varYagoColor, varYagoIcon, skuPdv, freq, positivacao: dataNode.positivacao, percPosit };
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
