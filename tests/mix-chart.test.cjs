const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../src/js/app.js'), 'utf8');
const start = source.indexOf('function renderMixSaltyFoodsChart(data)');
const end = source.indexOf('// AGENDA VIEW LOGIC', start);
assert.ok(start >= 0 && end > start);
let plotted;
const context = vm.createContext({
  document: { getElementById: () => ({ innerHTML: '' }) },
  AppLog: { log() {}, warn() {} },
  MONTHS_PT_INITIALS: ['J','F','M','A','M','J','J','A','S','O','N','D'],
  mixSaltyFoodsChartInstance: null,
  Chart: function (_, config) { plotted = config; this.destroy = () => {}; },
});
vm.runInContext(source.slice(start, end), context);
context.renderMixSaltyFoodsChart({ chart_data: [
  { mes: 8, total_salty: 2, total_foods: 1, total_ambas: 1 },
  { mes: 9, total_salty: 3, total_foods: 0, total_ambas: 0 },
] });
for (const series of plotted.data.datasets) {
  assert.equal(series.data[0], null, 'Unreported month must remain missing');
  assert.equal(series.data[9], null, 'Future month must remain missing');
  assert.equal(series.data[11], null);
}
assert.equal(plotted.data.datasets.find(s => s.label === 'Realizado Foods').data[8], 0, 'Real zero must be retained');
assert.equal(plotted.data.datasets.find(s => s.label === 'Realizado Salty')._sum, 5);
console.log('PASS: missing Mix months are gaps, reported zero and series ordering preserved');

context.renderMixSaltyFoodsChart({chart_data:[{mes:10,total_salty:661,total_foods:23,total_ambas:22}],goal_series:{salty:Array(12).fill(1381),foods:Array(12).fill(299)}});
const items=plotted.data.datasets.map(dataset=>({dataset}));
items.sort(plotted.options.plugins.tooltip.itemSort);
assert.deepEqual(Array.from(items, i=>i.dataset.label), ['Meta Salty','Realizado Salty','Meta Foods','Realizado Foods','Ambos']);
console.log('PASS: Mix tooltip groups each target with its actual, with Ambos last');
