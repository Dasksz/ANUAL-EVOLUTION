const test = require('node:test');
const assert = require('node:assert');
const { parseBrazilianNumber } = require('../src/js/worker.js');

test('parseBrazilianNumber tests', async (t) => {
    await t.test('should return the value if it is already a number', () => {
        assert.strictEqual(parseBrazilianNumber(123.45), 123.45);
        assert.strictEqual(parseBrazilianNumber(0), 0);
        assert.strictEqual(parseBrazilianNumber(-10.5), -10.5);
    });

    await t.test('should return 0 for non-string/non-number values or empty strings', () => {
        assert.strictEqual(parseBrazilianNumber(null), 0);
        assert.strictEqual(parseBrazilianNumber(undefined), 0);
        assert.strictEqual(parseBrazilianNumber(''), 0);
        assert.strictEqual(parseBrazilianNumber([]), 0);
        assert.strictEqual(parseBrazilianNumber({}), 0);
    });

    await t.test('should parse Brazilian formatted numbers (comma as decimal separator)', () => {
        assert.strictEqual(parseBrazilianNumber('1.000,50'), 1000.50);
        assert.strictEqual(parseBrazilianNumber('1.234.567,89'), 1234567.89);
        assert.strictEqual(parseBrazilianNumber('0,99'), 0.99);
        assert.strictEqual(parseBrazilianNumber(',50'), 0.50);
    });

    await t.test('should parse currency strings with R$', () => {
        assert.strictEqual(parseBrazilianNumber('R$ 1.000,50'), 1000.50);
        assert.strictEqual(parseBrazilianNumber('R$1.000,50'), 1000.50);
        assert.strictEqual(parseBrazilianNumber('R$  10,00'), 10.00);
    });

    await t.test('should parse US/International formatted numbers (dot as decimal separator)', () => {
        assert.strictEqual(parseBrazilianNumber('1,000.50'), 1000.50);
        assert.strictEqual(parseBrazilianNumber('1,234,567.89'), 1234567.89);
        assert.strictEqual(parseBrazilianNumber('0.99'), 0.99);
        assert.strictEqual(parseBrazilianNumber('.50'), 0.50);
    });

    await t.test('should handle simple numbers in strings', () => {
        assert.strictEqual(parseBrazilianNumber('123'), 123);
        assert.strictEqual(parseBrazilianNumber('123.45'), 123.45);
        assert.strictEqual(parseBrazilianNumber('123,45'), 123.45);
    });

    await t.test('should return 0 for invalid number strings', () => {
        assert.strictEqual(parseBrazilianNumber('abc'), 0);
        assert.strictEqual(parseBrazilianNumber('R$ abc'), 0);
        assert.strictEqual(parseBrazilianNumber('--123'), 0);
    });

    await t.test('should handle negative numbers in strings', () => {
        assert.strictEqual(parseBrazilianNumber('-1.000,50'), -1000.50);
        assert.strictEqual(parseBrazilianNumber('-1,000.50'), -1000.50);
        assert.strictEqual(parseBrazilianNumber('-123,45'), -123.45);
    });

    await t.test('should handle strings with extra whitespace', () => {
        assert.strictEqual(parseBrazilianNumber('  1.000,50  '), 1000.50);
        assert.strictEqual(parseBrazilianNumber('\n100,00\t'), 100.00);
    });
});
