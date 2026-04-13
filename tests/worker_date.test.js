import { test } from 'node:test';
import assert from 'node:assert';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { parseDate } = require('../src/js/worker.js');

test('parseDate 2-digit years', async (t) => {
    await t.test('handles DD/MM/YY format (future-ish)', () => {
        const dt = parseDate('01/01/26');
        assert.strictEqual(dt.getUTCFullYear(), 2026);
        assert.strictEqual(dt.getUTCMonth(), 0);
        assert.strictEqual(dt.getUTCDate(), 1);
    });

    await t.test('handles DD/MM/YY format (past)', () => {
        const dt = parseDate('31/12/99');
        assert.strictEqual(dt.getUTCFullYear(), 1999);
        assert.strictEqual(dt.getUTCMonth(), 11);
        assert.strictEqual(dt.getUTCDate(), 31);
    });

    await t.test('handles DD/MM/YY format (threshold 50)', () => {
        const dt50 = parseDate('15/05/50');
        assert.strictEqual(dt50.getUTCFullYear(), 1950);

        const dt49 = parseDate('15/05/49');
        assert.strictEqual(dt49.getUTCFullYear(), 2049);
    });

    await t.test('handles YYYY-MM-DD fast path with 00YY', () => {
        const dt = parseDate('0026-01-01');
        assert.strictEqual(dt.getUTCFullYear(), 2026);
    });

    await t.test('handles DD/MM/YYYY fast path with 00YY', () => {
        const dt = parseDate('01/01/0026');
        assert.strictEqual(dt.getUTCFullYear(), 2026);
    });

    await t.test('handles standard 4-digit years', () => {
        const dt = parseDate('01/01/2026');
        assert.strictEqual(dt.getUTCFullYear(), 2026);

        const iso = parseDate('2026-05-15');
        assert.strictEqual(iso.getUTCFullYear(), 2026);
    });
});

test('parseDate edge cases', async (t) => {
    await t.test('handles null/undefined/empty', () => {
        assert.strictEqual(parseDate(null), null);
        assert.strictEqual(parseDate(undefined), null);
        assert.strictEqual(parseDate(''), null);
        assert.strictEqual(parseDate('   '), null);
    });

    await t.test('handles invalid dates', () => {
        assert.strictEqual(parseDate('not-a-date'), null);
        // Note: 32/01/2024 is actually parsed by Date.UTC as 01/02/2024
        const dt = parseDate('32/01/2024');
        assert.ok(dt instanceof Date);
        assert.strictEqual(dt.getUTCFullYear(), 2024);
        assert.strictEqual(dt.getUTCMonth(), 1); // February
        assert.strictEqual(dt.getUTCDate(), 1);
    });

    await t.test('handles Date objects', () => {
        const d = new Date();
        assert.strictEqual(parseDate(d), d);
        assert.strictEqual(parseDate(new Date('invalid')), null);
    });
});
