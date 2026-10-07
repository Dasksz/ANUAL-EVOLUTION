const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
function worker(fetch) {
  const context = vm.createContext({ self: { importScripts() {} }, fetch,
    AbortController, setTimeout, clearTimeout, TextEncoder,
    console: { warn() {} } });
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../src/js/worker.js'), 'utf8'), context);
  return context;
}
test('stalled IBGE request times out and aborts instead of blocking import', async () => {
  let signal;
  const context = worker((url, options) => { signal = options.signal; return new Promise(() => {}); });
  const result = await context.fetchIbgeMapping(10);
  assert.equal(Object.keys(result).length, 0);
  assert.equal(signal.aborted, true);
});
test('stalled IBGE response body is also bounded', async () => {
  const context = worker(async () => ({ ok: true, json: () => new Promise(() => {}) }));
  assert.equal(Object.keys(await context.fetchIbgeMapping(10)).length, 0);
});
test('IBGE names resolve on success and service errors preserve original codes', async () => {
  const context = worker(async () => ({ ok: true, json: async () => [{ id: 2913606, nome: 'Ilhéus' }] }));
  assert.equal((await context.fetchIbgeMapping(100))[2913606], 'ILHÉUS');
  const failed = worker(async () => ({ ok: false }));
  assert.equal(Object.keys(await failed.fetchIbgeMapping(100)).length, 0);
});
