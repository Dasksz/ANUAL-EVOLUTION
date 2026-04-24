const matchHtmlRegExp = /["'&<>]/;
export function escapeHtml(unsafe) {
    if (unsafe == null) return '';
    const str = String(unsafe);
    if (!matchHtmlRegExp.test(str)) return str;

    // ⚡ Bolt Optimization: Single-pass iteration instead of multiple chained `.replace` calls
    let escaped = '';
    let lastIndex = 0;
    for (let i = 0; i < str.length; i++) {
        let match = '';
        switch (str.charCodeAt(i)) {
            case 38: match = '&amp;'; break; // &
            case 60: match = '&lt;'; break; // <
            case 62: match = '&gt;'; break; // >
            case 34: match = '&quot;'; break; // "
            case 39: match = '&#039;'; break; // '
            default: continue;
        }
        escaped += str.substring(lastIndex, i) + match;
        lastIndex = i + 1;
    }
    return escaped + str.substring(lastIndex);
}

const _numberFormatters = new Map();
export function formatNumber(num, decimals = 2) {
    if (num == null) return '--';
    const parsed = Number(num);
    if (isNaN(parsed)) return '--';

    let formatter = _numberFormatters.get(decimals);
    if (!formatter) {
        formatter = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
        _numberFormatters.set(decimals, formatter);
    }
    return formatter.format(parsed);
}

/**
 * Safely updates the paths of an SVG element without using innerHTML.
 * @param {SVGElement} svgElement - The SVG element to update.
 * @param {string[]} pathDataArray - An array of path 'd' attribute strings.
 */
export function updateSvgPaths(svgElement, pathDataArray) {
    if (!svgElement) return;
    let paths = svgElement.querySelectorAll('path');

    // Ensure we have enough path elements
    while (paths.length < pathDataArray.length) {
        const newPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        // Default attributes based on project style
        newPath.setAttribute('stroke-linecap', 'round');
        newPath.setAttribute('stroke-linejoin', 'round');
        newPath.setAttribute('stroke-width', '2');
        svgElement.appendChild(newPath);
        paths = svgElement.querySelectorAll('path');
    }

    pathDataArray.forEach((d, i) => {
        paths[i].setAttribute('d', d);
    });

    // Hide extra paths by clearing their 'd' attribute
    for (let i = pathDataArray.length; i < paths.length; i++) {
        paths[i].setAttribute('d', '');
    }
}

/**
 * Formats a value as BRL Currency.
 * Improves readability by encapsulating the lengthy toLocaleString call.
 */
let _currencyFormatter = null;
export function formatCurrency(value) {
    if (value == null || isNaN(Number(value))) return 'R$ 0,00';
    if (!_currencyFormatter) {
        _currencyFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
    }
    return _currencyFormatter.format(Number(value));
}

/**
 * Formats a weight value (in kg) to Tons (divided by 1000).
 * Improves readability by encapsulating the division and toLocaleString call.
 */
export function formatTons(weightInKg, decimals = 1) {
    if (weightInKg == null || isNaN(Number(weightInKg))) return '0,0 Ton';

    let formatter = _numberFormatters.get(decimals);
    if (!formatter) {
        formatter = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
        _numberFormatters.set(decimals, formatter);
    }
    return formatter.format(Number(weightInKg) / 1000) + ' Ton';
}

export const MONTHS_PT = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
export const MONTHS_PT_SHORT = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
export const MONTHS_PT_INITIALS = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];

/**
 * Shared SVG icons for tables and detailed views.
 * Extracted into a centralized object to prevent duplication across different modules
 * and to keep function scopes (like openDetalhadoModal) clean and readable.
 */
export const TABLE_ICONS = {
    vendedor: `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>`,
    filial: `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1v1H9V7zm5 0h1v1h-1V7zm-5 4h1v1H9v-1zm5 0h1v1h-1v-1zm-5 4h1v1H9v-1zm5 0h1v1h-1v-1z" /></svg>`,
    chart: `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>`,
    target: `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>`,
    share: `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1.5 inline text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" /></svg>`
};

/**
 * Formats a value as an Integer in pt-BR locale.
 * Improves readability by encapsulating Math.round and toLocaleString.
 */
let _integerFormatter = null;
export function formatInteger(value) {
    if (value == null || isNaN(Number(value))) return '0';
    if (!_integerFormatter) {
        _integerFormatter = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 });
    }
    return _integerFormatter.format(Math.round(Number(value)));
}

/**
 * Sets a loading spinner on a button. Replaces the innerHTML of the target element.
 * Helps reduce duplicated long SVG spinner strings.
 * @param {HTMLElement} target - The DOM element where the text and spinner will be injected. (Could be the button or a .btn-text span)
 * @param {HTMLElement} btn - The main button to disable.
 * @param {string} loadingText - Text to display while loading.
 * @param {string} extraClasses - Extra CSS classes for the spinner SVG (e.g. 'text-white' for solid colored auth buttons, or empty string for export buttons).
 * @returns {string} The original HTML string of the target.
 */
export function setElementLoading(target, btn, loadingText, extraClasses = '') {
    // Ensure loadingText is escaped to prevent DOM XSS
    if (!target || !btn) return '';
    const originalHtml = target.innerHTML;
    btn.disabled = true;
    target.innerHTML = `<svg class="animate-spin -ml-1 mr-2 h-4 w-4 inline-block ${escapeHtml(extraClasses).trim()}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>${escapeHtml(loadingText)}`;
    return originalHtml;
}

/**
 * Restores the element to its original inner HTML state and enables the button.
 * @param {HTMLElement} target - The element whose HTML should be restored.
 * @param {HTMLElement} btn - The button to re-enable.
 * @param {string} originalHtml - The original HTML state.
 */
export function restoreElementState(target, btn, originalHtml) {
    if (!target || !btn) return;
    target.innerHTML = originalHtml;
    btn.disabled = false;
}

/**
 * Handles clickaway events for dropdowns to close them when clicked outside.
 * Centralizes repetitive dropdown closing logic.
 * @param {Event} e - The click event.
 * @param {HTMLElement[]} dropdowns - Array of dropdown elements.
 * @param {HTMLElement[]} btns - Array of corresponding toggle buttons.
 * @returns {boolean} True if any dropdown was closed, false otherwise.
 */
export function handleDropdownsClickaway(e, dropdowns, btns) {
    let anyClosed = false;
    dropdowns.forEach((dd, idx) => {
        if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
            dd.classList.add('hidden');
            anyClosed = true;
        }
    });
    return anyClosed;
}

/**
 * Closes all absolute dropdown menus.
 * Centralizes the repetitive DOM query and loop logic for absolute dropdowns.
 */
export function closeAllDropdowns() {
    document.querySelectorAll('.absolute.z-\\[50\\], .absolute.z-\\[999\\]').forEach(el => {
        if (!el.classList.contains('hidden')) {
            el.classList.add('hidden');
        }
    });
}

/**
 * Unchecks all checkbox inputs within a given container element.
 * Centralizes repetitive DOM queries and state resets.
 * @param {HTMLElement} element - The container element (e.g. a dropdown).
 */
export function uncheckAllCheckboxes(element) {
    if (!element) return;
    element.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = false);
}
