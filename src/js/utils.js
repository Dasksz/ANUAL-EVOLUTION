export function escapeHtml(unsafe) {
    if (unsafe == null) return '';
    return String(unsafe)
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
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
            if (btns[idx]) {
                btns[idx].setAttribute('aria-expanded', 'false');
            }
            anyClosed = true;
        }
    });
    return anyClosed;
}
