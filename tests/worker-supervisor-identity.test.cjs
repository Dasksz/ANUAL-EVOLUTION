const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');

function csv(name, rows) {
  const keys = [...new Set(rows.flatMap(Object.keys))];
  return { name, text: [keys.join(';'), ...rows.map(r => keys.map(k => r[k] ?? '').join(';'))].join('\n') };
}
function sale(code, vendor, client, overrides = {}) {
  return { CODSUPERVISOR: code, SUPERV: 'NOME ANTIGO', CODUSUR: vendor,
    NOME: 'VENDEDOR ' + vendor, CODCLI: client, MUNICIPIO: 'ILHEUS',
    OBSERVACAOFOR: 'PEPSICO', FILIAL: '5', DTPED: '2025-09-10',
    NUMPED: client, PRODUTO: '1', CODFOR: '707', TIPOVENDA: '1',
    VLVENDA: '100', QTVENDA: '1', ...overrides };
}
async function runWorker(data) {
  const messages = [];
  class FileReader {
    readAsArrayBuffer(file) {
      this.onload({ target: { result: new TextEncoder().encode(file.text).buffer } });
    }
  }
  const self = { importScripts() {}, crypto: webcrypto, postMessage(m) { messages.push(m); } };
  const context = vm.createContext({ self, FileReader, TextEncoder, TextDecoder, console });
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../src/js/worker.js'), 'utf8'), context);
  await self.onmessage({ data: { cityBranchMap: {}, ...data } });
  const error = messages.find(m => m.type === 'error');
  assert.equal(error, undefined, error?.message);
  return JSON.parse(JSON.stringify(messages.find(m => m.type === 'result').data));
}
const clients = csv('clients.csv', [
  { 'Código': '1000', 'RCA 1': '100', Cliente: 'CLIENTE A' },
  { 'Código': '1001', 'RCA 1': '101', Cliente: 'CLIENTE B' },
  { 'Código': '1002', 'RCA 1': '102', Cliente: 'CLIENTE C' },
  { 'Código': '6421', 'RCA 1': '100', Cliente: 'BALCAO' },
]);

for (const fileKey of ['salesPrevYearFile', 'salesCurrYearFile', 'salesCurrMonthFile']) {
  test('Rômulo identity survives ' + fileKey + ' import with historical codes intact', async () => {
    const data = await runWorker({ clientsFile: clients, [fileKey]: csv('sales.csv', [
      sale(' 18 ', '100', '1000'),
      sale('21', '101', '1001', { SUPERV: 'DESCONHECIDO' }),
      sale('12', '102', '1002', { SUPERV: 'OUTRO SUPERVISOR' }),
      sale('18', '100', '6421'),
    ]) });
    const supervisors = Object.fromEntries(data.newSupervisors.map(s => [s.codigo, s.nome]));
    assert.equal(supervisors['18'], 'RÔMULO AMADO DA');
    assert.equal(supervisors['21'], 'RÔMULO AMADO DA');
    assert.equal(supervisors['12'], 'TIAGO JOSÉ DE S');
    assert.equal(supervisors['8'], 'BALCAO');
    const rows = Object.values(data.historyChunks || data.detailedChunks).flatMap(c => c.rows);
    assert.equal(rows.find(r => r.codcli === '1000').codsupervisor, '18');
    assert.equal(rows.find(r => r.codcli === '1001').codsupervisor, '21');
    assert.equal(rows.find(r => r.codcli === '1000').codusur, '100');
    assert.equal(rows.reduce((sum, r) => sum + r.vlvenda, 0), 400);
  });
}
test('valid client RCA replaces an INAT seller while retaining Rômulo identity', async () => {
  const data = await runWorker({ clientsFile: clients,
    salesPrevYearFile: csv('history.csv', [sale('18', 'INAT_ANTIGO', '1000')]),
    salesCurrMonthFile: csv('current.csv', [sale('21', '100', '1000', { DTPED: '2026-10-01', SUPERV: 'ROMULO SEM ACENTO' })]),
  });
  const row = Object.values(data.historyChunks).flatMap(c => c.rows)[0];
  assert.equal(row.codusur, '100');
  assert.equal(row.codsupervisor, '21');
  assert.ok(data.newSupervisors.every(s => s.nome === 'RÔMULO AMADO DA'));
  assert.ok(!data.newVendors.some(v => v.codigo.startsWith('INAT_')));
});


test('omitting client spreadsheet uses registered RCA and does not recreate INAT sellers', async () => {
  const data = await runWorker({ existingClientsMap: [{codigo_cliente:'1000',rca1:'100',nomecliente:'CLIENTE A'}],
    salesCurrMonthFile: csv('current.csv',[sale('12','100','1000',{DTPED:'2026-10-01',SUPERV:'INATIVOS'})]) });
  const row = Object.values(data.detailedChunks).flatMap(c=>c.rows)[0];
  assert.equal(row.codusur,'100');
  assert.equal(row.codsupervisor,'12');
  assert.equal(data.newSupervisors[0].nome,'TIAGO JOSÉ DE S');
  assert.equal(data.clients,null,'existing clients must not be overwritten by a partial import');
});
test('placeholder supervisor cannot overwrite a valid latest name/code pair', async () => {
  const data = await runWorker({clientsFile:clients,
    salesPrevYearFile:csv('history.csv',[sale('10','100','1000',{SUPERV:'SUPERVISOR VALIDO'})]),
    salesCurrMonthFile:csv('current.csv',[sale('99','100','1000',{SUPERV:'INATIVOS',DTPED:'2026-10-01'})])});
  const row=Object.values(data.detailedChunks).flatMap(c=>c.rows)[0];
  assert.equal(row.codsupervisor,'10');
  assert.equal(data.newSupervisors.find(s=>s.codigo==='10').nome,'SUPERVISOR VALIDO');
});
test('vendor 190 rule assigns canonical Tiago name even without raw code 12', async () => {
  const data = await runWorker({clientsFile:csv('clients.csv',[{'Código':'1000','RCA 1':'190',Cliente:'CLIENTE A'}]),
    salesCurrMonthFile:csv('current.csv',[sale('77','190','1000')])});
  const row=Object.values(data.detailedChunks).flatMap(c=>c.rows)[0];
  assert.equal(row.codsupervisor,'12');
  assert.equal(data.newSupervisors.find(s=>s.codigo==='12').nome,'TIAGO JOSÉ DE S');
});
