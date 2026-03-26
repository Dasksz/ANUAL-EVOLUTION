const fs = require('fs');

const appJsPath = 'src/js/app.js';
let content = fs.readFileSync(appJsPath, 'utf8');

const targetStr = `
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
        },`;

const replacementStr = `
    const saltySum = saltyData.reduce((a, b) => a + b, 0);
    const foodsSum = foodsData.reduce((a, b) => a + b, 0);
    const ambasSum = ambasData.reduce((a, b) => a + b, 0);

    const datasets = [
        {
            label: 'Salty',
            data: saltyData,
            borderColor: '#F97316', // orange
            backgroundColor: 'rgba(249, 115, 22, 0.2)',
            tension: 0.4,
            borderWidth: 2,
            pointRadius: 4,
            pointBackgroundColor: '#F97316',
            fill: true,
            _sum: saltySum
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
            fill: true,
            _sum: foodsSum
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
            fill: true,
            _sum: ambasSum
        }
    ];

    // Ordenar para desenhar primeiro os maiores volumes (atrás), depois os menores (na frente)
    datasets.sort((a, b) => b._sum - a._sum);

    mixSaltyFoodsChartInstance = new Chart(canvas, {
        type: 'line',
        data: {
            labels: monthInitials,
            datasets: datasets
        },`;

content = content.replace(targetStr, replacementStr);

fs.writeFileSync(appJsPath, content, 'utf8');
console.log('Patch applied successfully.');
