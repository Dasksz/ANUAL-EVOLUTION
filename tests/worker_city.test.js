import { test } from 'node:test';
import assert from 'node:assert';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { normalizeCityName } = require('../src/js/worker.js');

test('normalizeCityName', async (t) => {
    await t.test('normalizes city names correctly', () => {
        assert.strictEqual(normalizeCityName('São Paulo'), 'SAO PAULO');
        assert.strictEqual(normalizeCityName('maceió'), 'MACEIO');
        assert.strictEqual(normalizeCityName('CONCEIÇÃO DO JACUÍPE'), 'CONCEICAO DO JACUIPE');
    });

    await t.test('trims whitespace', () => {
        assert.strictEqual(normalizeCityName('  Aracaju  '), 'ARACAJU');
    });

    await t.test('handles falsy and empty inputs', () => {
        assert.strictEqual(normalizeCityName(''), '');
        assert.strictEqual(normalizeCityName(null), '');
        assert.strictEqual(normalizeCityName(undefined), '');
    });

    await t.test('handles numeric inputs', () => {
        assert.strictEqual(normalizeCityName(123), '123');
    });

    await t.test('returns consistent output (caching logic)', () => {
        const first = normalizeCityName('São Paulo');
        const second = normalizeCityName('São Paulo');
        assert.strictEqual(first, second);
        assert.strictEqual(second, 'SAO PAULO');
    });
});
