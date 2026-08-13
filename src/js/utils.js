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
        html += `<option class="bg-slate-800 text-slate-200" value="${escapeHtml(defaultValue)}">${escapeHtml(defaultLabel)}</option>`;
    }
    html += years.map(a => `<option class="bg-slate-800 text-slate-200" value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
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
        html += `<option class="bg-slate-800 text-slate-200" value="${escapeHtml(defaultValue)}">${escapeHtml(defaultLabel)}</option>`;
    }
    html += MONTHS_PT.map((m, i) => {
        const val = oneIndexedPadded ? String(i + 1).padStart(2, '0') : i;
        return `<option class="bg-slate-800 text-slate-200" value="${escapeHtml(val)}">${escapeHtml(m)}</option>`;
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
 * Resets year and month select dropdowns to current dates and dispatches change events.
 * Extracted from app.js to reduce repetition when clearing filters.
 * @param {HTMLElement} anoSelect - The year select element.
 * @param {HTMLElement} mesSelect - The month select element.
 * @param {string|number} currentYear - The current year value.
 * @param {string|number} currentMonth - The current month value.
 */
export function resetDateDropdowns(anoSelect, mesSelect, currentYear, currentMonth) {
    if (anoSelect) {
        let hasYear = Array.from(anoSelect.options).some(opt => opt.value === String(currentYear));
        anoSelect.value = hasYear ? String(currentYear) : 'todos';
        anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
    }
    if (mesSelect) {
        mesSelect.value = String(currentMonth);
        mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
    }
}

/**
 * Generates an HTML string for a table row indicating an empty state or error.
 * Extracted from app.js to reduce duplication of `<tr><td colspan="...">...</td></tr>` strings.
 * @param {number|string} colspan - The number of columns to span.
 * @param {string} message - The message to display.
 * @param {boolean} [isError=false] - Whether the message is an error (applies red text).
 * @param {string} [extraClasses=''] - Any extra CSS classes (e.g. for padding/text size).
 * @returns {string} The HTML string for the empty state row.
 */
export function renderTableEmptyState(colspan, message, isError = false, extraClasses = '') {
    const colorClass = isError ? 'text-red-500' : (extraClasses.includes('text-slate-') ? '' : 'text-slate-500');
    // Using string interpolation for performance, and escaping dynamic inputs
    return `<tr><td colspan="${escapeHtml(colspan)}" class="text-center ${colorClass} ${escapeHtml(extraClasses)}">${escapeHtml(message)}</td></tr>`;
}

/**
 * Safely updates a DOM element's textContent or style width.
 * Extracted from getBoxesDashboardData in app.js to be used globally, reducing repetition of document.getElementById checks.
 * @param {string} id - The ID of the DOM element to update.
 * @param {string|number} val - The value to set (text or width).
 * @param {boolean} [isStyle=false] - If true, updates style.width instead of textContent.
 */
export function updateEl(id, val, isStyle = false) {
    const el = document.getElementById(id);
    if (el) {
        if (isStyle) el.style.width = val;
        else el.textContent = val;
    }
}
        export function parseGoalsSvStructure(text) {
            console.log("[Parser] Iniciando parse...");
            const lines = text.replace(/[\r\n]+$/, '').split(/\r?\n/);
            if (lines.length === 0) return null;

            // 1. Detect Delimiter (Heuristic)
            const firstLine = lines[0];
            let delimiter = '\t';
            if (firstLine.includes('\t')) delimiter = '\t';
            else if (firstLine.includes(';')) delimiter = ';';
            else if (firstLine.includes(',') && lines.length > 1) delimiter = ',';
            // Fallback for space separated copy-paste if single line has spaces
            else if (firstLine.trim().split(/\s{2,}/).length > 1) delimiter = /\s{2,}/; // At least 2 spaces

            console.log("[Parser] Delimitador detectado:", delimiter);

            const rows = lines.map(line => {
                // If delimiter is regex, use split directly
                if (delimiter instanceof RegExp) return line.trim().split(delimiter);
                return line.split(delimiter);
            });

            console.log(`[Parser] Linhas encontradas: ${rows.length}`);

            // 2. Identify Header Rows and Construct ColMap
            const colMap = {};
            let dataStartRow = 0;

            if (rows.length >= 3) {
                // Standard logic: Rows 0, 1, 2
                const startRow = 0;

                const header0 = rows[startRow].map(h => h ? h.trim().toUpperCase() : '');
                const header1 = rows[startRow + 1].map(h => h ? h.trim().toUpperCase() : '');
                const header2 = rows[startRow + 2].map(h => h ? h.trim().toUpperCase() : '');

                console.log("[Parser] Header 0:", header0.join('|'));
                console.log("[Parser] Header 1:", header1.join('|'));
                console.log("[Parser] Header 2:", header2.join('|'));

                let currentCategory = null;
                let currentMetric = null;

                // Map Headers
                for (let i = 0; i < header0.length; i++) {
                    if (header0[i]) currentCategory = header0[i];
                    if (header1[i]) currentMetric = header1[i];
                    let subMetric = header2[i]; // Meta, Ajuste, etc.

                    if (currentCategory && subMetric) {
                        if (subMetric === 'AJ.' || subMetric === 'AJ') subMetric = 'AJUSTE';

                        let catKey = currentCategory;
                        // Normalize Category Names to IDs (Fuzzy Matching)
                        if (catKey.includes('NÃO EXTRUSADOS') || catKey.includes('NAO EXTRUSADOS')) catKey = '708';
                        else if (catKey.includes('EXTRUSADOS')) catKey = '707';
                        else if (catKey.includes('TORCIDA')) catKey = '752';
                        else if (catKey.includes('TODDYNHO')) catKey = '1119_TODDYNHO';
                        else if (catKey.includes('TODDY')) catKey = '1119_TODDY';
                        else if (catKey.includes('QUAKER') || catKey.includes('KEROCOCO')) catKey = '1119_QUAKER_KEROCOCO';
                        else if (catKey === 'KG ELMA') catKey = 'tonelada_elma';
                        else if (catKey === 'KG FOODS') catKey = 'tonelada_foods';
                        else if (catKey === 'TOTAL ELMA') catKey = 'total_elma';
                        else if (catKey === 'TOTAL FOODS') catKey = 'total_foods';
                        else if (catKey === 'MIX SALTY') catKey = 'mix_salty';
                        else if (catKey === 'MIX FOODS') catKey = 'mix_foods';
                        else if (catKey === 'PEPSICO_ALL_POS' || catKey === 'PEPSICO_ALL' || catKey === 'GERAL') catKey = 'pepsico_all';

                        let metricKey = 'OTHER';
                        if (currentMetric === 'FATURAMENTO' || currentMetric === 'MÉDIA TRIM.') metricKey = 'FAT';
                        else if (currentMetric === 'POSITIVAÇÃO' || currentMetric === 'POSITIVACAO' || currentMetric.includes('POSITIVA')) metricKey = 'POS';
                        else if (currentMetric === 'TONELADA' || currentMetric === 'META KG') metricKey = 'VOL';
                        else if (currentMetric === 'META MIX' || currentMetric === 'MIX' || currentMetric === 'QTD') metricKey = 'MIX';

                        const key = `${catKey}_${metricKey}_${subMetric}`;
                        colMap[key] = i;
                    }
                }

                dataStartRow = startRow + 3;
            } else {
                console.warn("[Parser] Menos de 3 linhas. Tentando modo simplificado...");
                // Simplified Mode: Hardcoded Column Map based on Standard Export
                // Columns structure matches exportGoalsSvXLSX

                let colIdx = 2; // Start after Vendedor (Index 2)
                const addKeys = (cat, keys) => {
                    keys.forEach((k, i) => {
                        if (k) colMap[`${cat}_${k}`] = colIdx + i;
                    });
                    colIdx += keys.length;
                };

                // 1. TOTAL ELMA (Standard Agg)
                addKeys('total_elma', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 2. EXTRUSADOS (707)
                addKeys('707', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 3. NÃO EXTRUSADOS (708)
                addKeys('708', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 4. TORCIDA (752)
                addKeys('752', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 5. KG ELMA (tonnage)
                addKeys('tonelada_elma', [null, 'VOL_VOLUME', 'VOL_AJUSTE']);
                // 6. MIX SALTY (mix)
                addKeys('mix_salty', [null, 'MIX_META', 'MIX_AJUSTE']);

                // 7. TOTAL FOODS (Standard Agg)
                addKeys('total_foods', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 8. TODDYNHO (1119_TODDYNHO)
                addKeys('1119_TODDYNHO', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 9. TODDY (1119_TODDY)
                addKeys('1119_TODDY', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 10. QUAKER/KEROCOCO
                addKeys('1119_QUAKER_KEROCOCO', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 11. KG FOODS (tonnage)
                addKeys('tonelada_foods', [null, 'VOL_VOLUME', 'VOL_AJUSTE']);
                // 12. MIX FOODS (mix)
                addKeys('mix_foods', [null, 'MIX_META', 'MIX_AJUSTE']);

                // 13. GERAL (pepsico_all)
                addKeys('pepsico_all', [null, 'FAT_META', 'VOL_META', 'POS_META']);

                // 14. PEDEV
                colIdx += 1;

                dataStartRow = 0; // Parse all rows
            }

            const updates = [];
            const processedSellers = new Set();

            const parseImportValue = (rawStr) => {
                if (!rawStr) return NaN;
                let clean = String(rawStr).trim().toUpperCase().replace(/[^0-9,.-]/g, '');
                if (!clean) return NaN;

                const dotIdx = clean.lastIndexOf('.');
                const commaIdx = clean.lastIndexOf(',');
                
                if (dotIdx > -1 && commaIdx > -1) {
                    if (dotIdx > commaIdx) clean = clean.replace(/,/g, ''); 
                    else clean = clean.replace(/\./g, '').replace(',', '.');
                } else if (commaIdx > -1) {
                    // Has comma, no dot. Assume comma is decimal in Brazil
                    // However, if the user exported raw CSV without decimals for thousands (e.g. 1,234 meaning 1234)
                    // it is highly ambiguous. In this system, we mostly use Brazilian format (1,234 is 1.234)
                    // We remove the old /,\d{3}$/ check because volume is often 3 decimals (e.g., 2,600 kg = 2.6).
                    clean = clean.replace(',', '.');
                } else if (dotIdx > -1) {
                    // Has dot, no comma.
                    // If it has multiple dots, they are definitely thousands separators.
                    if (clean.split('.').length > 2) {
                        clean = clean.replace(/\./g, '');
                    } else {
                        // Single dot. In raw Excel data or standard floats (e.g., 1359.041), this is a decimal point.
                        // We DO NOT remove it. Removing it would inflate the value 1000x for volume.
                    }
                }
                return parseFloat(clean);
            };
            // Identify Vendor Column Index (Name)
            // Usually Index 1 (Code, Name, ...)
            // We scan first few rows to find valid seller names
            let nameColIndex = 1; 
            // Basic Heuristic: If col 0 looks like a name and col 1 is number, maybe it's col 0.
            // But standard template is [Code, Name, ...]. We stick to 1 for now or 0 if 1 is empty.

            for (let i = dataStartRow; i < rows.length; i++) {
                const row = rows[i];
                if (!row || row.length < 2) continue;

                // Try col 1 for name, fallback to col 0 if col 1 is empty/numeric
                let sellerName = row[1];
                let sellerCodeCandidate = row[0]; // Candidate for Code

                if (!sellerName || !isNaN(parseImportValue(sellerName))) {
                     // If col 1 is number, maybe col 0 is name? Or col 2?
                     // Standard: Col 0 = Code, Col 1 = Name.
                     if (row[0] && isNaN(parseImportValue(row[0]))) {
                         sellerName = row[0];
                         sellerCodeCandidate = null; // Name is in Col 0
                     }
                }

                if (!sellerName) continue; 
                
                // --- ENHANCED FILTER: Ignore Supervisors, Aggregates, and BALCAO ---
                const upperName = sellerName.normalize('NFD').replace(/[\u0300-\u036f]/g, "").toUpperCase().trim();
                
                // 1. Explicit Blocklist
                if (upperName === 'BALCAO' || upperName === 'BALCÃO' || 
                    upperName.includes('TOTAL') || upperName.includes('SUPERVISOR') || upperName.includes('GERAL') ||
                    upperName === 'VENDEDOR' || upperName === 'NOME' || upperName === 'CODIGO' || upperName === 'CÓDIGO') {
                    continue;
                }

                // --- RESOLUTION LOGIC: Normalize Seller Name to System Canonical Name ---
                let canonicalName = null;

                // 1. Try by Code (Col 0)
                if (sellerCodeCandidate) {
                    const parsedCode = parseImportValue(sellerCodeCandidate);
                    if (!isNaN(parsedCode)) {
                        const codeStr = String(parsedCode);
                        if (optimizedData.rcaNameByCode.has(codeStr)) {
                            canonicalName = optimizedData.rcaNameByCode.get(codeStr);
                        }
                    }
                }

                // 2. Try by Name (Fuzzy/Case-Insensitive)
                if (!canonicalName) {
                    // Iterate existing system names to find case-insensitive match
                    for (const [sysName, sysCode] of optimizedData.rcaCodeByName) {
                         const sysUpper = sysName.normalize('NFD').replace(/[\u0300-\u036f]/g, "").toUpperCase().trim();
                         if (sysUpper === upperName) {
                             canonicalName = sysName;
                             break;
                         }
                    }
                }

                const finalSellerName = canonicalName || sellerName;

                // 2. Dynamic Supervisor Check
                // If the name is a known Supervisor (key in rcasBySupervisor), ignore it.
                // Assuming supervisors are not also sellers in this context (or we only want leaf sellers).
                if (optimizedData.rcasBySupervisor.has(finalSellerName) || optimizedData.rcasBySupervisor.has(finalSellerName.toUpperCase())) {
                    continue;
                }
                // ------------------------------------------------

                if (processedSellers.has(finalSellerName)) continue;
                processedSellers.add(finalSellerName);

                // Helper to get value with priority: Adjust > Meta
                const getPriorityValue = (cat, metric) => {
                    // 1. Try AJUSTE
                    let idx = colMap[`${cat}_${metric}_AJUSTE`];
                    if (idx !== undefined && row[idx]) {
                        const val = parseImportValue(row[idx]);
                        if (!isNaN(val)) return val;
                    }
                    // 2. Try META
                    idx = colMap[`${cat}_${metric}_META`];
                    if (idx !== undefined && row[idx]) {
                        const val = parseImportValue(row[idx]);
                        if (!isNaN(val)) return val;
                    }
                    return NaN;
                };

                // 1. Revenue
                const revCats = ['707', '708', '752', '1119_TODDYNHO', '1119_TODDY', '1119_QUAKER_KEROCOCO'];
                revCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'FAT');
                    if (!isNaN(val)) updates.push({ type: 'rev', seller: sellerName, category: cat, val: val });
                });

                // 2. Volume
                // Metas de Volume são importadas pelos Totais (KG ELMA / KG FOODS) e distribuídas automaticamente
                const volCats = ['tonelada_elma', 'tonelada_foods'];
                volCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'VOL');
                    if (!isNaN(val)) updates.push({ type: 'vol', seller: sellerName, category: cat, val: val });
                });

                // 3. Positivation
                const posCats = ['pepsico_all', 'total_elma', 'total_foods', '707', '708', '752', '1119_TODDYNHO', '1119_TODDY', '1119_QUAKER_KEROCOCO'];
                posCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'POS');
                    if (!isNaN(val)) updates.push({ type: 'pos', seller: sellerName, category: cat, val: Math.round(val) });
                });

                // 4. Mix
                const mixCats = ['mix_salty', 'mix_foods'];
                mixCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'MIX');
                    if (!isNaN(val)) updates.push({ type: 'mix', seller: sellerName, category: cat, val: Math.round(val) });
                });
            }
            return updates;
        }
// Mock fallback for optimizedData if missing since legacy parser relies on it
if (typeof window.optimizedData === 'undefined') {
    window.optimizedData = { rcasBySupervisor: new Map() };
}
