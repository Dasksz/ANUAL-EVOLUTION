const test = require('node:test');
const assert = require('node:assert');
const { parseExcelDate, parseDate } = require('../src/js/worker');

test('parseExcelDate parses basic dates correctly', () => {
    // 45262 is 2023-12-02
    const d1 = parseExcelDate(45262);
    assert.strictEqual(d1.toISOString(), '2023-12-02T00:00:00.000Z');
});

test('parseExcelDate handles leap year bug threshold correctly', () => {
    // Excel thinks 1900 is a leap year. So day 60 is Feb 29, 1900.
    // In actual Gregorian calendar, 1900 is NOT a leap year, so day 60 is Feb 28, 1900
    // But since Excel shifts everything after day 60 by 1, day 60 is mapped to Feb 28, 1900
    // and day 61 is mapped to Mar 1, 1900
    const feb28 = parseExcelDate(59);
    assert.strictEqual(feb28.toISOString(), '1900-02-28T00:00:00.000Z');

    // Excel day 60 is Feb 29 1900, which doesn't exist, so JS wraps to Mar 1
    const feb29 = parseExcelDate(60);
    assert.strictEqual(feb29.toISOString(), '1900-03-01T00:00:00.000Z');

    const mar1 = parseExcelDate(61);
    assert.strictEqual(mar1.toISOString(), '1900-03-01T00:00:00.000Z');
});

test('parseDate uses parseExcelDate correctly', () => {
    const d1 = parseDate(45262);
    assert.strictEqual(d1.toISOString(), '2023-12-02T00:00:00.000Z');
});

test('parseDate handles various formats', () => {
    const d1 = parseDate('2023-12-02');
    assert.strictEqual(d1.toISOString().startsWith('2023-12-02'), true);

    const d2 = parseDate('02/12/2023');
    // Expect 2023-12-02 since it forces DD/MM/YYYY into UTC Date
    assert.strictEqual(d2.toISOString(), '2023-12-02T00:00:00.000Z');
});

test('parseDate rejects invalid dates in fast path correctly', () => {
    // Should return null for non-date strings that match length and delimiter rules
    const d1 = parseDate('word-is-it');
    assert.strictEqual(d1, null);

    const d2 = parseDate('  23-11-20');
    // For spaces, it should fallback and probably parse as invalid or return null
    // (the fallback Date constructor might parse it or return Invalid Date, but the fast path should skip it)
    // Actually the fallback Date constructor might parse it if it looks like a valid ISO date, but let's check what it does
    // Let's just check that it doesn't return a corrupted year like -17577
    if (d2) {
         assert.notStrictEqual(d2.getFullYear(), -17577);
    }
});

test('parseDate handles 2-digit years correctly in fallback path', () => {
    const d1 = parseDate('13/01/24 10:00');
    assert.notStrictEqual(d1, null, '13/01/24 10:00 should not be null');
    assert.strictEqual(d1.getUTCFullYear(), 2024, '13/01/24 10:00 should be 2024');

    const d2 = parseDate('1/1/24');
    assert.strictEqual(d2.getUTCFullYear(), 2024, '1/1/24 should be 2024');

    const d3 = parseDate('01/01/99');
    assert.strictEqual(d3.getUTCFullYear(), 1999, '01/01/99 should be 1999');

    const d4 = parseDate('01/01/00');
    assert.strictEqual(d4.getUTCFullYear(), 2000, '01/01/00 should be 2000');
});
