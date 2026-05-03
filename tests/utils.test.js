import { test } from 'node:test';
import assert from 'node:assert';
import {
    formatNumber,
    escapeHtml,
    setElementLoading,
    restoreElementState,
    formatInteger,
    formatCurrency,
    formatTons,
    updateSvgPaths,
    handleDropdownsClickaway,
    closeAllDropdowns,
    uncheckAllCheckboxes,
    formatPercentage
} from '../src/js/utils.js';

test('updateSvgPaths', () => {
    // Mock SVG structure
    class MockSVG {
        constructor() {
            this.paths = [];
            this.children = [];
        }
        querySelectorAll(selector) {
            if (selector === 'path') return this.paths;
            return [];
        }
        appendChild(child) {
            this.paths.push(child);
            this.children.push(child);
        }
    }
    class MockPath {
        constructor() {
            this.attributes = {};
        }
        setAttribute(name, value) {
            this.attributes[name] = value;
        }
        getAttribute(name) {
            return this.attributes[name];
        }
    }

    // Mock document.createElementNS
    global.document = {
        createElementNS: (ns, name) => {
            if (name === 'path') return new MockPath();
        }
    };

    const svg = new MockSVG();

    // Test: creating paths
    updateSvgPaths(svg, ['M1', 'M2']);
    assert.strictEqual(svg.paths.length, 2);
    assert.strictEqual(svg.paths[0].getAttribute('d'), 'M1');
    assert.strictEqual(svg.paths[1].getAttribute('d'), 'M2');
    assert.strictEqual(svg.paths[0].getAttribute('stroke-width'), '2');

    // Test: hiding extra paths
    updateSvgPaths(svg, ['M3']);
    assert.strictEqual(svg.paths.length, 2);
    assert.strictEqual(svg.paths[0].getAttribute('d'), 'M3');
    assert.strictEqual(svg.paths[1].getAttribute('d'), '');

    // Cleanup global
    delete global.document;
});

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

test('formatInteger', async (t) => {
    await t.test('formats integers correctly with thousand separators', () => {
        const result = formatInteger(1234.56);
        // Math.round(1234.56) = 1235
        assert.match(result, /1[.,]235/);
    });

    await t.test('rounds correctly', () => {
        assert.match(formatInteger(1.4), /1/);
        assert.match(formatInteger(1.5), /2/);
    });

    await t.test('handles null/undefined inputs', () => {
        assert.strictEqual(formatInteger(null), '0');
        assert.strictEqual(formatInteger(undefined), '0');
    });

    await t.test('handles non-numeric string inputs', () => {
        assert.strictEqual(formatInteger('not a number'), '0');
    });

    await t.test('handles numeric string inputs', () => {
        const result = formatInteger('1234.56');
        assert.match(result, /1[.,]235/);
    });
});

test('formatCurrency', async (t) => {
    await t.test('formats currency correctly', () => {
        const result = formatCurrency(1234.56);
        // BRL format: R$ 1.234,56 (with non-breaking spaces sometimes)
        assert.match(result, /R\$\s*1[.,]234,56/);
    });

    await t.test('handles null/undefined inputs', () => {
        assert.strictEqual(formatCurrency(null), 'R$ 0,00');
        assert.strictEqual(formatCurrency(undefined), 'R$ 0,00');
    });

    await t.test('handles non-numeric string inputs', () => {
        assert.strictEqual(formatCurrency('abc'), 'R$ 0,00');
    });
});

