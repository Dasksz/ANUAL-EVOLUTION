import { test } from 'node:test';
import assert from 'node:assert';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { parseBrazilianNumber } = require('../src/js/worker.js');

test('parseBrazilianNumber - numeric and falsy inputs', async (t) => {
    await t.test('handles numeric input (identity)', () => {
        assert.strictEqual(parseBrazilianNumber(123.45), 123.45);
    });

    await t.test('handles null/undefined/empty', () => {
        assert.strictEqual(parseBrazilianNumber(null), 0);
        assert.strictEqual(parseBrazilianNumber(undefined), 0);
        assert.strictEqual(parseBrazilianNumber(''), 0);
        assert.strictEqual(parseBrazilianNumber('   '), 0);
    });

    await t.test('handles non-numeric strings', () => {
        assert.strictEqual(parseBrazilianNumber('abc'), 0);
    });
});

test('parseBrazilianNumber - format variations', async (t) => {
    await t.test('handles standard Brazilian format', () => {
        assert.strictEqual(parseBrazilianNumber('1.234,56'), 1234.56);
    });

    await t.test('handles Brazilian format without thousand separator', () => {
        assert.strictEqual(parseBrazilianNumber('1234,56'), 1234.56);
    });

    await t.test('handles standard US format', () => {
        assert.strictEqual(parseBrazilianNumber('1,234.56'), 1234.56);
    });

    await t.test('handles US format without thousand separator', () => {
        assert.strictEqual(parseBrazilianNumber('1234.56'), 1234.56);
    });

    await t.test('handles pure integers in strings', () => {
        assert.strictEqual(parseBrazilianNumber('1234'), 1234);
    });
});

test('parseBrazilianNumber - currency and whitespace', async (t) => {
    await t.test('handles R$ prefix', () => {
        assert.strictEqual(parseBrazilianNumber('R$ 1.234,56'), 1234.56);
        assert.strictEqual(parseBrazilianNumber('R$1.234,56'), 1234.56);
    });

    await t.test('handles trailing/leading whitespace', () => {
        assert.strictEqual(parseBrazilianNumber('  123,45  '), 123.45);
    });
});
