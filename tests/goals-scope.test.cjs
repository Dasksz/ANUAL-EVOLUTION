const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../src/js/app.js'), 'utf8');
const columnsBlock = source.slice(source.indexOf('        const allSvColumns = ['), source.indexOf('        const monthsCount = quarterMonths.length;'));
const columns = selectedSuppliers => JSON.parse(vm.runInNewContext(columnsBlock + '\nJSON.stringify(svColumns.map(c => c.id));', {selectedSuppliers}));
test('supplier selection hides unrelated columns and incomplete Mix blocks', () => {
  assert.deepEqual(columns(['1119_QUAKER_KEROCOCO']), ['total_foods', '1119_QUAKER_KEROCOCO', 'tonelada_foods', 'geral']);
  assert.deepEqual(columns(['707']), ['total_elma', '707', 'tonelada_elma', 'geral']);
  assert.ok(columns(['707', '708', '752']).includes('mix_salty'));
  assert.ok(columns(['1119']).includes('mix_foods'));
  assert.equal(columns([]).length, 14);
});
test('revenue totals use imported category values, including reported zero', () => {
  const start = source.indexOf('                // Imported revenue is stored by category');
  const end = source.indexOf("                sData['geral'].metaVol", start);
  const block = source.slice(start, end);
  const calculate = selectedSuppliers => {
    const sData = Object.fromEntries(['total_elma','total_foods','707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'].map(id => [id,{metaFat:0}]));
    sData['707'].metaFat=310230.67; sData['708'].metaFat=531607.96; sData['752'].metaFat=79058.37;
    return vm.runInNewContext(block + "\nsData['geral'].metaFat;", {sData, elmaSuppliers:['707','708','752'], foodsSuppliers:['1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'], selectedSuppliers, selectedColumnSuppliers:new Set(selectedSuppliers), mapCol:()=>({metaFat:955768.77})});
  };
  assert.equal(Math.round(calculate([]) * 100),92089700);
  assert.equal(calculate(['707']),310230.67);
  assert.equal(calculate(['1119_QUAKER_KEROCOCO']),0);
});
