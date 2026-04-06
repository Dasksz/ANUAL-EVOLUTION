import { test } from 'node:test';
import assert from 'node:assert';
import { formatNumber, escapeHtml } from '../src/js/utils.js';

test('formatNumber', async (t) => {
    await t.test('formats numbers correctly with default decimals (2)', () => {
        // Note: pt-BR uses . as group separator and , as decimal separator
        // toLocaleString might behave differently in Node environments depending on ICU data
        // but let's test the core logic first.
        const result = formatNumber(1234.567);
        // We use regex to be flexible with different whitespace types (e.g. non-breaking space)
        assert.match(result, /1[.,]234,57/);
    });

    await t.test('formats numbers correctly with custom decimals', () => {
        const result1 = formatNumber(1234.567, 1);
        assert.match(result1, /1[.,]234,6/);

        const result0 = formatNumber(1234.567, 0);
        assert.match(result0, /1[.,]235/);
    });

    await t.test('handles null/undefined inputs', () => {
        assert.strictEqual(formatNumber(null), '--');
        assert.strictEqual(formatNumber(undefined), '--');
    });

    await t.test('handles non-numeric string inputs', () => {
        assert.strictEqual(formatNumber('not a number'), '--');
    });

    await t.test('handles numeric string inputs', () => {
        const result = formatNumber('1234.56');
        assert.match(result, /1[.,]234,56/);
    });
});

test('escapeHtml', async (t) => {
    await t.test('escapes special characters', () => {
        assert.strictEqual(escapeHtml('<script>alert("xss")</script>'), '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;');
    });

    await t.test('handles null/undefined', () => {
        assert.strictEqual(escapeHtml(null), '');
        assert.strictEqual(escapeHtml(undefined), '');
    });

    await t.test('handles plain text', () => {
        assert.strictEqual(escapeHtml('Hello World'), 'Hello World');
    });
});
