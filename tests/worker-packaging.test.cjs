const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');

function csv(name, rows) {
  const keys = [...new Set(rows.flatMap(Object.keys))];
  return {name, text:[keys.join(';'), ...rows.map(r=>keys.map(k=>r[k] ?? '').join(';'))].join('\n')};
}
async function run(data) {
  const messages=[];
  class FileReader {
    readAsArrayBuffer(file) { this.onload({target:{result:new TextEncoder().encode(file.text).buffer}}); }
  }
  const self={importScripts(){},crypto:webcrypto,postMessage(m){messages.push(m);}};
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../src/js/worker.js'),'utf8'),
    vm.createContext({self,FileReader,TextEncoder,TextDecoder,console}));
  await self.onmessage({data:{cityBranchMap:{},...data}});
  return {error:messages.find(m=>m.type==='error'), data:messages.find(m=>m.type==='result')?.data};
}
const sale={CODSUPERVISOR:'12',SUPERV:'TIAGO',CODUSUR:'100',NOME:'VENDEDOR',CODCLI:'1000',
  MUNICIPIO:'ILHEUS',OBSERVACAOFOR:'PEPSICO',FILIAL:'8',DTPED:'2026-09-10',
  NUMPED:'1000',PRODUTO:'5459',CODFOR:'1119',TIPOVENDA:'1',VLVENDA:'100',QTVENDA:'28'};
function product(master, codigo='5459') {
  return {'Código':codigo,'Descrição':'QUAKER AVEIA','Fornecedor':'1119','Qtde embalagem master(Compra)':master};
}
for (const master of ['',undefined,'abc','28 unidades',0,-2]) {
  test('invalid packaging stops before upload: '+String(master),async()=>{
    const {error,data}=await run({salesCurrMonthFile:csv('sales.csv',[sale]),productsFile:csv('products.csv',[product(master)])});
    assert.match(error.message,/5459.*embalagem master.*inválida/);
    assert.equal(data,undefined);
  });
}
test('partial product file cannot recreate a sold SKU with master one',async()=>{
  const {data,error}=await run({salesCurrMonthFile:csv('sales.csv',[sale]),
    existingProductsMap:[{codigo:'5459',qtde_embalagem_master:28}],
    productsFile:csv('products.csv',[product(12,'5462')])});
  assert.equal(error,undefined);
  assert.ok(!data.newProducts.some(p=>p.codigo==='5459'));
});
test('sales-only stock conversion uses registered packaging and keeps fractional boxes',async()=>{
  const {data,error}=await run({salesCurrMonthFile:csv('sales.csv',[{...sale,ESTOQUECX:'',ESTOQUEUNIT:'30'}]),
    existingProductsMap:[{codigo:'5459',qtde_embalagem_master:28}]});
  assert.equal(error,undefined);
  assert.equal(data.newProducts,null);
  assert.equal(data.productStock[0].estoque,1.071);
});
test('unknown unit stock cannot silently assume master one',async()=>{
  const {error}=await run({salesCurrMonthFile:csv('sales.csv',[{...sale,ESTOQUEUNIT:'28'}])});
  assert.match(error.message,/embalagem master válida/);
});
test('real packaging of one remains valid',async()=>{
  const {data,error}=await run({salesCurrMonthFile:csv('sales.csv',[sale]),
    productsFile:csv('products.csv',[product(1)])});
  assert.equal(error,undefined);
  assert.equal(data.newProducts[0].qtde_embalagem_master,1);
});
test('no unit stock does not require a product spreadsheet',async()=>{
  const {data,error}=await run({salesCurrMonthFile:csv('sales.csv',[{...sale,ESTOQUEUNIT:'0'}])});
  assert.equal(error,undefined);
  assert.equal(data.newProducts,null);
  assert.equal(data.productStock[0].estoque,0);
});