test('formatTons', async (t) => {
    await t.test('converts kg to tons correctly', () => {
        const result = formatTons(1500);
        assert.match(result, /1,5 Ton/);
    });

    await t.test('respects custom decimals', () => {
        const result = formatTons(1500, 2);
        assert.match(result, /1,50 Ton/);
    });

    await t.test('handles null/undefined inputs', () => {
        assert.match(formatTons(null), /0,0 Ton/);
        assert.match(formatTons(undefined), /0,0 Ton/);
    });

    await t.test('handles non-numeric string inputs', () => {
        assert.match(formatTons('abc'), /0,0 Ton/);
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

// A minimal mock for testing DOM functions outside a browser environment
class MockElement {
    constructor() {
        this.innerHTML = '';
        this.disabled = false;
    }
}

test('setElementLoading', () => {
    const btn = new MockElement();
    const target = new MockElement();
    target.innerHTML = 'Original Text';

    const originalHtml = setElementLoading(target, btn, 'Loading...', 'text-white');

    assert.strictEqual(originalHtml, 'Original Text');
    assert.strictEqual(btn.disabled, true);
    assert.ok(target.innerHTML.includes('<svg'));
    assert.ok(target.innerHTML.includes('text-white'));
    assert.ok(target.innerHTML.includes('Loading...'));

    const result = setElementLoading(null, btn, 'Loading...');
    assert.strictEqual(result, '');
});

test('restoreElementState', () => {
    const btn = new MockElement();
    const target = new MockElement();
    target.innerHTML = '<svg>...</svg>';
    btn.disabled = true;

    restoreElementState(target, btn, 'Original Text');

    assert.strictEqual(target.innerHTML, 'Original Text');
    assert.strictEqual(btn.disabled, false);

    // Just verify it doesn't throw
    restoreElementState(null, btn, 'Original Text');
});

test('closeAllDropdowns', () => {
    class MockElementWithClass {
        constructor(classes = []) {
            this.classList = {
                classes: new Set(classes),
                contains: (cls) => this.classList.classes.has(cls),
                add: (cls) => this.classList.classes.add(cls)
            };
        }
    }

    const el1 = new MockElementWithClass(['absolute', 'z-[50]']);
    const el2 = new MockElementWithClass(['absolute', 'z-[999]', 'hidden']);
    const el3 = new MockElementWithClass(['absolute', 'z-[50]']);

    const originalDocument = global.document;
    try {
        global.document = {
            querySelectorAll: (selector) => {
                // The selector in src/js/utils.js uses escaped brackets for Tailwind classes
                if (selector.includes('.absolute.z-\\[50\\]') && selector.includes('.absolute.z-\\[999\\]')) {
                    return [el1, el2, el3];
                }
                return [];
            }
        };

        closeAllDropdowns();

        assert.ok(el1.classList.contains('hidden'), 'el1 should have hidden class');
        assert.ok(el2.classList.contains('hidden'), 'el2 should still have hidden class');
        assert.ok(el3.classList.contains('hidden'), 'el3 should have hidden class');
    } finally {
        global.document = originalDocument;
    }
});

test('handleDropdownsClickaway', () => {
    class MockElementWithContains {
        constructor(isHidden) {
            this.classList = {
                contains: (cls) => cls === 'hidden' ? isHidden : false,
                add: (cls) => { if (cls === 'hidden') isHidden = true; }
            };
        }
        contains(target) { return this === target; }
    }

    const dd1 = new MockElementWithContains(false);
    const btn1 = new MockElementWithContains(false);
    const dd2 = new MockElementWithContains(true);
    const btn2 = new MockElementWithContains(false);

    // Case 1: Click outside
    const result1 = handleDropdownsClickaway({ target: {} }, [dd1, dd2], [btn1, btn2]);
    assert.strictEqual(result1, true);

    // Case 2: Click inside dd1
    const result2 = handleDropdownsClickaway({ target: dd1 }, [dd1], [btn1]);
    assert.strictEqual(result2, false);

    // Case 3: Click on btn1
    const result3 = handleDropdownsClickaway({ target: btn1 }, [dd1], [btn1]);
    assert.strictEqual(result3, false);
});

test('uncheckAllCheckboxes', () => {
    const checkboxes = [{ checked: true }, { checked: true }];
    const mockElement = {
        querySelectorAll: (selector) => selector === 'input[type="checkbox"]' ? checkboxes : []
    };

    uncheckAllCheckboxes(mockElement);
    assert.strictEqual(checkboxes[0].checked, false);
    assert.strictEqual(checkboxes[1].checked, false);

    // Should not throw for null
    uncheckAllCheckboxes(null);
});

test('formatPercentage', () => {
    assert.strictEqual(formatPercentage(12.34), '12.3%');
    assert.strictEqual(formatPercentage(12.34, 2), '12.34%');
    assert.strictEqual(formatPercentage(null), '0.0%');
    assert.strictEqual(formatPercentage(undefined), '0.0%');
    assert.strictEqual(formatPercentage('abc'), '0.0%');
});
