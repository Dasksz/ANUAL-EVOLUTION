const matchHtmlRegExp = /["'&<>]/;
export function escapeHtml(unsafe) {
    if (unsafe == null) return '';
    const str = String(unsafe);
    if (!matchHtmlRegExp.test(str)) return str;

    // Performance Optimization: single-pass character iteration
    // instead of chained .replace() which creates multiple intermediate strings
    let html = '';
    let lastIndex = 0;

    for (let i = 0; i < str.length; i++) {
        let escaped;
        switch (str.charCodeAt(i)) {
            case 38: // &
                escaped = '&amp;';
                break;
            case 60: // <
                escaped = '&lt;';
                break;
            case 62: // >
                escaped = '&gt;';
                break;
            case 34: // "
                escaped = '&quot;';
                break;
            case 39: // '
                escaped = '&#039;';
                break;
            default:
                continue;
        }

        if (lastIndex !== i) {
            html += str.substring(lastIndex, i);
        }

        lastIndex = i + 1;
        html += escaped;
    }

    if (lastIndex !== str.length) {
        html += str.substring(lastIndex);
    }

    return html;
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

/**
 * Formats a value as a percentage string.
 * Improves readability by centralizing percentage formatting and removing repetitive string interpolations.
 */
export function formatPercentage(value, decimals = 1) {
    if (value == null || isNaN(Number(value))) return (0).toFixed(decimals) + '%';
    return Number(value).toFixed(decimals) + '%';
}

/**
 * Generates options HTML string for a Year dropdown.
 * Improves readability by centralizing the repetitive mapping and joining of year arrays,
 * and reducing duplicated `map().join('')` logic across `app.js`.
 * @param {string[]|number[]} years - The array of years to map.
 * @param {string} defaultLabel - The text label for the default/empty option.
 * @param {string} defaultValue - The value for the default/empty option.
 * @returns {string} The HTML string containing the option elements.
 */
export function generateYearOptionsHtml(years, defaultLabel = 'Todos', defaultValue = 'todos') {
    let html = '';
    if (defaultLabel !== '') {
        html += `<option value="${escapeHtml(defaultValue)}">${escapeHtml(defaultLabel)}</option>`;
    }
    html += years.map(a => `<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
    return html;
}

/**
 * Generates options HTML string for a Month dropdown.
 * Improves readability by centralizing the repetitive iteration over MONTHS_PT,
 * and reducing duplicated `map().join('')` logic across `app.js`.
 * @param {string} defaultLabel - The text label for the default/empty option.
 * @param {string} defaultValue - The value for the default/empty option.
 * @param {boolean} oneIndexedPadded - If true, month values are 01-12. If false, month values are 0-11.
 * @returns {string} The HTML string containing the option elements.
 */
export function generateMonthOptionsHtml(defaultLabel = 'Todos', defaultValue = '', oneIndexedPadded = false) {
    let html = '';
    if (defaultLabel !== '') {
        html += `<option value="${escapeHtml(defaultValue)}">${escapeHtml(defaultLabel)}</option>`;
    }
    html += MONTHS_PT.map((m, i) => {
        const val = oneIndexedPadded ? String(i + 1).padStart(2, '0') : i;
        return `<option value="${escapeHtml(val)}">${escapeHtml(m)}</option>`;
    }).join('');
    return html;
}

/**
 * Clears multiple arrays in place.
 * Centralizes repetitive array.length = 0 assignments.
 * @param {...Array} arrays - Arrays to be cleared.
 */
export function clearArrays(...arrays) {
    arrays.forEach(arr => {
        if (Array.isArray(arr)) {
            arr.length = 0;
        }
    });
}

export function debounce(func, wait = 300) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}


export function showToast(type, message, title = '') {
    const container = document.getElementById('toast-container');
    if (!container) {
        console.error('Toast container not found!');
        console.log(`[${type}] ${message}`);
        return;
    }

    const variants = {
        success: {
            class: 'toast-success',
            icon: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`,
            defaultTitle: 'Sucesso'
        },
        error: {
            class: 'toast-error',
            icon: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`,
            defaultTitle: 'Erro'
        },
        info: {
            class: 'toast-info',
            icon: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`,
            defaultTitle: 'Informação'
        },
        warning: {
            class: 'toast-warning',
            icon: `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>`,
            defaultTitle: 'Atenção'
        }
    };

    const variant = variants[type] || variants.info;
    const finalTitle = title || variant.defaultTitle;

    const toast = document.createElement('div');
    toast.className = `toast ${variant.class}`;
    const role = (type === 'error' || type === 'warning') ? 'alert' : 'status';
    const ariaLive = (type === 'error' || type === 'warning') ? 'assertive' : 'polite';
    toast.setAttribute('role', role);
    toast.setAttribute('aria-live', ariaLive);

    // 🧹 Tidy Optimization: Usado innerHTML literal para criar o toast substituindo o documento.createElement excessivo
    toast.innerHTML = `
        <div class="toast-icon">${variant.icon}</div>
        <div class="flex-1 min-w-0">
            <h4 class="toast-title">${escapeHtml(finalTitle)}</h4>
            <p class="toast-message">${escapeHtml(message)}</p>
        </div>
        <button class="toast-close-btn" aria-label="Fechar notificação">
            <svg class="w-4 h-4" aria-hidden="true" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
        </button>
    `;

    toast.querySelector('.toast-close-btn').onclick = function() {
        toast.classList.add('hiding');
        toast.addEventListener('animationend', () => toast.remove());
    };

    container.appendChild(toast);
};

/**
 * Resets date dropdowns to a specified year and month.
 * Checks if the year option exists before setting it.
 * Dispatches change events.
 *
 * @param {HTMLSelectElement} anoSelect - The year select element
 * @param {HTMLSelectElement} mesSelect - The month select element
 * @param {string} currentYear - The target year
 * @param {string} currentMonth - The target month
 * @param {string} defaultYear - The fallback year if target is not found (default 'todos')
 */
export function resetDateDropdowns(anoSelect, mesSelect, currentYear, currentMonth, defaultYear = 'todos') {
    if (anoSelect) {
        let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
        anoSelect.value = hasYear ? currentYear : defaultYear;
        anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
    }
    if (mesSelect) {
        mesSelect.value = currentMonth;
        mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
    }
}
