const fs = require('fs');

const path = 'src/js/frequency_table.js';
let content = fs.readFileSync(path, 'utf-8');

const regex = /let mixSaltyFoodsChartInstance = null;[\s\S]*\}\n\}\n/g;

const newCode = `let mixSaltyFoodsChartInstance = null;
function renderMixSaltyFoodsChart(data) {
    const container = document.getElementById('mixSaltyFoodsChartContainer');
    if (!container) {
        console.warn('Container mixSaltyFoodsChartContainer não encontrado.');
        return;
    }

    // Always clear the container first
    container.innerHTML = '<canvas id="mixSaltyFoodsCanvas"></canvas>';
    const canvas = document.getElementById('mixSaltyFoodsCanvas');
    if (!canvas) {
        console.warn('Canvas mixSaltyFoodsCanvas não criado.');
        return;
    }

    if (mixSaltyFoodsChartInstance) {
        mixSaltyFoodsChartInstance.destroy();
    }

    const chartData = (data && data.chart_data) ? data.chart_data : [];
    console.log("Renderizando Mix Salty & Foods Chart com dados:", chartData);

    const monthInitials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
    const saltyData = new Array(12).fill(0);
    const foodsData = new Array(12).fill(0);
    const ambasData = new Array(12).fill(0);

    chartData.forEach(row => {
        const monthIndex = row.mes - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
            saltyData[monthIndex] = (row.total_salty !== undefined && row.total_salty !== null) ? row.total_salty : 0;
            foodsData[monthIndex] = (row.total_foods !== undefined && row.total_foods !== null) ? row.total_foods : 0;
            ambasData[monthIndex] = (row.total_ambas !== undefined && row.total_ambas !== null) ? row.total_ambas : 0;
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
                    borderColor: '#F97316', // orange
                    backgroundColor: 'rgba(249, 115, 22, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#F97316',
                    fill: true
                },
                {
                    label: 'Foods',
                    data: foodsData,
                    borderColor: '#3B82F6', // blue
                    backgroundColor: 'rgba(59, 130, 246, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#3B82F6',
                    fill: true
                },
                {
                    label: 'Ambas',
                    data: ambasData,
                    borderColor: '#A855F7', // purple
                    backgroundColor: 'rgba(168, 85, 247, 0.2)',
                    tension: 0.4,
                    borderWidth: 2,
                    pointRadius: 4,
                    pointBackgroundColor: '#A855F7',
                    fill: true
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
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    displayColors: true
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
                    display: false,
                    min: 0,
                    grace: '10%'
                }
            }
        }
    });
}
`;

content = content.replace(regex, newCode);
fs.writeFileSync(path, content);
