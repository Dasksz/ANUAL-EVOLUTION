const fs = require('fs');

const path = 'src/js/frequency_table.js';
let content = fs.readFileSync(path, 'utf-8');

const target1 = `        const { data, error } = await supabase.rpc('get_frequency_table_data', reqFilters);

        if (error) throw error;

        renderFrequencyTable(data, tableBody, tableFooter);
        renderFrequencyChart(data);`;

const replacement1 = `        const [freqResponse, mixResponse] = await Promise.all([
            supabase.rpc('get_frequency_table_data', reqFilters),
            supabase.rpc('get_mix_salty_foods_data', reqFilters)
        ]);

        if (freqResponse.error) throw freqResponse.error;
        if (mixResponse.error) throw mixResponse.error;

        renderFrequencyTable(freqResponse.data, tableBody, tableFooter);
        renderFrequencyChart(freqResponse.data);
        renderMixSaltyFoodsChart(mixResponse.data);`;

content = content.replace(target1, replacement1);

const mixSaltyFoodsCode = `
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
    const saltyData = new Array(12).fill(null);
    const foodsData = new Array(12).fill(null);
    const ambasData = new Array(12).fill(null);

    chartData.forEach(row => {
        const monthIndex = row.mes - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
            saltyData[monthIndex] = row.total_salty !== undefined ? row.total_salty : null;
            foodsData[monthIndex] = row.total_foods !== undefined ? row.total_foods : null;
            ambasData[monthIndex] = row.total_ambas !== undefined ? row.total_ambas : null;
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
                    spanGaps: true
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
                    spanGaps: true
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
`;

content += mixSaltyFoodsCode;

fs.writeFileSync(path, content);
