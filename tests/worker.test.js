const test = require('node:test');
const assert = require('node:assert');

const fs = require('fs');
const path = require('path');
const workerCode = fs.readFileSync(path.join(__dirname, '../src/js/worker.js'), 'utf8');

const initEnv = new Function(`
  ${workerCode}
  return { parseDate };
`);

const { parseDate } = initEnv();

test('parseDate handles 2-digit years correctly', (t) => {
  assert.strictEqual(parseDate('01/01/26').toISOString(), '2026-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('01/01/99').toISOString(), '1999-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('31/12/49').toISOString(), '2049-12-31T00:00:00.000Z');
  assert.strictEqual(parseDate('01/01/50').toISOString(), '1950-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('01/01/00').toISOString(), '2000-01-01T00:00:00.000Z');
});

test('parseDate handles 4-digit years correctly', (t) => {
  assert.strictEqual(parseDate('01/01/2026').toISOString(), '2026-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('2026-01-01').toISOString(), '2026-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('01-01-2026').toISOString(), '2026-01-01T00:00:00.000Z');
  assert.strictEqual(parseDate('01/01/1999').toISOString(), '1999-01-01T00:00:00.000Z');
});
