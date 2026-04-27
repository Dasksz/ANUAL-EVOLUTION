
let estrelasDetailedData = [];
let estrelasQtdMarcas = 0;

// Modal functions

/**
 * Creates a table row for the detailed modal safely using DOM API
 * to prevent XSS and improve performance.
 * @param {Object} row - The data row object
 * @param {number} index - The index for alternating row colors
 * @param {number|string} realizado - The realized amount
 * @param {string} realizedUnit - The unit string for realized amount
 * @param {number|string} meta - The target amount
 * @param {string} metaUnit - The unit string for target amount
 * @param {number|string} share - The share percentage
 * @param {string} shareColorClass - The color class for the share text
 * @returns {string} The constructed HTML string for the table row
 */
function createDetalhadoRow(row, index, realizado, realizedUnit, meta, metaUnit, share, shareColorClass) {
    const bgClass = index % 2 === 0 ? 'bg-transparent' : 'bg-white/[0.02]';
    const realizedUnitHtml = realizedUnit ? `<span class="text-xs text-slate-400">${escapeHtml(realizedUnit)}</span>` : '';
    const metaUnitHtml = metaUnit ? `<span class="text-xs">${escapeHtml(metaUnit)}</span>` : '';

    // ⚡ Bolt Optimization: Return a formatted HTML string instead of using document.createElement for every cell
    return `
        <tr class="border-b border-white/5 hover:bg-white/5 transition-colors ${bgClass}">
            <td class="py-3 px-4 whitespace-nowrap text-slate-200">${escapeHtml(row.vendedor_nome || 'N/D')}</td>
            <td class="py-3 px-4 whitespace-nowrap">
                <span class="px-2 py-1 rounded bg-slate-800 text-slate-300 text-xs border border-slate-700">${escapeHtml(row.filial || 'N/D')}</span>
            </td>
            <td class="py-3 px-4 text-right font-medium text-white">${escapeHtml(realizado)}${realizedUnit ? ' ' : ''}${realizedUnitHtml}</td>
            <td class="py-3 px-4 text-right text-slate-400">${escapeHtml(meta)}${metaUnit ? ' ' : ''}${metaUnitHtml}</td>
            <td class="py-3 px-4 text-right font-bold ${escapeHtml(shareColorClass)}">${escapeHtml(share)}%</td>
        </tr>
    `;
}

window.openDetalhadoModal = function(type) {
    const modal = document.getElementById('modal-resultado-detalhado');
    const title = document.getElementById('modal-detalhado-title');
    const subtitle = document.getElementById('modal-detalhado-subtitle');
    const thead = document.getElementById('modal-detalhado-thead');
    const tbody = document.getElementById('modal-detalhado-tbody');
    
    // Reset contents
    thead.textContent = '';
    tbody.textContent = '';
    subtitle.classList.add('hidden');
    
    let totalRealizado = 0;

    if (!estrelasDetailedData || estrelasDetailedData.length === 0) {
        title.textContent = type === 'sellout' ? 'Resultado Detalhado - Sellout' : (type === 'positivacao' ? 'Resultado Detalhado - Positivação' : 'Resultado Detalhado - Aceleradores');
        thead.textContent = '';
        tbody.innerHTML = `
            <tr>
                <td class="py-12 px-4 text-center text-slate-400" colspan="100%">
                    <div class="flex flex-col items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mb-3 text-slate-500 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                        </svg>
                        <span class="text-base font-medium text-slate-300">Nenhum dado encontrado</span>
                        <span class="text-sm mt-1">Ajuste os filtros ou aguarde a sincronização.</span>
                    </div>
                </td>
            </tr>`;
        modal.classList.remove('hidden');
        return;
    }

    if (type === 'sellout') {
        title.innerHTML = `<span class="flex items-center text-indigo-400">${TABLE_ICONS.chart} Resultado Detalhado - Sellout</span>`;
        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.target}Meta Salty</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.chart}Realizado Salty</th>
            <th class="py-3 px-4 text-right bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.target}Meta Foods</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-indigo-500/10 text-indigo-200">${TABLE_ICONS.chart}Realizado Foods</th>
        `;
        
        const sortedDataSellout = [...estrelasDetailedData].sort((a, b) => {
            const valA = (a.sellout_salty || 0) + (a.sellout_foods || 0);
            const valB = (b.sellout_salty || 0) + (b.sellout_foods || 0);
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataSellout.map((row, index) => {
            const metaSalty = (row.meta_salty || 0).toFixed(2);
            const realizadoSalty = ((row.sellout_salty || 0) / 1000.0).toFixed(2);
            const metaFoods = (row.meta_foods || 0).toFixed(2);
            const realizadoFoods = ((row.sellout_foods || 0) / 1000.0).toFixed(2);
            
            const bgClass = index % 2 === 0 ? 'bg-transparent' : 'bg-white/[0.02]';
            return `
                <tr class="hover:bg-white/5 transition-colors border-b border-white/5 ${bgClass}">
                    <td class="py-3 px-4 text-slate-300 font-medium">
                        <div class="flex items-center">
                            <span class="w-6 h-6 rounded-full bg-indigo-500/20 text-indigo-400 flex items-center justify-center text-xs mr-3 shrink-0">${index + 1}</span>
                            <span class="truncate max-w-[200px]" title="${escapeHtml(row.vendedor_nome)}">${escapeHtml(row.vendedor_nome)}</span>
                        </div>
                    </td>
                    <td class="py-3 px-4 text-slate-400 font-mono text-sm">${escapeHtml(row.filial)}</td>
                    <td class="py-3 px-4 text-right font-medium text-slate-400">${escapeHtml(metaSalty)} tons</td>
                    <td class="py-3 px-4 text-right font-bold text-white">${escapeHtml(realizadoSalty)} tons</td>
                    <td class="py-3 px-4 text-right font-medium text-slate-400">${escapeHtml(metaFoods)} tons</td>
                    <td class="py-3 px-4 text-right font-bold text-white">${escapeHtml(realizadoFoods)} tons</td>
                </tr>
            `;
        });
        tbody.innerHTML = htmlArray.join('');
        
    } else if (type === 'positivacao') {
        title.innerHTML = `<span class="flex items-center text-emerald-400">${TABLE_ICONS.chart} Resultado Detalhado - Positivação</span>`;
        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.chart}Realizado</th>
            <th class="py-3 px-4 text-right bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.target}Meta</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-emerald-500/10 text-emerald-200">${TABLE_ICONS.share}% Share</th>
        `;
        
        totalRealizado = estrelasDetailedData.reduce((acc, curr) => acc + ((curr.pos_salty || 0) + (curr.pos_foods || 0)), 0);
        
        const sortedDataPos = [...estrelasDetailedData].sort((a, b) => {
            const valA = (a.pos_salty || 0) + (a.pos_foods || 0);
            const valB = (b.pos_salty || 0) + (b.pos_foods || 0);
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataPos.map((row, index) => {
            const realizado = (row.pos_salty || 0) + (row.pos_foods || 0);
            const meta = row.meta_pos || 0;
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;
            return createDetalhadoRow(row, index, realizado, 'PDV(s)', meta, 'PDV(s)', share, 'text-emerald-400');
        });
        tbody.innerHTML = htmlArray.join('');
        
    } else if (type === 'aceleradores') {
        title.innerHTML = `<span class="flex items-center text-amber-400">${TABLE_ICONS.target} Resultado Detalhado - Aceleradores</span>`;
        subtitle.textContent = `Total de Marcas Cadastradas: ${estrelasQtdMarcas}`;
        subtitle.classList.remove('hidden');
        
        thead.innerHTML = `
            <th class="py-3 px-4 text-left rounded-tl-lg bg-amber-500/10 text-amber-200">${TABLE_ICONS.vendedor}Vendedor</th>
            <th class="py-3 px-4 text-left bg-amber-500/10 text-amber-200">${TABLE_ICONS.filial}Filial</th>
            <th class="py-3 px-4 text-right bg-amber-500/10 text-amber-200">${TABLE_ICONS.chart}Aceleradores (Realizado)</th>
            <th class="py-3 px-4 text-right bg-amber-500/10 text-amber-200">${TABLE_ICONS.target}Meta (50% da Pos.)</th>
            <th class="py-3 px-4 text-right rounded-tr-lg bg-amber-500/10 text-amber-200">${TABLE_ICONS.share}% Share</th>
        `;
        
        totalRealizado = estrelasDetailedData.reduce((acc, curr) => acc + (curr.acel_realizado || 0), 0);
        
        const sortedDataAcel = [...estrelasDetailedData].sort((a, b) => {
            const valA = a.acel_realizado || 0;
            const valB = b.acel_realizado || 0;
            return valB - valA;
        });

        // ⚡ Bolt Optimization: Replace document.createElement with innerHTML array join
        const htmlArray = sortedDataAcel.map((row, index) => {
            const realizado = row.acel_realizado || 0;
            const metaPositivação = row.meta_pos || 0;
            const meta = Math.ceil(metaPositivação * 0.5); 
            const share = totalRealizado > 0 ? ((realizado / totalRealizado) * 100).toFixed(2) : 0;
            return createDetalhadoRow(row, index, realizado, null, meta, null, share, 'text-amber-400');
        });
        tbody.innerHTML = htmlArray.join('');
    }

    modal.classList.remove('hidden');
};

window.closeDetalhadoModal = function() {
    const modal = document.getElementById('modal-resultado-detalhado');
    modal.classList.add('hidden');
};


import supabase from './supabase.js?v=3';
import {  formatNumber, escapeHtml, formatCurrency, formatTons, formatInteger, MONTHS_PT, MONTHS_PT_SHORT, MONTHS_PT_INITIALS, setElementLoading, restoreElementState , handleDropdownsClickaway, closeAllDropdowns, TABLE_ICONS, updateSvgPaths, uncheckAllCheckboxes } from './utils.js';


function getDefaultFilterDates(lastSalesDate) {
    let currentYear = '';
    let currentMonth = '';
    if (typeof lastSalesDate !== 'undefined' && lastSalesDate) {
        const lastDate = new Date(lastSalesDate + 'T12:00:00');
        currentYear = String(lastDate.getFullYear());
        currentMonth = String(lastDate.getMonth() + 1).padStart(2, '0');
    } else {
        const now = new Date();
        currentYear = String(now.getFullYear());
        currentMonth = String(now.getMonth() + 1).padStart(2, '0');
    }
    return { currentYear, currentMonth };
}

// --- Logging System ---
const AppLog = {
    log: (...args) => console.log(...args),
    warn: (...args) => console.warn(...args),
    error: (...args) => console.error(...args)
};

// --- Toast Notification System ---
window.showToast = function(type, message, title = '') {
    const container = document.getElementById('toast-container');
    if (!container) {
        AppLog.error('Toast container not found!');
        AppLog.log(`[${type}] ${message}`);
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
    const iconDiv = document.createElement('div');
    iconDiv.className = 'toast-icon';
    iconDiv.innerHTML = variant.icon;

    const contentDiv = document.createElement('div');
    contentDiv.className = 'flex-1 min-w-0';

    const titleEl = document.createElement('h4');
    titleEl.className = 'toast-title';
    titleEl.textContent = title;

    const msgEl = document.createElement('p');
    msgEl.className = 'toast-message';
    msgEl.textContent = message;

    contentDiv.appendChild(titleEl);
    contentDiv.appendChild(msgEl);

    const closeBtn = document.createElement('button');
    closeBtn.className = 'toast-close-btn';
    closeBtn.setAttribute('aria-label', 'Fechar notificação');
    closeBtn.innerHTML = '<svg class="w-4 h-4" aria-hidden="true" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>';
    closeBtn.onclick = function() {
        toast.classList.add('hiding');
        toast.addEventListener('animationend', () => toast.remove());
    };

    toast.appendChild(iconDiv);
    toast.appendChild(contentDiv);
    toast.appendChild(closeBtn);

    // Use textContent to prevent XSS
    toast.querySelector('.toast-title').textContent = finalTitle;
    toast.querySelector('.toast-message').textContent = message;

    container.appendChild(toast);
};

document.addEventListener('DOMContentLoaded', () => {
    AppLog.log("App Version: 2.0 (Cache Refresh Split)");
    let isMainDashboardInitialized = false;
    let isInnovationsInitialized = false;
    let isLojaPerfeitaInitialized = false;
    let isEstrelasInitialized = false;
let lpSelectedFiliais = [];
let lpSelectedSupervisors = [];
let lpSelectedVendedores = [];
let lpSelectedRedes = [];

let lpSelectedCidades = [];

let estrelasSelectedFiliais = [];
let estrelasSelectedCidades = [];
let estrelasSelectedSupervisors = [];
let estrelasSelectedVendedores = [];
let estrelasSelectedFornecedores = [];
let estrelasSelectedTiposVenda = [];
let estrelasSelectedRedes = [];
let estrelasSelectedCategorias = [];

    // --- GLOBAL NAVIGATION HISTORY ---
    let currentActiveView = 'dashboard';
    let viewHistory = [];

    function setupGlobalEsc() {
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                // Priority 1: Check Open Modals
                const openModal = document.querySelector('.fixed.inset-0:not(.hidden)');
                if (openModal) {
                    // Try to click the close button if it exists
                    const closeBtn = openModal.querySelector('button[id$="close-btn"], button[id^="close-"]');
                    if (closeBtn) {
                        closeBtn.click();
                    } else {
                        openModal.classList.add('hidden');
                    }
                    return;
                }

                // Priority 2: View Navigation
                if (viewHistory.length > 0) {
                    const prevView = viewHistory.pop();
                    renderView(prevView, { skipHistory: true });
                }
            }
        });
    }
    setupGlobalEsc();

    // --- Auth & Navigation Elements ---
    const loginView = document.getElementById('login-view');
    const appLayout = document.getElementById('app-layout');
    const googleLoginBtn = document.getElementById('google-login-btn');
    const loginError = document.getElementById('login-error');
    const logoutBtn = document.getElementById('logout-btn');
    const logoutBtnPendente = document.getElementById('logout-btn-pendente');

    // Auth Views
    const loginFormSignin = document.getElementById('view-login');
    const loginFormSignup = document.getElementById('view-signup');
    const loginFormForgot = document.getElementById('view-forgot');

    // Navigation links within Auth
    const linkSignup = document.getElementById('link-signup');
    const linkForgot = document.getElementById('link-forgot');
    const linkLoginFromSignup = document.getElementById('link-login-from-signup');
    const linkLoginFromForgot = document.getElementById('link-login-from-forgot');

    // Forms
    const formSignin = document.getElementById('loginForm');
    const formSignup = document.getElementById('signupForm');
    const formForgot = document.getElementById('forgotForm');

    // Load saved email if any
    const savedEmail = localStorage.getItem('prime_saved_email');
    if (savedEmail) {
        const emailInput = document.getElementById('email');
        const rememberMe = document.getElementById('remember-me');
        if (emailInput) emailInput.value = savedEmail;
        if (rememberMe) rememberMe.checked = true;
    }

    // Input toggles
    const btnTogglePasswordSignin = document.getElementById('togglePassword');
    const inputPasswordSignin = document.getElementById('password');
    const eyeIcon = document.getElementById('eyeIcon');

    const btnTogglePasswordSignup = document.getElementById('togglePasswordSignup');
    const inputPasswordSignup = document.getElementById('signup-password');
    const eyeIconSignup = document.getElementById('eyeIconSignup');

    // View Switching Logic
    const switchAuthView = (viewToShow) => {
        [loginFormSignin, loginFormSignup, loginFormForgot].forEach(el => {
            if (el) {
                el.classList.add('hidden');
                el.classList.remove('opacity-100', 'scale-100');
                el.classList.add('opacity-0', 'scale-95');
            }
        });

        if (viewToShow) {
            viewToShow.classList.remove('hidden');
            // Small delay to allow display block to apply before animating opacity
            setTimeout(() => {
                viewToShow.classList.remove('opacity-0', 'scale-95');
                viewToShow.classList.add('opacity-100', 'scale-100');
            }, 10);
        }
    };

    if (linkSignup) linkSignup.addEventListener('click', (e) => { e.preventDefault(); switchAuthView(loginFormSignup); });
    if (linkForgot) linkForgot.addEventListener('click', (e) => { e.preventDefault(); switchAuthView(loginFormForgot); });
    if (linkLoginFromSignup) linkLoginFromSignup.addEventListener('click', (e) => { e.preventDefault(); switchAuthView(loginFormSignin); });
    if (linkLoginFromForgot) linkLoginFromForgot.addEventListener('click', (e) => { e.preventDefault(); switchAuthView(loginFormSignin); });

    // New Top Navbar Elements
    const topNavbar = document.getElementById('top-navbar');
    const navDashboardBtn = document.getElementById('nav-dashboard');
    const navCityAnalysisBtn = document.getElementById('nav-city-analysis');
    const navBoxesBtn = document.getElementById('nav-boxes-btn');
    const navBranchBtn = document.getElementById('nav-branch-btn');
    const navUploaderBtn = document.getElementById('nav-uploader');
    const navInnovationsBtn = document.getElementById('nav-innovations-btn');
    const navLojaPerfeitaBtn = document.getElementById('nav-loja-perfeita-btn');
    const navEstrelasBtn = document.getElementById('nav-estrelas-btn');
    const navAgendaBtn = document.getElementById('nav-agenda-btn');
    // Export UI Logic
    const exportDropdown = document.getElementById('export-dropdown');
    let currentActiveNavId = 'nav-dashboard'; // keep track

    function positionExportDropdown(targetEl) {
        if (!exportDropdown || !targetEl) return;
        const rect = targetEl.getBoundingClientRect();
        exportDropdown.style.left = `${rect.left}px`;
        exportDropdown.style.top = `${rect.bottom + 8}px`; // 8px spacing
    }

    function toggleExportDropdown(targetEl) {
        if (!exportDropdown) return;
        if (exportDropdown.classList.contains('hidden')) {
            positionExportDropdown(targetEl);
            exportDropdown.classList.remove('hidden');
        } else {
            exportDropdown.classList.add('hidden');
        }
    }

    // Global click listener to close dropdown
    document.addEventListener('click', (e) => {
        if (!exportDropdown) return;
        const isClickInsideDropdown = exportDropdown.contains(e.target);
        const isClickOnActiveNav = e.target.closest('.nav-link.active');
        
        if (!isClickInsideDropdown && !isClickOnActiveNav && !exportDropdown.classList.contains('hidden')) {
            exportDropdown.classList.add('hidden');
        }
    });

    // Handle Window Resize to keep dropdown positioned correctly or hide it


    function getActiveExportView() {
        let activeView = null;
        let viewName = 'Export';
        const views = [
            { id: 'main-dashboard-view', navId: 'nav-dashboard', name: 'Visao Geral' },
            { id: 'city-view', navId: 'nav-city-analysis', name: 'Share' },
            { id: 'boxes-view', navId: 'nav-boxes-btn', name: 'Cobertura' },
            { id: 'branch-view', navId: 'nav-branch-btn', name: 'Filiais' },
            { id: 'comparison-view', navId: 'nav-comparativo-btn', name: 'Comparativo' },
            { id: 'innovations-month-view', navId: 'nav-innovations-btn', name: 'Inovacoes' },
            { id: 'loja-perfeita-view', navId: 'nav-loja-perfeita-btn', name: 'Loja Perfeita' },
            { id: 'estrelas-view', navId: 'nav-estrelas-btn', name: 'Estrelas' },
            { id: 'agenda-view', navId: 'nav-agenda-btn', name: 'Agenda' }
        ];

        for (const view of views) {
            const navEl = document.getElementById(view.navId);
            const viewEl = document.getElementById(view.id);
            if (navEl && navEl.classList.contains('active') && viewEl && !viewEl.classList.contains('hidden')) {
                activeView = viewEl;
                viewName = view.name;
                break;
            }
        }
        return { activeView, viewName };
    }

    // --- EXPORT EXCEL LOGIC ---
    const exportExcelBtn = document.getElementById('export-excel-btn');
    if (exportExcelBtn) {
        exportExcelBtn.addEventListener('click', () => {
            if (exportDropdown) exportDropdown.classList.add('hidden');
            
            const { activeView, viewName } = getActiveExportView();

            if (!activeView) {
                alert('Nenhuma visualização ativa encontrada para exportar.');
                return;
            }

            // Find all visible tables
            const tables = activeView.querySelectorAll('table:not(.hidden)');
            if (tables.length === 0) {
                alert('Nenhuma tabela encontrada na tela atual para exportar ao Excel.');
                return;
            }

            // Show loading state
            const originalHtml = setElementLoading(exportExcelBtn, exportExcelBtn, ' Gerando...');

            try {
                // Initialize a new workbook
                const wb = XLSX.utils.book_new();

                let sheetCounter = 1;
                tables.forEach((table, index) => {
                    // Filter out hidden rows entirely so they aren't parsed
                    const clonedTable = table.cloneNode(true);
                    const hiddenRows = clonedTable.querySelectorAll('.hidden, [style*="display: none"]');
                    hiddenRows.forEach(row => row.parentNode.removeChild(row));
                    
                    // Sanitize text if there are icons or complex formatting
                    const thTdElements = clonedTable.querySelectorAll('th, td');
                    thTdElements.forEach(cell => {
                        // Extract plain text to avoid extracting HTML attributes
                        // ⚡ Bolt Optimization: Use textContent instead of innerText to prevent expensive layout thrashing in cloned nodes
                        const text = cell.textContent;
                        // For numbers with R$ or formatting, excel might prefer strings that look like numbers
                        cell.textContent = text.trim();
                    });

                    // Generate worksheet
                    const ws = XLSX.utils.table_to_sheet(clonedTable, { raw: true });
                    
                    // Name the sheet
                    let sheetName = `Tabela ${sheetCounter}`;
                    // Attempt to find a title above the table
                    const prevElement = table.previousElementSibling;
                    if (prevElement && prevElement.tagName.match(/^H[1-6]$/i) && prevElement.textContent) {
                         sheetName = prevElement.textContent.substring(0, 30).trim(); // Max 31 chars for Excel sheet name
                    } else if (table.id) {
                         sheetName = table.id.replace(/[-_]/g, ' ').substring(0, 30);
                    }
                    
                    // Ensure unique sheet name
                    let baseName = sheetName;
                    let dupCounter = 1;
                    while (wb.SheetNames.includes(sheetName)) {
                        sheetName = `${baseName.substring(0, 25)} (${dupCounter})`;
                        dupCounter++;
                    }

                    XLSX.utils.book_append_sheet(wb, ws, sheetName);
                    sheetCounter++;
                });

                // Write file
                XLSX.writeFile(wb, `${viewName}_${new Date().toISOString().split('T')[0]}.xlsx`);

            } catch (err) {
                AppLog.error("Erro ao gerar Excel:", err);
                alert("Ocorreu um erro ao gerar o Excel. Tente novamente.");
            } finally {
                restoreElementState(exportExcelBtn, exportExcelBtn, originalHtml);
            }
        });
    }


    // --- EXPORT PDF LOGIC ---
    const exportPdfBtn = document.getElementById('export-pdf-btn');
    if (exportPdfBtn) {
        exportPdfBtn.addEventListener('click', async () => {
            // Hide dropdown
            if (exportDropdown) exportDropdown.classList.add('hidden');
            
            // Find currently active view
            const { activeView } = getActiveExportView();

            if (!activeView) {
                alert('Nenhuma visualização ativa encontrada para exportar.');
                return;
            }

            // Show loading state on button
            const originalHtml = setElementLoading(exportPdfBtn, exportPdfBtn, ' Gerando...');

            let headerEl = null;
            try {
                // Obter título da view ativa
                let viewTitle = 'Dashboard de Vendas';
                const activeNav = document.querySelector('.nav-link.active');
                if (activeNav) {
                    // Remover ícones ou texto extra do botão de nav se houver
                    viewTitle = activeNav.textContent.trim();
                }
                
                // Criar cabeçalho customizado para o PDF
                const currentDate = new Date().toLocaleString('pt-BR');
                headerEl = document.createElement('div');
                headerEl.className = 'pdf-header-export mb-6 pb-4 border-b border-white/10 flex justify-between items-center';
                headerEl.innerHTML = `
                    <div>
                        <h1 class="text-2xl font-bold text-white">${escapeHtml(viewTitle)}</h1>
                        <p class="text-sm text-slate-400">Dados obtidos via banco de dados</p>
                    </div>
                    <div class="text-right">
                        <p class="text-sm text-slate-300 font-medium">PRIME | Distribuição</p>
                        <p class="text-xs text-slate-500">Gerado em: ${escapeHtml(currentDate)}</p>
                    </div>
                `;
                
                // Inserir cabeçalho no topo da view
                activeView.insertBefore(headerEl, activeView.firstChild);

                                // Add a temporary class first so that the browser calculates the true size of the view with PDF padding applied
                activeView.classList.add('pdf-exporting');

                // Allow a tiny reflow tick for CSS to apply (specifically padding and width changes)
                await new Promise(resolve => setTimeout(resolve, 50));

                // Now calculate the true dimensions required, including the 40px padding from CSS
                // We use scrollWidth/scrollHeight to capture everything even if it overflows the viewport
                const width = Math.max(activeView.scrollWidth, activeView.offsetWidth);
                const height = Math.max(activeView.scrollHeight, activeView.offsetHeight);

                // Determine layout sizes and prepare for high-res single page export
                const opt = {
                    margin:       0, // We handle margins via CSS padding on .pdf-exporting
                    filename:     `export_${new Date().toISOString().split('T')[0]}.pdf`,
                    image:        { type: 'jpeg', quality: 0.98 },
                    html2canvas:  { 
                        scale: 2,
                        useCORS: true, 
                        logging: false,
                        x: 0,
                        y: 0,
                        scrollX: 0,
                        scrollY: 0,
                        windowWidth: width,
                        windowHeight: height,
                        width: width,   // Explicitly tell canvas to render this width
                        height: height, // Explicitly tell canvas to render this height
                        backgroundColor: '#131217'
                    },
                    jsPDF:        {
                        unit: 'px',
                        format: [width, height],
                        orientation: width > height ? 'landscape' : 'portrait',
                        hotfixes: ["px_scaling"] // Fixes some resolution/scaling bugs in jsPDF
                    }
                };

                await html2pdf().set(opt).from(activeView).save();
                
            } catch (err) {
                AppLog.error("Erro ao gerar PDF:", err);
                alert("Ocorreu um erro ao gerar o PDF. Tente novamente.");
            } finally {
                // Remover cabeçalho customizado
                if (headerEl && headerEl.parentNode) {
                    headerEl.parentNode.removeChild(headerEl);
                }
                
                // Restore button state
                restoreElementState(exportPdfBtn, exportPdfBtn, originalHtml);
                if (activeView) activeView.classList.remove('pdf-exporting');
            }
        });
    }
    window.addEventListener('resize', () => {
        if (exportDropdown && !exportDropdown.classList.contains('hidden')) {
             exportDropdown.classList.add('hidden');
        }
    });
    const navComparativoBtn = document.getElementById('nav-comparativo-btn');
    const optimizeDbBtnNav = document.getElementById('optimize-db-btn-nav');
    const profileMenuBtn = document.getElementById('profile-menu-btn');
    const profileDropdown = document.getElementById('profile-dropdown');
    const profileDropdownName = document.getElementById('profile-dropdown-name');
    const profileDropdownRole = document.getElementById('profile-dropdown-role');

    // Profile Dropdown Logic
    if (profileMenuBtn && profileDropdown) {
        profileMenuBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            profileDropdown.classList.toggle('hidden');
            const isHidden = profileDropdown.classList.contains('hidden');
            profileMenuBtn.setAttribute('aria-expanded', (!isHidden).toString());
        });

        document.addEventListener('click', (e) => {
            if (!profileDropdown.contains(e.target) && !profileMenuBtn.contains(e.target)) {
                profileDropdown.classList.add('hidden');
                profileMenuBtn.setAttribute('aria-expanded', 'false');
            }
        });
    }

    // Views
    const dashboardContainer = document.getElementById('dashboard-container');
    const uploaderModal = document.getElementById('uploader-modal');
    const innovationsMonthView = document.getElementById('innovations-month-view');
    const lojaPerfeitaView = document.getElementById('loja-perfeita-view');
    const estrelasView = document.getElementById('estrelas-view');
    const agendaView = document.getElementById('agenda-view');
    
    const closeUploaderBtn = document.getElementById('close-uploader-btn');

    // Dashboard Internal Views
    const mainDashboardView = document.getElementById('main-dashboard-view');
    const mainDashboardHeader = document.getElementById('main-dashboard-header');
    const mainDashboardContent = document.getElementById('main-dashboard-content');
    const cityView = document.getElementById('city-view');
    const boxesView = document.getElementById('boxes-view'); // New Boxes View
    const branchView = document.getElementById('branch-view');
    const comparisonView = document.getElementById('comparison-view'); // New

    // Buttons in Dashboard
    const clearFiltersBtn = document.getElementById('clear-filters-btn');
    const calendarBtn = document.getElementById('calendar-btn'); // New Calendar Button
    const chartToggleBtn = document.getElementById('chart-toggle-btn'); // Chart Mode Toggle

    // Toggle Secondary KPIs
    const toggleSecondaryKpisBtn = document.getElementById('toggle-secondary-kpis-btn');
    const secondaryKpiRow = document.getElementById('secondary-kpi-row');
    const toggleKpiIcon = document.getElementById('toggle-kpi-icon');

    // --- Filter Element Declarations (Hoisted to top of DOMContentLoaded) ---
    // Dashboard Filters
    const anoFilter = document.getElementById('ano-filter');
    const mesFilter = document.getElementById('mes-filter');
    const filialFilterBtn = document.getElementById('filial-filter-btn');
    const filialFilterDropdown = document.getElementById('filial-filter-dropdown');
    const cidadeFilterBtn = document.getElementById('cidade-filter-btn');
    const cidadeFilterDropdown = document.getElementById('cidade-filter-dropdown');
    const cidadeFilterList = document.getElementById('cidade-filter-list');
    const cidadeFilterSearch = document.getElementById('cidade-filter-search');
    const supervisorFilterBtn = document.getElementById('supervisor-filter-btn');
    const supervisorFilterDropdown = document.getElementById('supervisor-filter-dropdown');
    const vendedorFilterBtn = document.getElementById('vendedor-filter-btn');
    const vendedorFilterDropdown = document.getElementById('vendedor-filter-dropdown');
    const vendedorFilterList = document.getElementById('vendedor-filter-list');
    const vendedorFilterSearch = document.getElementById('vendedor-filter-search');
    const fornecedorFilterBtn = document.getElementById('fornecedor-filter-btn');
    const fornecedorFilterDropdown = document.getElementById('fornecedor-filter-dropdown');
    const fornecedorFilterList = document.getElementById('fornecedor-filter-list');
    const fornecedorFilterSearch = document.getElementById('fornecedor-filter-search');
    const tipovendaFilterBtn = document.getElementById('tipovenda-filter-btn');
    const tipovendaFilterDropdown = document.getElementById('tipovenda-filter-dropdown');
    const redeFilterBtn = document.getElementById('rede-filter-btn');
    const redeFilterDropdown = document.getElementById('rede-filter-dropdown');
    const redeFilterList = document.getElementById('rede-filter-list');
    const redeFilterSearch = document.getElementById('rede-filter-search');
    const categoriaFilterBtn = document.getElementById('categoria-filter-btn');
    const categoriaFilterDropdown = document.getElementById('categoria-filter-dropdown');
    const categoriaFilterList = document.getElementById('categoria-filter-list');
    const categoriaFilterSearch = document.getElementById('categoria-filter-search');

    // Boxes Filter Elements
    const boxesCategoriaFilterBtn = document.getElementById('boxes-categoria-filter-btn');
    const boxesCategoriaFilterDropdown = document.getElementById('boxes-categoria-filter-dropdown');
    const boxesCategoriaFilterList = document.getElementById('boxes-categoria-filter-list');
    const boxesCategoriaFilterSearch = document.getElementById('boxes-categoria-filter-search');

    const boxesAnoFilter = document.getElementById('boxes-ano-filter');
    const boxesMesFilter = document.getElementById('boxes-mes-filter');
    const boxesFilialFilterBtn = document.getElementById('boxes-filial-filter-btn');
    const boxesFilialFilterDropdown = document.getElementById('boxes-filial-filter-dropdown');
    const boxesProdutoFilterBtn = document.getElementById('boxes-produto-filter-btn');
    const boxesProdutoFilterDropdown = document.getElementById('boxes-produto-filter-dropdown');
    const boxesProdutoFilterList = document.getElementById('boxes-produto-filter-list');
    const boxesProdutoFilterSearch = document.getElementById('boxes-produto-filter-search');
    const boxesSupervisorFilterBtn = document.getElementById('boxes-supervisor-filter-btn');
    const boxesSupervisorFilterDropdown = document.getElementById('boxes-supervisor-filter-dropdown');
    const boxesVendedorFilterBtn = document.getElementById('boxes-vendedor-filter-btn');
    const boxesVendedorFilterDropdown = document.getElementById('boxes-vendedor-filter-dropdown');
    const boxesVendedorFilterList = document.getElementById('boxes-vendedor-filter-list');
    const boxesVendedorFilterSearch = document.getElementById('boxes-vendedor-filter-search');
    const boxesFornecedorFilterBtn = document.getElementById('boxes-fornecedor-filter-btn');
    const boxesFornecedorFilterDropdown = document.getElementById('boxes-fornecedor-filter-dropdown');
    const boxesFornecedorFilterList = document.getElementById('boxes-fornecedor-filter-list');
    const boxesFornecedorFilterSearch = document.getElementById('boxes-fornecedor-filter-search');
    const boxesCidadeFilterBtn = document.getElementById('boxes-cidade-filter-btn');
    const boxesCidadeFilterDropdown = document.getElementById('boxes-cidade-filter-dropdown');
    const boxesCidadeFilterList = document.getElementById('boxes-cidade-filter-list');
    const boxesCidadeFilterSearch = document.getElementById('boxes-cidade-filter-search');
    const boxesTipovendaFilterBtn = document.getElementById('boxes-tipovenda-filter-btn');
    const boxesTipovendaFilterDropdown = document.getElementById('boxes-tipovenda-filter-dropdown');
    const boxesClearFiltersBtn = document.getElementById('boxes-clear-filters-btn');
    const boxesTrendToggleBtn = document.getElementById('boxes-trend-toggle-btn');
    // Boxes Export
    const boxesExportBtn = document.getElementById('boxes-export-btn');
    const boxesExportDropdown = document.getElementById('boxes-export-dropdown');
    const boxesExportExcelBtn = document.getElementById('boxes-export-excel');
    const boxesExportPdfBtn = document.getElementById('boxes-export-pdf');

    // City View Filter Logic
    const cityFilialFilterBtn = document.getElementById('city-filial-filter-btn');
    const cityFilialFilterDropdown = document.getElementById('city-filial-filter-dropdown');
    const cityAnoFilter = document.getElementById('city-ano-filter');
    const cityMesFilter = document.getElementById('city-mes-filter');
    const cityCidadeFilterBtn = document.getElementById('city-cidade-filter-btn');
    const cityCidadeFilterDropdown = document.getElementById('city-cidade-filter-dropdown');
    const cityCidadeFilterList = document.getElementById('city-cidade-filter-list');
    const cityCidadeFilterSearch = document.getElementById('city-cidade-filter-search');
    const citySupervisorFilterBtn = document.getElementById('city-supervisor-filter-btn');
    const citySupervisorFilterDropdown = document.getElementById('city-supervisor-filter-dropdown');
    const cityVendedorFilterBtn = document.getElementById('city-vendedor-filter-btn');
    const cityVendedorFilterDropdown = document.getElementById('city-vendedor-filter-dropdown');
    const cityVendedorFilterList = document.getElementById('city-vendedor-filter-list');
    const cityVendedorFilterSearch = document.getElementById('city-vendedor-filter-search');
    const cityFornecedorFilterBtn = document.getElementById('city-fornecedor-filter-btn');
    const cityFornecedorFilterDropdown = document.getElementById('city-fornecedor-filter-dropdown');
    const cityFornecedorFilterList = document.getElementById('city-fornecedor-filter-list');
    const cityFornecedorFilterSearch = document.getElementById('city-fornecedor-filter-search');
    const cityRedeFilterBtn = document.getElementById('city-rede-filter-btn');
    const cityRedeFilterDropdown = document.getElementById('city-rede-filter-dropdown');
    const cityRedeFilterList = document.getElementById('city-rede-filter-list');
    const cityRedeFilterSearch = document.getElementById('city-rede-filter-search');
    const cityTipovendaFilterBtn = document.getElementById('city-tipovenda-filter-btn');
    const cityTipovendaFilterDropdown = document.getElementById('city-tipovenda-filter-dropdown');
    const cityClearFiltersBtn = document.getElementById('city-clear-filters-btn');

    const cityCategoriaFilterBtn = document.getElementById('city-categoria-filter-btn');
    const cityCategoriaFilterDropdown = document.getElementById('city-categoria-filter-dropdown');
    const cityCategoriaFilterList = document.getElementById('city-categoria-filter-list');
    const cityCategoriaFilterSearch = document.getElementById('city-categoria-filter-search');

    // Branch View Logic
    const branchFilialFilterBtn = document.getElementById('branch-filial-filter-btn');
    const branchFilialFilterDropdown = document.getElementById('branch-filial-filter-dropdown');
    const branchAnoFilter = document.getElementById('branch-ano-filter');
    const branchMesFilter = document.getElementById('branch-mes-filter');
    const branchCidadeFilterBtn = document.getElementById('branch-cidade-filter-btn');
    const branchCidadeFilterDropdown = document.getElementById('branch-cidade-filter-dropdown');
    const branchCidadeFilterList = document.getElementById('branch-cidade-filter-list');
    const branchCidadeFilterSearch = document.getElementById('branch-cidade-filter-search');
    const branchSupervisorFilterBtn = document.getElementById('branch-supervisor-filter-btn');
    const branchSupervisorFilterDropdown = document.getElementById('branch-supervisor-filter-dropdown');
    const branchVendedorFilterBtn = document.getElementById('branch-vendedor-filter-btn');
    const branchVendedorFilterDropdown = document.getElementById('branch-vendedor-filter-dropdown');
    const branchVendedorFilterList = document.getElementById('branch-vendedor-filter-list');
    const branchVendedorFilterSearch = document.getElementById('branch-vendedor-filter-search');
    const branchFornecedorFilterBtn = document.getElementById('branch-fornecedor-filter-btn');
    const branchFornecedorFilterDropdown = document.getElementById('branch-fornecedor-filter-dropdown');
    const branchFornecedorFilterList = document.getElementById('branch-fornecedor-filter-list');
    const branchFornecedorFilterSearch = document.getElementById('branch-fornecedor-filter-search');
    const branchRedeFilterBtn = document.getElementById('branch-rede-filter-btn');
    const branchRedeFilterDropdown = document.getElementById('branch-rede-filter-dropdown');
    const branchRedeFilterList = document.getElementById('branch-rede-filter-list');
    const branchRedeFilterSearch = document.getElementById('branch-rede-filter-search');
    const branchTipovendaFilterBtn = document.getElementById('branch-tipovenda-filter-btn');
    const branchTipovendaFilterDropdown = document.getElementById('branch-tipovenda-filter-dropdown');
    const branchClearFiltersBtn = document.getElementById('branch-clear-filters-btn');
    const branchCalendarBtn = document.getElementById('branch-calendar-btn');
    const branchChartToggleBtn = document.getElementById('branch-chart-toggle-btn');

    const branchCategoriaFilterBtn = document.getElementById('branch-categoria-filter-btn');
    const branchCategoriaFilterDropdown = document.getElementById('branch-categoria-filter-dropdown');
    const branchCategoriaFilterList = document.getElementById('branch-categoria-filter-list');
    const branchCategoriaFilterSearch = document.getElementById('branch-categoria-filter-search');

    // Comparison View Filters
    const comparisonAnoFilter = document.getElementById('comparison-ano-filter');
    const comparisonMesFilter = document.getElementById('comparison-mes-filter');
    const comparisonSupervisorFilterBtn = document.getElementById('comparison-supervisor-filter-btn');
    const comparisonSupervisorFilterDropdown = document.getElementById('comparison-supervisor-filter-dropdown');
    const comparisonVendedorFilterBtn = document.getElementById('comparison-vendedor-filter-btn');
    const comparisonVendedorFilterDropdown = document.getElementById('comparison-vendedor-filter-dropdown');
    const comparisonSupplierFilterBtn = document.getElementById('comparison-supplier-filter-btn');
    const comparisonSupplierFilterDropdown = document.getElementById('comparison-supplier-filter-dropdown');
    const comparisonProductFilterBtn = document.getElementById('comparison-product-filter-btn');
    const comparisonProductFilterDropdown = document.getElementById('comparison-product-filter-dropdown');
    const comparisonTipoVendaFilterBtn = document.getElementById('comparison-tipo-venda-filter-btn');
    const comparisonTipoVendaFilterDropdown = document.getElementById('comparison-tipo-venda-filter-dropdown');
    const comparisonRedeFilterBtn = document.getElementById('comparison-rede-filter-btn');
    const comparisonRedeFilterDropdown = document.getElementById('comparison-rede-filter-dropdown');
    const comparisonRedeFilterList = document.getElementById('comparison-rede-filter-list');
    const comparisonRedeFilterSearch = document.getElementById('comparison-rede-filter-search');
    const comparisonFilialFilterBtn = document.getElementById('comparison-filial-filter-btn');
    const comparisonFilialFilterDropdown = document.getElementById('comparison-filial-filter-dropdown');
    const comparisonCityFilterBtn = document.getElementById('comparison-city-filter-btn');
    const comparisonCityFilterDropdown = document.getElementById('comparison-city-filter-dropdown');
    const comparisonCityFilterList = document.getElementById('comparison-city-filter-list');
    const comparisonCityFilterSearch = document.getElementById('comparison-city-filter-search');
    const comparisonCategoriaFilterBtn = document.getElementById('comparison-categoria-filter-btn');
    const comparisonCategoriaFilterDropdown = document.getElementById('comparison-categoria-filter-dropdown');
    const clearComparisonFiltersBtn = document.getElementById('clear-comparison-filters-btn');
    const comparisonPastaFilter = document.getElementById('comparison-pasta-filter');
    const comparisonTendencyToggle = document.getElementById('comparison-tendency-toggle');
    const toggleWeeklyBtn = document.getElementById('toggle-weekly-btn');
    const toggleMonthlyBtn = document.getElementById('toggle-monthly-btn');
    const comparisonChartTitle = document.getElementById('comparison-chart-title');
    const weeklyComparisonChartContainer = document.getElementById('weeklyComparisonChartContainer');
    const monthlyComparisonChartContainer = document.getElementById('monthlyComparisonChartContainer');
    const toggleMonthlyFatBtn = document.getElementById('toggle-monthly-fat-btn');
    const toggleMonthlyClientsBtn = document.getElementById('toggle-monthly-clients-btn');

    if(toggleSecondaryKpisBtn && secondaryKpiRow) {
        toggleSecondaryKpisBtn.addEventListener('click', () => {
            secondaryKpiRow.classList.toggle('hidden');
            const isHidden = secondaryKpiRow.classList.contains('hidden');
            toggleSecondaryKpisBtn.setAttribute('aria-expanded', (!isHidden).toString());

            // Icon Paths
            const plusPath = "M12 4v16m8-8H4"; // Heroicons Plus
            const minusPath = "M20 12H4"; // Heroicons Minus

            // Update Icon
            if(toggleKpiIcon) {
                updateSvgPaths(toggleKpiIcon, [isHidden ? plusPath : minusPath]);
            }
        });
    }

    // Calendar Modal Elements
    const calendarModal = document.getElementById('calendar-modal');
    const calendarModalBackdrop = document.getElementById('calendar-modal-backdrop');
    const closeCalendarModalBtn = document.getElementById('close-calendar-modal-btn');
    const calendarModalContent = document.getElementById('calendar-modal-content');
    // For comparison view:
    const comparisonHolidayPickerBtn = document.getElementById('comparison-holiday-picker-btn');

    // Uploader Elements
    const salesPrevYearInput = document.getElementById('sales-prev-year-input');
    const salesCurrYearInput = document.getElementById('sales-curr-year-input');
    const salesCurrMonthInput = document.getElementById('sales-curr-month-input');
    const clientsFileInput = document.getElementById('clients-file-input');
    const productsFileInput = document.getElementById('products-file-input');
    const generateBtn = document.getElementById('generate-btn');
    const optimizeDbBtn = document.getElementById('optimize-db-btn');
    const statusContainer = document.getElementById('status-container');
    const statusText = document.getElementById('status-text');
    const progressBar = document.getElementById('progress-bar');
    const missingBranchesNotification = document.getElementById('missing-branches-notification');

    // --- Auth Logic ---
    const telaLoading = document.getElementById('tela-loading');
    const telaPendente = document.getElementById('tela-pendente');

    // UI Functions
    const showScreen = (screenId) => {
        // Hide all auth/app screens first
        [loginView, telaLoading, telaPendente, appLayout].forEach(el => el?.classList.add('hidden'));
        
        // Ensure topNavbar is hidden by default on auth screens
        if (topNavbar) topNavbar.classList.add('hidden');
        
        if (screenId) {
            const screen = document.getElementById(screenId);
            screen?.classList.remove('hidden');

            // If showing the login view container, explicitly set it back to the signin view
            if (screenId === 'login-view') {
                switchAuthView(loginFormSignin);
            }

            // Ensure Top Nav is visible if authenticated and in app
            if (screenId === 'app-layout' && topNavbar) {
                topNavbar.classList.remove('hidden');
            }
        }
    };

    // --- Cache (IndexedDB) Logic ---
    const DB_NAME = 'PrimeDashboardDB';
    const STORE_NAME = 'data_store';
    const DB_VERSION = 1;

    // --- URL Routing & Filter Persistence Logic ---

    function getActiveViewId() {
        if (!mainDashboardView.classList.contains('hidden')) return 'dashboard';
        if (!cityView.classList.contains('hidden')) return 'city';
        if (!boxesView.classList.contains('hidden')) return 'boxes';
        if (!branchView.classList.contains('hidden')) return 'branch';
        if (comparisonView && !comparisonView.classList.contains('hidden')) return 'comparison';
        if (innovationsMonthView && !innovationsMonthView.classList.contains('hidden')) return 'innovations';
        if (lojaPerfeitaView && !lojaPerfeitaView.classList.contains('hidden')) return 'loja-perfeita';
        if (estrelasView && !estrelasView.classList.contains('hidden')) return 'estrelas';
        return 'dashboard';
    }

    function getFiltersFromActiveView() {
        const view = getActiveViewId();
        const state = {};

        if (view === 'dashboard') {
            state.ano = anoFilter.value;
            state.mes = mesFilter.value;
            state.filiais = selectedFiliais;
            state.cidades = selectedCidades;
            state.supervisores = selectedSupervisores;
            state.vendedores = selectedVendedores;
            state.fornecedores = selectedFornecedores;
            state.tiposvenda = selectedTiposVenda;
            state.redes = selectedRedes;
            state.categorias = selectedCategorias;
        } else if (view === 'city') {
            state.ano = cityAnoFilter.value;
            state.mes = cityMesFilter.value;
            state.filiais = citySelectedFiliais;
            state.cidades = citySelectedCidades;
            state.supervisores = citySelectedSupervisores;
            state.vendedores = citySelectedVendedores;
            state.fornecedores = citySelectedFornecedores;
            state.tiposvenda = citySelectedTiposVenda;
            state.redes = citySelectedRedes;
        } else if (view === 'boxes') {
            state.ano = boxesAnoFilter.value;
            state.mes = boxesMesFilter.value;
            state.filiais = boxesSelectedFiliais;
            state.cidades = boxesSelectedCidades;
            state.supervisores = boxesSelectedSupervisores;
            state.vendedores = boxesSelectedVendedores;
            state.fornecedores = boxesSelectedFornecedores;
            state.produtos = boxesSelectedProducts;
            // state.tiposvenda = ... if added later
        } else if (view === 'branch') {
            state.ano = branchAnoFilter.value;
            state.mes = branchMesFilter.value;
            state.filiais = branchSelectedFiliais;
            state.cidades = branchSelectedCidades;
            state.supervisores = branchSelectedSupervisores;
            state.vendedores = branchSelectedVendedores;
            state.fornecedores = branchSelectedFornecedores;
            state.tiposvenda = branchSelectedTiposVenda;
            state.redes = branchSelectedRedes;
        } else if (view === 'comparison') {
            state.ano = comparisonAnoFilter.value;
            state.mes = comparisonMesFilter.value;
            state.filiais = selectedComparisonFiliais;
            state.cidades = selectedComparisonCities;
            state.supervisores = selectedComparisonSupervisors;
            state.vendedores = selectedComparisonSellers;
            state.fornecedores = selectedComparisonSuppliers;
            state.produtos = selectedComparisonProducts;
            state.tiposvenda = selectedComparisonTiposVenda;
            state.redes = selectedComparisonRedes;
            state.categorias = selectedComparisonCategorias;
        } else if (view === 'innovations') {
            const anoSelect = document.getElementById('innovations-ano-filter');
            const mesSelect = document.getElementById('innovations-mes-filter');
            state.ano = anoSelect ? anoSelect.value : null;
            state.mes = mesSelect ? mesSelect.value : null;
            state.filiais = innovationsSelectedFiliais;
            state.cidades = innovationsSelectedCidades;
            state.supervisores = innovationsSelectedSupervisors;
            state.vendedores = innovationsSelectedVendedores;
            state.tiposvenda = innovationsSelectedTiposVenda;
            state.redes = innovationsSelectedRedes;
            state.categorias = innovationsSelectedCategorias;

        } else if (view === 'estrelas') {
            const anoSelect = document.getElementById('estrelas-ano-filter');
            const mesSelect = document.getElementById('estrelas-mes-filter');
            state.ano = anoSelect ? anoSelect.value : null;
            state.mes = mesSelect ? mesSelect.value : null;
            state.filiais = estrelasSelectedFiliais;
            state.cidades = estrelasSelectedCidades;
            state.supervisores = estrelasSelectedSupervisors;
            state.vendedores = estrelasSelectedVendedores;
            state.fornecedores = estrelasSelectedFornecedores;
            state.tiposvenda = estrelasSelectedTiposVenda;
            state.redes = estrelasSelectedRedes;
            state.categorias = estrelasSelectedCategorias;
        } else if (view === 'loja-perfeita') {
            state.cidades = lpSelectedCidades;
            state.supervisores = lpSelectedSupervisors;
            state.vendedores = lpSelectedVendedores;
            state.redes = lpSelectedRedes;
            if (lpSelectedClient) state.codcli = lpSelectedClient;
        }

        const serialize = (key, val) => {
            if (Array.isArray(val)) return val.join(',');
            return val;
        };

        const params = new URLSearchParams();
        for (const [key, val] of Object.entries(state)) {
            if (val && val.length > 0) {
                 params.set(key, serialize(key, val));
            }
        }
        return params;
    }

    function applyFiltersToView(view, params) {
        const getList = (key) => {
            const val = params.get(key);
            return val ? val.split(',') : [];
        };
        const getVal = (key) => params.get(key);

        if (view === 'dashboard') {
            if (getVal('ano')) anoFilter.value = getVal('ano');
            if (getVal('mes')) mesFilter.value = getVal('mes');

            selectedFiliais = getList('filiais');
            selectedCidades = getList('cidades');
            selectedSupervisores = getList('supervisores');
            selectedVendedores = getList('vendedores');
            selectedFornecedores = getList('fornecedores');
            selectedTiposVenda = getList('tiposvenda');
            selectedRedes = getList('redes');
            selectedCategorias = getList('categorias');

        } else if (view === 'city') {
            if (getVal('ano')) cityAnoFilter.value = getVal('ano');
            if (getVal('mes')) cityMesFilter.value = getVal('mes');

            citySelectedFiliais = getList('filiais');
            citySelectedCidades = getList('cidades');
            citySelectedSupervisores = getList('supervisores');
            citySelectedVendedores = getList('vendedores');
            citySelectedFornecedores = getList('fornecedores');
            citySelectedTiposVenda = getList('tiposvenda');
            citySelectedRedes = getList('redes');

        } else if (view === 'boxes') {
            if (getVal('ano')) boxesAnoFilter.value = getVal('ano');
            if (getVal('mes')) boxesMesFilter.value = getVal('mes');

            boxesSelectedFiliais = getList('filiais');
            boxesSelectedCidades = getList('cidades');
            boxesSelectedSupervisores = getList('supervisores');
            boxesSelectedVendedores = getList('vendedores');
            boxesSelectedFornecedores = getList('fornecedores');
            boxesSelectedProducts = getList('produtos');

        } else if (view === 'branch') {
             if (getVal('ano')) branchAnoFilter.value = getVal('ano');
             if (getVal('mes')) branchMesFilter.value = getVal('mes');

             branchSelectedFiliais = getList('filiais');
             branchSelectedCidades = getList('cidades');
             branchSelectedSupervisores = getList('supervisores');
             branchSelectedVendedores = getList('vendedores');
             branchSelectedFornecedores = getList('fornecedores');
             branchSelectedTiposVenda = getList('tiposvenda');
             branchSelectedRedes = getList('redes');

        } else if (view === 'comparison') {
             if (getVal('ano')) comparisonAnoFilter.value = getVal('ano');
             if (getVal('mes')) comparisonMesFilter.value = getVal('mes');

             const filiais = getList('filiais');
             selectedComparisonFiliais = getList('filiais');

             selectedComparisonCities = getList('cidades');

             selectedComparisonSupervisors = getList('supervisores');
             selectedComparisonSellers = getList('vendedores');
             selectedComparisonSuppliers = getList('fornecedores');
             selectedComparisonProducts = getList('produtos');
             selectedComparisonTiposVenda = getList('tiposvenda');
             selectedComparisonRedes = getList('redes');
             selectedComparisonCategorias = getList('categorias');
        } else if (view === 'innovations') {
            const anoSelect = document.getElementById('innovations-ano-filter');
            const mesSelect = document.getElementById('innovations-mes-filter');
            if (getVal('ano') && anoSelect) anoSelect.value = getVal('ano');
            if (getVal('mes') && mesSelect) mesSelect.value = getVal('mes');
            innovationsSelectedFiliais = getList('filiais');
            innovationsSelectedCidades = getList('cidades');
            innovationsSelectedSupervisors = getList('supervisores');
            innovationsSelectedVendedores = getList('vendedores');
            innovationsSelectedTiposVenda = getList('tiposvenda');
            innovationsSelectedRedes = getList('redes');
            innovationsSelectedCategorias = getList('categorias');

        } else if (view === 'estrelas') {
            const anoSelect = document.getElementById('estrelas-ano-filter');
            const mesSelect = document.getElementById('estrelas-mes-filter');
            if (getVal('ano') && anoSelect) anoSelect.value = getVal('ano');
            if (getVal('mes') && mesSelect) mesSelect.value = getVal('mes');
            estrelasSelectedFiliais = getList('filiais');
            estrelasSelectedCidades = getList('cidades');
            estrelasSelectedSupervisors = getList('supervisores');
            estrelasSelectedVendedores = getList('vendedores');
            estrelasSelectedFornecedores = getList('fornecedores');
            estrelasSelectedTiposVenda = getList('tiposvenda');
            estrelasSelectedRedes = getList('redes');
            estrelasSelectedCategorias = getList('categorias');
        } else if (view === 'loja-perfeita') {
            lpSelectedCidades = getList('cidades');
            lpSelectedSupervisors = getList('supervisores');
            lpSelectedVendedores = getList('vendedores');
            lpSelectedRedes = getList('redes');
            if (getVal('codcli')) lpSelectedClient = getVal('codcli');
        }
    }

    async function handleInitialRouting() {
        const params = new URLSearchParams(window.location.search);
        let view = params.get('view');

        // Priority to URL Hash if query param isn't explicitly setting it
        if (!view && window.location.hash) {
            view = window.location.hash.substring(1);
        }

        checkRoleForUI();

        if (view) {
            applyFiltersToView(view, params);
        }

        showScreen('app-layout');

        // Provide a default if the view wasn't set or is invalid
        const validViews = ['dashboard', 'city', 'boxes', 'branch', 'comparison', 'innovations', 'loja-perfeita', 'estrelas', 'agenda'];
        if (!view || !validViews.includes(view)) {
            view = 'dashboard';
        }

        renderView(view);

        if (view === 'dashboard') {
            initDashboard();
        }
    }

    window.addEventListener('hashchange', () => {
        const view = window.location.hash.substring(1) || 'dashboard';
        renderView(view, { skipHistory: true });
    });

    function navigateWithCtrl(e, targetViewId) {
        if (e.ctrlKey || e.metaKey) {
            e.preventDefault();
            e.stopPropagation();

            const params = getFiltersFromActiveView();
            params.set('view', targetViewId);

            const url = `${window.location.pathname}?${params.toString()}`;
            window.open(url, '_blank');
            return true;
        }
        return false;
    }

    const initDB = () => {
        return idb.openDB(DB_NAME, DB_VERSION, {
            upgrade(db) {
                if (!db.objectStoreNames.contains(STORE_NAME)) {
                    db.createObjectStore(STORE_NAME);
                }
            },
        });
    };

    const getFromCache = async (key) => {
        try {
            const db = await initDB();
            return await db.get(STORE_NAME, key);
        } catch (e) {
            AppLog.warn('Erro ao ler cache:', e);
            return null;
        }
    };

    const saveToCache = async (key, value) => {
        try {
            const db = await initDB();
            // Wrap data with timestamp for TTL
            const payload = { timestamp: Date.now(), data: value };
            await db.put(STORE_NAME, payload, key);
        } catch (e) {
            AppLog.warn('Erro ao salvar cache:', e);
        }
    };

    // Helper to check if bonification mode is active (Only Type 5 or 11 or both)
    function isBonificationMode(selectedTypes) {
        if (!selectedTypes || selectedTypes.length === 0) return false;
        return selectedTypes.every(t => t === '5' || t === '11');
    }

    // Helper to generate canonical cache keys (sorted arrays)
    function generateCacheKey(prefix, filters) {
        const sortedFilters = {};
        Object.keys(filters).sort().forEach(k => {
            let val = filters[k];
            if (Array.isArray(val)) {
                // Clone and sort array to ensure ['A', 'B'] == ['B', 'A']
                val = [...val].sort();
            }
            sortedFilters[k] = val;
        });
        return `${prefix}_${JSON.stringify(sortedFilters)}`;
    }

    let checkProfileLock = false;
    let isAppReady = false;

    // --- Visibility & Reconnection Logic ---
    document.addEventListener('visibilitychange', async () => {
        if (document.visibilityState === 'visible') {
            const { data } = await supabase.auth.getSession();
            if (data && data.session) {
                if (!isAppReady) {
                     checkProfileStatus(data.session.user);
                }
            } else {
                if (isAppReady) {
                     window.location.reload();
                }
            }
        }
    });

    async function checkSession() {
        showScreen('tela-loading');

        supabase.auth.onAuthStateChange(async (event, session) => {
            if (event === 'SIGNED_OUT') {
                isAppReady = false;
                showScreen('login-view');
                return;
            }

            if (session) {
                if (isAppReady) return;

                if (!checkProfileLock) {
                    await checkProfileStatus(session.user);
                }
            } else {
                showScreen('login-view');
            }
        });
    }

    function updateProfileMenu(name, role) {
        if (profileDropdownName) profileDropdownName.textContent = name || 'Usuário';
        if (profileDropdownRole) profileDropdownRole.textContent = role || 'Sem Função';
    }

    async function checkProfileStatus(user) {
        if (isAppReady) return;

        const cacheKey = `user_auth_cache_${user.id}`;
        const cachedAuth = localStorage.getItem(cacheKey);

        if (cachedAuth) {
            try {
                const { status, role, name } = JSON.parse(cachedAuth);
                if (status === 'aprovado') {
                    window.userRole = role;
                    updateProfileMenu(name, role);
                    isAppReady = true;
                    handleInitialRouting();
                    return;
                }
            } catch (e) {
                localStorage.removeItem(cacheKey);
            }
        }

        checkProfileLock = true;
        
        try {
            const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('Tempo limite de conexão excedido. Verifique sua internet.')), 10000));
            const profileQuery = supabase.from('profiles').select('status, role, name').eq('id', user.id).single();

            const { data: profile, error } = await Promise.race([profileQuery, timeout]);

            if (error) {
                if (error.code === 'PGRST116') {
                    // Profile doesn't exist, create it
                    const { error: insertError } = await supabase
                        .from('profiles')
                        .insert([{ id: user.id, email: user.email, status: 'pendente' }]);

                    if (insertError) throw insertError;
                } else {
                    throw error;
                }
            }

            const status = profile?.status || 'pendente';
            if (profile?.role) window.userRole = profile.role;
            updateProfileMenu(profile?.name, profile?.role);

            if (status === 'aprovado') {
                localStorage.setItem(cacheKey, JSON.stringify({ status: 'aprovado', role: profile?.role, name: profile?.name }));
                const currentScreen = document.getElementById('app-layout');
                if (currentScreen.classList.contains('hidden')) {
                    isAppReady = true;
                    handleInitialRouting();
                } else {
                    isAppReady = true;
                }
            } else {
                showScreen('tela-pendente');
                if (status === 'bloqueado') {
                        const statusMsg = document.getElementById('status-text-pendente'); 
                        if(statusMsg) statusMsg.textContent = "Acesso Bloqueado";
                }
                startStatusListener(user.id);
            }
        } catch (err) {
            checkProfileLock = false;
            if (!isAppReady) {
                if (err.message !== 'Tempo limite de conexão excedido. Verifique sua internet.') {
                    window.showToast('error', "Erro de conexão: " + (err.message || 'Erro desconhecido'));
                    showScreen('login-view');
                }
            }
        } finally {
            checkProfileLock = false;
        }
    }

    let statusListener = null;
    function startStatusListener(userId) {
        if (statusListener) return;

        statusListener = supabase
            .channel(`public:profiles:id=eq.${userId}`)
            .on('postgres_changes', {
                event: 'UPDATE',
                schema: 'public',
                table: 'profiles',
                filter: `id=eq.${userId}`
            }, (payload) => {
                if (payload.new && payload.new.status === 'aprovado') {
                    supabase.removeChannel(statusListener);
                    statusListener = null;
                    handleInitialRouting();
                }
            })
            .subscribe();
    }

    if (googleLoginBtn) {
        googleLoginBtn.addEventListener('click', async () => {
            loginError.classList.add('hidden');
            const { data, error } = await supabase.auth.signInWithOAuth({
                provider: 'google',
                options: { redirectTo: window.location.origin + window.location.pathname }
            });
            if (error) {
                loginError.textContent = 'Erro ao iniciar login: ' + error.message;
                loginError.classList.remove('hidden');
            }
        });
    }

    // Helper function to handle password visibility toggle
    // Extracted to reduce duplication and improve readability of the UI event logic.
    function setupPasswordToggle(btn, input, icon) {
        if (!btn || !input) return;
        btn.addEventListener('click', () => {
            const type = input.getAttribute('type') === 'password' ? 'text' : 'password';
            input.setAttribute('type', type);

            if (type === 'text') {
                btn.setAttribute('aria-label', 'Ocultar senha');
                btn.setAttribute('title', 'Ocultar senha');
                btn.setAttribute('aria-pressed', 'true');
            } else {
                btn.setAttribute('aria-label', 'Mostrar senha');
                btn.setAttribute('title', 'Mostrar senha');
                btn.setAttribute('aria-pressed', 'false');
            }

            if (icon) {
                if (type === 'text') {
                    updateSvgPaths(icon, ["M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"]);
                } else {
                    updateSvgPaths(icon, [
                        "M15 12a3 3 0 11-6 0 3 3 0 016 0z",
                        "M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                    ]);
                }
            }
        });
    }

    setupPasswordToggle(btnTogglePasswordSignin, inputPasswordSignin, eyeIcon);
    setupPasswordToggle(btnTogglePasswordSignup, inputPasswordSignup, eyeIconSignup);

    if (formSignin) {
        formSignin.addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const rememberMe = document.getElementById('remember-me');

            if (rememberMe && rememberMe.checked) {
                localStorage.setItem('prime_saved_email', email);
            } else {
                localStorage.removeItem('prime_saved_email');
            }

            const btn = formSignin.querySelector('button[type="submit"]');
            const btnText = btn.querySelector('.btn-text');
            const svgLoader = btn.querySelector('.loader') || document.createElement('svg');
            const oldText = btnText ? setElementLoading(btnText, btn, 'Entrando...', 'text-white') : setElementLoading(btn, btn, 'Entrando...', 'text-white');

            const { data, error } = await supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) {
                btnText ? restoreElementState(btnText, btn, oldText) : restoreElementState(btn, btn, oldText);
                loginError.textContent = 'Erro ao iniciar login: ' + error.message;
                loginError.classList.remove('hidden');
            }
        });
    }

    if (formSignup) {
        formSignup.addEventListener('submit', async (e) => {
            e.preventDefault();
            const name = document.getElementById('signup-name').value;
            const email = document.getElementById('signup-email').value;
            const phone = document.getElementById('signup-phone').value;
            const password = document.getElementById('signup-password').value;

            if (password.length < 8 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
                window.showToast('error', 'A senha deve ter no mínimo 8 caracteres, uma letra maiúscula, uma minúscula e um caractere especial.');
                return;
            }

            const btn = formSignup.querySelector('button[type=\"submit\"]');
            const oldText = setElementLoading(btn, btn, 'Cadastrando...', 'text-white');

            const { data, error } = await supabase.auth.signUp({
                email,
                password,
                options: {
                    data: {
                        full_name: name,
                        phone: phone,
                    },
                    emailRedirectTo: window.location.origin + window.location.pathname
                }
            });

            if (error) {
                window.showToast('error', 'Erro ao realizar cadastro: ' + error.message);
                restoreElementState(btn, btn, oldText);
                return;
            }

            if (data && data.user) {
                window.showToast('success', 'Cadastro realizado! Sua conta aguarda aprovação manual.');
                setTimeout(() => window.location.reload(), 2000);
            }
        });
    }

    if (formForgot) {
        formForgot.addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('forgot-email').value;

            const btn = formForgot.querySelector('button[type=\"submit\"]');
            const oldText = setElementLoading(btn, btn, 'Enviando...', 'text-white');

            try {
                const { data: profile, error: profileError } = await supabase
                    .from('profiles')
                    .select('status')
                    .eq('email', email)
                    .maybeSingle();

                if (profileError || !profile || profile.status !== 'aprovado') {
                    window.showToast('error', 'E-mail não encontrado ou cadastro pendente de aprovação.');
                    restoreElementState(btn, btn, oldText);
                    return;
                }

                const { data, error } = await supabase.auth.resetPasswordForEmail(email, {
                    redirectTo: window.location.origin + window.location.pathname,
                });

                if (error) {
                    window.showToast('error', 'Erro ao enviar e-mail: ' + error.message);
                } else {
                    window.showToast('success', 'Verifique seu e-mail para o link de redefinição de senha.');
                    switchAuthView(loginFormSignin);
                }
            } catch (err) {
                window.showToast('error', 'Ocorreu um erro ao processar sua solicitação.');
            } finally {
                restoreElementState(btn, btn, oldText);
            }
        });
    }

    const handleLogout = async () => {
        if(statusListener) {
            supabase.removeChannel(statusListener);
            statusListener = null;
        }
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user?.id) {
            localStorage.removeItem(`user_auth_cache_${session.user.id}`);
        }
        await supabase.auth.signOut();
    };

    logoutBtn.addEventListener('click', handleLogout);
    if(logoutBtnPendente) logoutBtnPendente.addEventListener('click', handleLogout);

    checkSession();

    // --- Navigation Logic (Updated for Top Nav) ---
    // Helper to check if a clicked link is already active
    function handleActiveLinkClick(e, navBtn, viewId) {
        if (navBtn.classList.contains('active')) {
            e.preventDefault();
            e.stopPropagation(); // prevent other handlers
            currentActiveNavId = navBtn.id;
            
            // Show Export Dropdown
            exportDropdown.classList.toggle('hidden');
            if (!exportDropdown.classList.contains('hidden')) {
                const rect = navBtn.getBoundingClientRect();
                exportDropdown.style.left = `${rect.left}px`;
                exportDropdown.style.top = `${rect.bottom + 8}px`; // 8px spacing
            }
            return true; // handled
        }
        // if not active, hide it
        if (exportDropdown && !exportDropdown.classList.contains('hidden')) {
            exportDropdown.classList.add('hidden');
        }
        return false;
    }

    function setActiveNavLink(link) {
        if (!link) return;
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
    }

    const resetViews = () => {
        dashboardContainer.classList.remove('hidden');
        uploaderModal.classList.add('hidden');
        mainDashboardView.classList.add('hidden');
        cityView.classList.add('hidden');
        boxesView.classList.add('hidden');
        branchView.classList.add('hidden');
        comparisonView.classList.add('hidden');
        if (innovationsMonthView) innovationsMonthView.classList.add('hidden');
        if (lojaPerfeitaView) lojaPerfeitaView.classList.add('hidden');
        if (estrelasView) estrelasView.classList.add('hidden');
        if (agendaView) agendaView.classList.add('hidden');
    };

    async function renderView(view, options = {}) {
        // Push to history if not navigating back
        if (!options.skipHistory && currentActiveView && currentActiveView !== view) {
            viewHistory.push(currentActiveView);
        }
        currentActiveView = view;

        // Sync Hash to ensure navigation consistency
        try {
            if (window.location.hash !== '#' + view) {
                history.pushState(null, null, '#' + view);
            }
        } catch (e) {
            AppLog.warn("App [Navigation]: History pushState failed", e);
        }

        resetViews();

        switch (view) {
            case 'dashboard':
                mainDashboardView.classList.remove('hidden');
                setActiveNavLink(navDashboardBtn);
                if (!isMainDashboardInitialized) {
                    initDashboard();
                }
                break;
            case 'city':
                cityView.classList.remove('hidden');
                setActiveNavLink(navCityAnalysisBtn);
                loadCityView();
                break;
            case 'boxes':
                if (boxesView && navBoxesBtn) {
                    boxesView.classList.remove('hidden');
                    setActiveNavLink(navBoxesBtn);
                    loadBoxesView();
                }
                break;
            case 'comparison':
                if (comparisonView && navComparativoBtn) {
                    comparisonView.classList.remove('hidden');
                    setActiveNavLink(navComparativoBtn);
                    loadComparisonView();
                }
                break;
            case 'innovations':
                if (innovationsMonthView && navInnovationsBtn) {
                    window.showDashboardLoading('innovations-month-view');
                    innovationsMonthView.classList.remove('hidden');
                    setActiveNavLink(navInnovationsBtn);
                    renderInnovationsMonthView();
                }
                break;
                        case 'estrelas':
                if (estrelasView && navEstrelasBtn) {
                    window.showDashboardLoading('estrelas-view');
                    estrelasView.classList.remove('hidden');
                    setActiveNavLink(navEstrelasBtn);
                    renderEstrelasView();
                }
                break;
            case 'agenda':
                if (agendaView && navAgendaBtn) {
                    window.showDashboardLoading('agenda-view');
                    agendaView.classList.remove('hidden');
                    setActiveNavLink(navAgendaBtn);
                    renderAgendaView();
                }
                break;
            case 'loja-perfeita':
                if (lojaPerfeitaView && navLojaPerfeitaBtn) {
                    window.showDashboardLoading('loja-perfeita-view');
                    lojaPerfeitaView.classList.remove('hidden');
                    setActiveNavLink(navLojaPerfeitaBtn);
                    renderLojaPerfeitaView();
                }
                break;
            case 'branch':
                if (branchView && navBranchBtn) {
                    branchView.classList.remove('hidden');
                    setActiveNavLink(navBranchBtn);
                    loadBranchView();
                }
                break;
            default:
                mainDashboardView.classList.remove('hidden');
                setActiveNavLink(navDashboardBtn);
                if (!isMainDashboardInitialized) {
                    initDashboard();
                }
                break;
        }
    }

    navDashboardBtn.addEventListener('click', (e) => {
        if (handleActiveLinkClick(e, navDashboardBtn, 'dashboard')) return;
        if (navigateWithCtrl(e, 'dashboard')) return;
        renderView('dashboard');
    });

    navCityAnalysisBtn.addEventListener('click', (e) => {
        if (handleActiveLinkClick(e, navCityAnalysisBtn, 'city')) return;
        if (navigateWithCtrl(e, 'city')) return;
        renderView('city');
    });

    if (navBoxesBtn) {
        navBoxesBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navBoxesBtn, 'boxes')) return;
            if (navigateWithCtrl(e, 'boxes')) return;
            renderView('boxes');
        });
    }

    if (navComparativoBtn) {
        navComparativoBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navComparativoBtn, 'comparison')) return;
            if (navigateWithCtrl(e, 'comparison')) return;
            renderView('comparison');
        });
    }

    if (navBranchBtn) {
        navBranchBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navBranchBtn, 'branch')) return;
            if (navigateWithCtrl(e, 'branch')) return;
            renderView('branch');
        });
    }

    if (navInnovationsBtn) {
        navInnovationsBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navInnovationsBtn, 'innovations')) return;
            if (navigateWithCtrl(e, 'innovations')) return;
            renderView('innovations');
        });
    }

    if (navEstrelasBtn) {
        navEstrelasBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navEstrelasBtn, 'estrelas')) return;
            if (navigateWithCtrl(e, 'estrelas')) return;
            renderView('estrelas');
        });
    }

    if (navAgendaBtn) {
        navAgendaBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navAgendaBtn, 'agenda')) return;
            if (navigateWithCtrl(e, 'agenda')) return;
            renderView('agenda');
        });
    }

    if (navLojaPerfeitaBtn) {
        navLojaPerfeitaBtn.addEventListener('click', (e) => {
            if (handleActiveLinkClick(e, navLojaPerfeitaBtn, 'lojaperfeita')) return;
            if (navigateWithCtrl(e, 'loja-perfeita')) return;
            renderView('loja-perfeita');
        });
    }

    if (navUploaderBtn) {
        navUploaderBtn.addEventListener('click', () => {
            if (window.userRole !== 'adm') {
                window.showToast('error', 'Acesso negado: Apenas administradores podem acessar o uploader.');
                return;
            }
            uploaderModal.classList.remove('hidden');
            checkMissingBranches();
        });
    }

    if (optimizeDbBtnNav) {
        optimizeDbBtnNav.addEventListener('click', async () => {
            if (window.userRole !== 'adm') return;
            if (!confirm('Recriar índices do banco de dados?')) return;
            
            try {
                const { data, error } = await supabase.rpc('optimize_database');
                if (error) throw error;
                window.showToast('success', data || 'Otimização concluída!');
            } catch(e) { 
                window.showToast('error', 'Erro: ' + e.message);
            }
        });
    }

    closeUploaderBtn.addEventListener('click', () => {
        uploaderModal.classList.add('hidden');
    });

    // Role Check for Uploader Visibility
    function checkRoleForUI() {
        if (window.userRole === 'adm') {
            if(navUploaderBtn) navUploaderBtn.classList.remove('hidden');
            if(navUploaderBtn) navUploaderBtn.classList.add('flex');
            if(optimizeDbBtnNav) optimizeDbBtnNav.classList.remove('hidden');
            if(optimizeDbBtnNav) optimizeDbBtnNav.classList.add('flex');
        } else {
            if(navUploaderBtn) navUploaderBtn.classList.add('hidden');
            if(navUploaderBtn) navUploaderBtn.classList.remove('flex');
            if(optimizeDbBtnNav) optimizeDbBtnNav.classList.add('hidden');
            if(optimizeDbBtnNav) optimizeDbBtnNav.classList.remove('flex');
        }
    }


    // --- Dashboard Internal Navigation ---
    if (chartToggleBtn) {
        chartToggleBtn.addEventListener('click', () => {
            currentChartMode = currentChartMode === 'faturamento' ? 'peso' : 'faturamento';
            if (lastDashboardData) {
                renderDashboard(lastDashboardData);
            }
        });
    }

    clearFiltersBtn.addEventListener('click', async () => {
        // Reset Single Selects
        anoFilter.value = 'todos';
        anoFilter.dispatchEvent(new Event('change', { bubbles: true }));
        mesFilter.value = '';
        mesFilter.dispatchEvent(new Event('change', { bubbles: true }));

        // Update custom dropdown visual text
        if (anoFilter.nextElementSibling && anoFilter.nextElementSibling.tagName === 'BUTTON') {
            const span = anoFilter.nextElementSibling.querySelector('span');
            if (span) span.textContent = 'Todos';
        }
        if (mesFilter.nextElementSibling && mesFilter.nextElementSibling.tagName === 'BUTTON') {
            const span = mesFilter.nextElementSibling.querySelector('span');
            if (span) span.textContent = 'Todos';
        }

        // Reset Multi Select Arrays
        selectedFiliais = [];
        selectedCidades = [];
        selectedSupervisores = [];
        selectedVendedores = [];
        selectedFornecedores = [];
        selectedTiposVenda = [];
        selectedRedes = [];
        selectedCategorias = [];

        // Note: loadFilters will re-render the dropdowns with checked status based on these empty arrays,
        // effectively clearing the checkboxes visually.
        
        await loadFilters(getCurrentFilters());
        loadMainDashboardData();
    });

    // --- Calendar Modal Logic ---
    function openCalendar() {
        calendarModal.classList.remove('hidden');
        renderCalendar();
    }

    function closeCalendar() {
        calendarModal.classList.add('hidden');
    }

    if(calendarBtn) calendarBtn.addEventListener('click', openCalendar);
    if(comparisonHolidayPickerBtn) comparisonHolidayPickerBtn.addEventListener('click', openCalendar);
    if(closeCalendarModalBtn) closeCalendarModalBtn.addEventListener('click', closeCalendar);
    if(calendarModalBackdrop) calendarModalBackdrop.addEventListener('click', closeCalendar);


    // --- Uploader Logic ---
    let files = {};
    const checkFiles = () => {
        const hasFiles = files.salesCurrMonthFile && files.clientsFile;
        generateBtn.disabled = !hasFiles;
    };

    const toggleOptionalFilesBtn = document.getElementById('toggle-optional-files-btn');
    const optionalFilesContainer = document.getElementById('optional-files-container');
    const optionalFilesIcon = document.getElementById('optional-files-icon');

    if (toggleOptionalFilesBtn) {
        toggleOptionalFilesBtn.addEventListener('click', () => {
            const isHidden = optionalFilesContainer.classList.contains('hidden');
            if (isHidden) {
                optionalFilesContainer.classList.remove('hidden');
                optionalFilesIcon.classList.add('rotate-90');
                toggleOptionalFilesBtn.setAttribute('aria-expanded', 'true');
            } else {
                optionalFilesContainer.classList.add('hidden');
                optionalFilesIcon.classList.remove('rotate-90');
                toggleOptionalFilesBtn.setAttribute('aria-expanded', 'false');
            }

        });
    }

    const innovationsFileInput = document.getElementById('innovations-file-input');
    const notaInvolvesMultipleInput = document.getElementById('nota-involves-multiple-input');
    const metaEstrelasInput = document.getElementById('meta-estrelas-input');
    const metaEstrelasPeriodo = document.getElementById('meta-estrelas-periodo');
    const metaEstrelasMes = document.getElementById('meta-estrelas-mes');
    const metaEstrelasAno = document.getElementById('meta-estrelas-ano');

    if(salesPrevYearInput) salesPrevYearInput.addEventListener('change', (e) => { files.salesPrevYearFile = e.target.files[0]; checkFiles(); });
    if(salesCurrYearInput) salesCurrYearInput.addEventListener('change', (e) => { files.salesCurrYearFile = e.target.files[0]; checkFiles(); });
    if(salesCurrMonthInput) salesCurrMonthInput.addEventListener('change', (e) => { files.salesCurrMonthFile = e.target.files[0]; checkFiles(); });
    if(clientsFileInput) clientsFileInput.addEventListener('change', (e) => { files.clientsFile = e.target.files[0]; checkFiles(); });
    if(productsFileInput) productsFileInput.addEventListener('change', (e) => { files.productsFile = e.target.files[0]; checkFiles(); });
    if(innovationsFileInput) innovationsFileInput.addEventListener('change', (e) => { files.innovationsFile = e.target.files[0]; checkFiles(); });
    
    if(notaInvolvesMultipleInput) notaInvolvesMultipleInput.addEventListener('change', (e) => {
        files.notaInvolvesFile1 = e.target.files.length > 0 ? e.target.files[0] : null;
        files.notaInvolvesFile2 = e.target.files.length > 1 ? e.target.files[1] : null;
        checkFiles();
    });

    if (metaEstrelasInput) {
        metaEstrelasInput.addEventListener('change', (e) => {
            files.metaEstrelasFile = e.target.files[0];
            if (e.target.files[0]) {
                metaEstrelasPeriodo.classList.remove('hidden');
                files.metaEstrelasMes = metaEstrelasMes.value;
                files.metaEstrelasAno = metaEstrelasAno.value;
            } else {
                metaEstrelasPeriodo.classList.add('hidden');
                delete files.metaEstrelasMes;
                delete files.metaEstrelasAno;
            }
            checkFiles();
        });
    }
    if (metaEstrelasMes) metaEstrelasMes.addEventListener('change', (e) => { files.metaEstrelasMes = e.target.value; });
    if (metaEstrelasAno) metaEstrelasAno.addEventListener('change', (e) => { files.metaEstrelasAno = e.target.value; });

    if(optimizeDbBtn) optimizeDbBtn.addEventListener('click', async () => {
        if (window.userRole !== 'adm') {
            window.showToast('error', 'Apenas administradores podem executar esta ação.');
            return;
        }
        if (!confirm('Recriar índices do banco de dados?')) return;

        optimizeDbBtn.disabled = true;
        optimizeDbBtn.textContent = 'Otimizando...';
        statusContainer.classList.remove('hidden');
        statusText.textContent = 'Otimizando...';
        progressBar.style.width = '50%';

        try {
            const { data, error } = await supabase.rpc('optimize_database');
            if (error) throw error;
            statusText.textContent = data || 'Concluído!';
            progressBar.style.width = '100%';
            window.showToast('success', data);
        } catch (e) {
            statusText.textContent = 'Erro: ' + e.message;
            window.showToast('error', 'Erro: ' + e.message);
        } finally {
            optimizeDbBtn.disabled = false;
            optimizeDbBtn.textContent = 'Otimizar Banco de Dados (Reduzir Espaço)';
            setTimeout(() => { statusContainer.classList.add('hidden'); }, 5000);
        }
    });

    // --- Config City Branches Logic ---
    async function fetchCityBranchMap() {
        const { data, error } = await supabase.from('config_city_branches').select('cidade, filial');
        if (error) {
            AppLog.error("Erro ao buscar mapa de cidades:", error);
            return {};
        }
        const map = {};
        data.forEach(item => {
            if (item.cidade) map[item.cidade.toUpperCase()] = item.filial;
        });
        return map;
    }

    async function checkMissingBranches() {
        const { data, error } = await supabase
            .from('config_city_branches')
            .select('cidade')
            .or('filial.is.null,filial.eq.""');
        
        if (!error && data && data.length > 0) {
            missingBranchesNotification.classList.remove('hidden');
        } else {
            missingBranchesNotification.classList.add('hidden');
        }
    }

    // O evento click de navUploaderBtn já foi declarado mais acima com a estrutura do nav.
    // Vamos apenas assegurar de mesclar a chamada de checkMissingBranches() que havia aqui.

    if(generateBtn) generateBtn.addEventListener('click', async () => {
        if (!files.salesCurrMonthFile || !files.clientsFile) return;

        generateBtn.disabled = true;
        statusContainer.classList.remove('hidden');
        statusText.textContent = 'Carregando configurações...';
        progressBar.style.width = '2%';

        // Fetch current city map
        const cityBranchMap = await fetchCityBranchMap();

        statusText.textContent = 'Processando...';
        
        const worker = new Worker('src/js/worker.js?v=4');
        // Pass files AND the city map
        worker.postMessage({ ...files, cityBranchMap });

        worker.onmessage = async (event) => {
            const { type, data, status, percentage, message } = event.data;
            if (type === 'progress') {
                statusText.textContent = status;
                progressBar.style.width = `${percentage}%`;
            } else if (type === 'result') {
                statusText.textContent = 'Upload...';
                try {
                    // 1. Insert New Cities if any
                    if (data.newCities && data.newCities.length > 0) {
                        statusText.textContent = 'Atualizando Cidades...';
                        const newCityBatch = data.newCities.map(c => ({ cidade: c, filial: null })); // Insert with null filial
                        // Use upsert to avoid conflicts if logic overlaps
                        const { error: cityErr } = await supabase.from('config_city_branches').upsert(newCityBatch, { onConflict: 'cidade', ignoreDuplicates: true });
                        if (cityErr) AppLog.warn('Erro ao inserir novas cidades:', cityErr);
                    }

                    await enviarDadosParaSupabase(data);
                    
                    // Re-check missing branches after upload
                    await checkMissingBranches();

                    statusText.textContent = 'Sucesso!';
                    progressBar.style.width = '100%';
                    setTimeout(() => {
                        uploaderModal.classList.add('hidden');
                        statusContainer.classList.add('hidden');
                        generateBtn.disabled = false;
                        window.showToast('success', 'Dados atualizados com sucesso!', 'Sucesso');
                        initDashboard();
                    }, 1500);
                } catch (e) {
                    statusText.innerHTML = '';
                    const span = document.createElement('span');
                    span.className = 'text-red-500';
                    span.textContent = `Erro: ${e.message}`;
                    statusText.appendChild(span);
                    generateBtn.disabled = false;
                }
            } else if (type === 'error') {
                statusText.innerHTML = '';
                const span = document.createElement('span');
                span.className = 'text-red-500';
                span.textContent = `Erro: ${message}`;
                statusText.appendChild(span);
                generateBtn.disabled = false;
            }
        };
    });

    async function enviarDadosParaSupabase(data) {
        const updateStatus = (msg, percent) => {
            statusText.textContent = msg;
            progressBar.style.width = `${percent}%`;
        };

        const retryOperation = async (operation, retries = 3, delay = 1000) => {
            for (let i = 0; i < retries; i++) {
                try {
                    return await operation();
                } catch (error) {
                    if (i === retries - 1) throw error;
                    AppLog.warn(`Tentativa ${i + 1} falhou. Retentando em ${delay}ms...`, error);
                    await new Promise(resolve => setTimeout(resolve, delay));
                    delay *= 2; // Exponential backoff
                }
            }
        };

        const performUpsert = async (table, batch) => {
            await retryOperation(async () => {
                let error;
                if (table === 'data_clients') {
                    // Use Upsert for clients to handle updates gracefully and avoid unique constraint errors
                    const { error: upsertErr } = await supabase.from(table).upsert(batch, { onConflict: 'codigo_cliente' });
                    error = upsertErr;
                } else {
                    const { error: insertErr } = await supabase.from(table).insert(batch);
                    error = insertErr;
                }
                
                if (error) {
                    if (error.code === '42P01') {
                        throw new Error(`Tabela '${table}' não encontrada. Por favor, execute o script SQL de atualização (full_system_v1.sql) no painel do Supabase antes de enviar os arquivos.`);
                    }
                    throw new Error(`Erro ${table}: ${error.message}`);
                }
            });
        };
        const performDimensionUpsert = async (table, batch) => {
             await retryOperation(async () => {
                 const { error } = await supabase.from(table).upsert(batch, { onConflict: 'codigo' });
                 if (error) {
                     if (error.message && (error.message.includes('Could not find the table') || error.message.includes('relation') || error.code === '42P01')) {
                         window.showToast('error', "Erro de Configuração: As tabelas novas (dimensões) não foram encontradas. \n\nPor favor, execute o script 'sql/optimization_plan.sql' no Editor SQL do Supabase para criar as tabelas necessárias e tente novamente.");
                     }
                     throw new Error(`Erro upsert ${table}: ${error.message}`);
                 }
             });
        };
        const clearTable = async (table) => {
            await retryOperation(async () => {
                const { error } = await supabase.rpc('truncate_table', { table_name: table });
                if (error) throw new Error(`Erro clear ${table}: ${error.message}`);
            });
        };

        // Reduced Batch Size to avoid 60s timeout during heavy inserts
        const BATCH_SIZE = 500;
        const CONCURRENT_REQUESTS = 3;

        const uploadBatch = async (table, items) => {
            const totalBatches = Math.ceil(items.length / BATCH_SIZE);
            let processedBatches = 0;
            const processChunk = async (chunkIndex) => {
                const start = chunkIndex * BATCH_SIZE;
                const end = start + BATCH_SIZE;
                const batch = items.slice(start, end);
                await performUpsert(table, batch);
                processedBatches++;
                // Progress handled by main sync loop
            };
             const queue = Array.from({ length: totalBatches }, (_, i) => i);
             const worker = async () => {
                 while (queue.length > 0) {
                     const chunkIndex = queue.shift();
                     await processChunk(chunkIndex);
                 }
             };
             await Promise.all(Array.from({ length: Math.min(CONCURRENT_REQUESTS, totalBatches) }, worker));
        };

        // --- Incremental Sync Logic (Chunked for Sales, Row-Hash for Clients) ---
        
        // Sync Logic for Sales (Metadata + Chunking + Batched HTTP Requests)
        const syncSalesChunks = async (tableName, localChunks, progressStart, progressEnd) => {
            updateStatus(`Verificando metadados de ${tableName}...`, progressStart);

            // 1. Get Server Metadata
            const { data: serverMeta, error: metaErr } = await supabase.from('data_metadata').select('chunk_key, chunk_hash').eq('table_name', tableName);
            if (metaErr) throw new Error(`Erro metadados ${tableName}: ${metaErr.message}`);

            const serverMap = new Map();
            if (serverMeta) {
                serverMeta.forEach(m => serverMap.set(m.chunk_key, m.chunk_hash));
            }

            const localKeys = Object.keys(localChunks);
            const totalChunks = localKeys.length;
            let processedChunks = 0;

            AppLog.log(`[${tableName}] Total Chunks: ${totalChunks}`);

            // 2. Iterate Chunks
            for (const key of localKeys) {
                const localChunk = localChunks[key];
                const serverHash = serverMap.get(key);

                if (serverHash !== localChunk.hash) {
                    AppLog.log(`[${tableName}] Syncing chunk ${key} (Size: ${localChunk.rows.length})...`);
                    updateStatus(`Sincronizando ${tableName} (${key})...`, progressStart + Math.floor((processedChunks / totalChunks) * (progressEnd - progressStart)));
                    
                    // --- GRANULAR UPLOAD STRATEGY ---
                    // 1. Wipe Data for Month
                    const { error: wipeErr } = await supabase.rpc('begin_sync_chunk', {
                        p_table_name: tableName,
                        p_chunk_key: key
                    });
                    if (wipeErr) throw new Error(`Erro WIPE chunk ${key}: ${wipeErr.message}`);

                    // 2. Batch Append (e.g. 2000 rows per request to avoid Gateway Timeouts)
                    const ROWS_PER_REQUEST = 2000;
                    const CONCURRENCY_LIMIT = 3;
                    const totalRows = localChunk.rows.length;
                    
                    let activePromises = [];
                    for (let i = 0; i < totalRows; i += ROWS_PER_REQUEST) {
                        const batch = localChunk.rows.slice(i, i + ROWS_PER_REQUEST);

                        const uploadTask = retryOperation(async () => {
                            const { error: appendErr } = await supabase.rpc('append_sync_chunk', {
                                p_table_name: tableName,
                                p_rows: batch
                            });
                            if (appendErr) throw new Error(`Erro APPEND chunk ${key} batch ${i}: ${appendErr.message}`);
                        });

                        activePromises.push(uploadTask);

                        // Wait if we hit concurrency limit
                        if (activePromises.length >= CONCURRENCY_LIMIT) {
                            await Promise.all(activePromises);
                            activePromises = [];
                            // Update progress after batch completes
                            const progress = Math.round((Math.min(i + ROWS_PER_REQUEST, totalRows) / totalRows) * 100);
                            updateStatus(`Enviando ${tableName} (${key}): ${progress}%`, progressStart + Math.floor((processedChunks / totalChunks) * (progressEnd - progressStart)));
                        }
                    }

                    // Await any remaining promises
                    if (activePromises.length > 0) {
                        await Promise.all(activePromises);
                        updateStatus(`Enviando ${tableName} (${key}): 100%`, progressStart + Math.floor((processedChunks / totalChunks) * (progressEnd - progressStart)));
                    }

                    // 3. Commit/Finalize
                    const { error: commitErr } = await supabase.rpc('commit_sync_chunk', {
                        p_table_name: tableName,
                        p_chunk_key: key,
                        p_hash: localChunk.hash
                    });
                    if (commitErr) throw new Error(`Erro COMMIT chunk ${key}: ${commitErr.message}`);

                } else {
                    AppLog.log(`[${tableName}] Chunk ${key} is up-to-date.`);
                }
                processedChunks++;
            }
            updateStatus(`${tableName} sincronizada.`, progressEnd);
        };

        // Legacy Row-Hash Sync (Kept for Clients)
        const syncTable = async (tableName, clientRows, progressStart, progressEnd) => {
            updateStatus(`Sincronizando ${tableName}...`, progressStart);
            
            // 1. Get Server Hashes
            const { data: serverHashes, error } = await supabase.rpc('get_table_hashes', { p_table_name: tableName });
            if (error) throw new Error(`Erro ao buscar hashes de ${tableName}: ${error.message}`);
            
            const serverHashSet = new Set(serverHashes.map(h => h.row_hash));
            const clientHashMap = new Map();
            clientRows.forEach(r => {
                if (r.row_hash) clientHashMap.set(r.row_hash, r);
            });

            // 2. Identify Diffs
            const toInsert = [];
            clientHashMap.forEach((row, hash) => {
                if (!serverHashSet.has(hash)) {
                    toInsert.push(row);
                }
            });

            const toDeleteHashes = [];
            serverHashes.forEach(sh => {
                if (!clientHashMap.has(sh.row_hash)) {
                    toDeleteHashes.push(sh.row_hash);
                }
            });

            AppLog.log(`[${tableName}] Total Client: ${clientRows.length}, Total Server: ${serverHashes.length}`);
            AppLog.log(`[${tableName}] To Insert: ${toInsert.length}, To Delete: ${toDeleteHashes.length}, Unchanged: ${serverHashSet.size - toDeleteHashes.length}`);

            // 3. Perform Deletes (Batch RPC)
            if (toDeleteHashes.length > 0) {
                updateStatus(`Removendo ${toDeleteHashes.length} registros obsoletos de ${tableName}...`, progressStart + 2);
                // Batch deletes to avoid huge payload issues
                const DELETE_BATCH = 5000;
                const totalBatches = Math.ceil(toDeleteHashes.length / DELETE_BATCH);
                const queue = Array.from({ length: totalBatches }, (_, i) => i);

                const worker = async () => {
                    while (queue.length > 0) {
                        const batchIndex = queue.shift();
                        const start = batchIndex * DELETE_BATCH;
                        const end = start + DELETE_BATCH;
                        const batch = toDeleteHashes.slice(start, end);

                        const { error: delErr } = await supabase.rpc('delete_by_hashes', { p_table_name: tableName, p_hashes: batch });
                        if (delErr) throw new Error(`Erro ao deletar de ${tableName}: ${delErr.message}`);
                    }
                };

                await Promise.all(Array.from({ length: Math.min(CONCURRENT_REQUESTS, totalBatches) }, worker));
            }

            // 4. Perform Inserts (Using existing uploadBatch logic)
            if (toInsert.length > 0) {
                updateStatus(`Inserindo ${toInsert.length} novos registros em ${tableName}...`, progressStart + 5);
                await uploadBatch(tableName, toInsert);
            } else {
                updateStatus(`${tableName} já está atualizado.`, progressEnd);
            }
        };

        try {
            // 0. Update Dimensions First
            if (data.newSupervisors && data.newSupervisors.length > 0) {
                 updateStatus('Atualizando Supervisores...', 1);
                 await performDimensionUpsert('dim_supervisores', data.newSupervisors);
            }
            if (data.newProducts && data.newProducts.length > 0) {
                 updateStatus('Atualizando Produtos...', 1);
                 await performDimensionUpsert('dim_produtos', data.newProducts);
            }
            if (data.newVendors && data.newVendors.length > 0) {
                 updateStatus('Atualizando Vendedores...', 2);
                 await retryOperation(async () => {
                     const { error } = await supabase.rpc('upsert_dim_vendedores', { p_vendors: data.newVendors });
                     if (error) throw new Error('Erro ao atualizar dim_vendedores: ' + error.message);
                 });
            }
            if (data.newProviders && data.newProviders.length > 0) {
                 updateStatus('Atualizando Fornecedores...', 3);
                 await performDimensionUpsert('dim_fornecedores', data.newProviders);
            }
            if (data.productStock && data.productStock.length > 0) {
                 updateStatus('Atualizando Estoque de Produtos...', 4);
                 await retryOperation(async () => {
                     const { error } = await supabase.rpc('update_products_stock', { p_stock_data: data.productStock });
                     if (error) throw new Error('Erro ao atualizar estoque_filial: ' + error.message);
                 });
            }

            // Sales Tables (Use Chunk Sync)
            if (data.historyChunks) await syncSalesChunks('data_history', data.historyChunks, 10, 40);
            if (data.detailedChunks) await syncSalesChunks('data_detailed', data.detailedChunks, 40, 70);
            
            // Clients Table (Use Row Sync)
            if (data.clients) await syncTable('data_clients', data.clients, 70, 75);

            // New Tables
            if (data.innovations && data.innovations.length > 0) {
                updateStatus('Atualizando Inovações...', 76);
                await clearTable('data_innovations');
                await uploadBatch('data_innovations', data.innovations);
            }
            if (data.notaPerfeita && data.notaPerfeita.length > 0) {
                updateStatus('Atualizando Nota Involves...', 78);
                await clearTable('data_nota_perfeita');
                await uploadBatch('data_nota_perfeita', data.notaPerfeita);
            }

            if (data.metaEstrelas && data.metaEstrelas.length > 0) {
                updateStatus('Atualizando Metas Estrelas...', 79);
                const { error: meErr } = await supabase.from('meta_estrelas').upsert(data.metaEstrelas, { onConflict: 'filial, cod_rca, mes, ano' });
                if (meErr) throw new Error(`Erro Metas Estrelas: ${meErr.message}`);
            }

            // CHUNKED CACHE REFRESH LOGIC
            updateStatus('Iniciando processamento do resumo...', 80);
            
            // 1. Explicitly clear Summary Table
            await clearTable('data_summary');
            await clearTable('data_summary_frequency');

            // 2. Get Years
            const { data: years, error: yearErr } = await supabase.rpc('get_available_years');
            if (yearErr) throw new Error(`Erro ao buscar anos: ${yearErr.message}`);

            if (years && years.length > 0) {
                // 2.5 Batch clear all months concurrently to improve throughput
                updateStatus('Limpando dados antigos...', 80);
                const clearPromises = [];
                for (let i = 0; i < years.length; i++) {
                    const year = years[i];
                    for (let m = 1; m <= 12; m++) {
                        clearPromises.push(
                            supabase.rpc('clear_summary_month', { p_year: year, p_month: m })
                                .then(({ error }) => {
                                    if (error) throw new Error(`Erro limpando ${m}/${year}: ${error.message}`);
                                })
                        );
                    }
                }
                await Promise.all(clearPromises);

                // 3. Loop and Process Each Year and Month (Granular to avoid timeout)
                for (let i = 0; i < years.length; i++) {
                    const year = years[i];
                    for (let m = 1; m <= 12; m++) {
                        // Calculate progress
                        const yearStep = 15 / years.length;
                        const monthStep = yearStep / 12;
                        const progress = 80 + Math.round((i * yearStep) + (m * monthStep));

                        // Calculate date boundaries
                        const startDate = `${year}-${String(m).padStart(2, '0')}-01`;
                        const chunk1EndDate = `${year}-${String(m).padStart(2, '0')}-11`;
                        const chunk2EndDate = `${year}-${String(m).padStart(2, '0')}-21`;
                        let nextMonth = m + 1;
                        let nextYear = year;
                        if (nextMonth > 12) {
                            nextMonth = 1;
                            nextYear++;
                        }
                        const endDate = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

                        updateStatus(`Processando ${m}/${year} (Partes 1-3)...`, progress + Math.round(monthStep * 0.20));
                        await retryOperation(async () => {
                            const res1 = await supabase.rpc('refresh_summary_chunk', { p_start_date: startDate, p_end_date: chunk1EndDate });
                            if (res1.error) throw new Error(`Erro processando ${m}/${year} (Parte 1): ${res1.error.message}`);
                        }, 3, 2000);

                        await retryOperation(async () => {
                            const res2 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk1EndDate, p_end_date: chunk2EndDate });
                            if (res2.error) throw new Error(`Erro processando ${m}/${year} (Parte 2): ${res2.error.message}`);
                        }, 3, 2000);

                        await retryOperation(async () => {
                            const res3 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk2EndDate, p_end_date: endDate });
                            if (res3.error) throw new Error(`Erro processando ${m}/${year} (Parte 3): ${res3.error.message}`);
                        }, 3, 2000);

                        // Atualiza o cache de filtros apenas para o mês que acabou de ser processado para evitar timeout
                        updateStatus(`Atualizando filtros ${m}/${year}...`, progress + Math.round(monthStep * 0.90));
                        await retryOperation(async () => {
                            const { error: filterErr } = await supabase.rpc('refresh_cache_filters', { p_ano: year, p_mes: m });
                            if (filterErr) throw new Error(`Erro atualizando filtros ${m}/${year}: ${filterErr.message}`);
                        }, 3, 2000);
                    }
                }

                updateStatus('Finalizando...', 98);
            }


        } catch (error) {
            AppLog.error(error);
            throw error;
        }
    }

    // --- Dashboard Data Logic ---


    // Boxes Logic
    let boxesFilterDebounceTimer;
    let boxesSelectedFiliais = [];
    let boxesSelectedCidades = [];
    let boxesSelectedSupervisores = [];
    let boxesSelectedVendedores = [];
    let boxesSelectedFornecedores = [];
    let boxesSelectedProducts = [];
    let boxesSelectedTiposVenda = [];
    let boxesSelectedCategorias = [];
    let boxesTrendActive = false; // State for Trend Toggle

    const handleBoxesFilterChange = async () => {
        clearTimeout(boxesFilterDebounceTimer);
        boxesFilterDebounceTimer = setTimeout(async () => {
            const viewFilters = {
                p_filial: boxesSelectedFiliais.length > 0 ? boxesSelectedFiliais : null,
                p_cidade: boxesSelectedCidades.length > 0 ? boxesSelectedCidades : null,
                p_supervisor: boxesSelectedSupervisores.length > 0 ? boxesSelectedSupervisores : null,
                p_vendedor: boxesSelectedVendedores.length > 0 ? boxesSelectedVendedores : null,
                p_fornecedor: boxesSelectedFornecedores.length > 0 ? boxesSelectedFornecedores : null,
                p_produto: boxesSelectedProducts.length > 0 ? boxesSelectedProducts : null,
                p_tipovenda: boxesSelectedTiposVenda.length > 0 ? boxesSelectedTiposVenda : null,
                p_categoria: boxesSelectedCategorias.length > 0 ? boxesSelectedCategorias : null,
                p_ano: boxesAnoFilter.value === 'todos' ? null : boxesAnoFilter.value,
                p_mes: boxesMesFilter.value === '' ? null : boxesMesFilter.value
            };

            // Filters for dropdowns should NOT include the product itself to avoid signature mismatch
            // and usually we don't want selecting a product to filter the other dropdowns backwards in this context.
            const { p_produto, ...dropdownFilters } = viewFilters;
            
            await loadBoxesFilters(dropdownFilters);
            await loadBoxesView();
        }, 500);
    };

    async function loadBoxesFilters(currentFilters) {
        // Exclude p_produto from filter fetch to prevent self-filtering if that's desired behavior?
        // Usually dependent filters (Supplier -> Product) mean selection in Supplier narrows Product.
        // But selection in Product shouldn't necessarily narrow Supplier in a way that hides the current selection?
        // For now, pass all filters as is standard.
        
        const { data, error } = await supabase.rpc('get_dashboard_filters', currentFilters);
        if (error) {
            AppLog.error('Error refreshing boxes filters:', error);
            return;
        }

        if (data) {
             // Update Dropdowns (Re-render options)
             // Note: We do NOT reset the selected arrays here, we just re-render the available options.
             // If a selected item is no longer in the returned data, it remains in the selected array (logic in setupCityMultiSelect handles check status based on array)
             // However, visually it won't be in the list.

             setupCityMultiSelect(boxesFilialFilterBtn, boxesFilialFilterDropdown, boxesFilialFilterDropdown, data.filiais, boxesSelectedFiliais);
             setupCityMultiSelect(boxesSupervisorFilterBtn, boxesSupervisorFilterDropdown, boxesSupervisorFilterDropdown, data.supervisors, boxesSelectedSupervisores);
             setupCityMultiSelect(boxesVendedorFilterBtn, boxesVendedorFilterDropdown, boxesVendedorFilterList, data.vendedores, boxesSelectedVendedores, boxesVendedorFilterSearch);
             setupCityMultiSelect(boxesFornecedorFilterBtn, boxesFornecedorFilterDropdown, boxesFornecedorFilterList, data.fornecedores, boxesSelectedFornecedores, boxesFornecedorFilterSearch, true);
             setupCityMultiSelect(boxesCidadeFilterBtn, boxesCidadeFilterDropdown, boxesCidadeFilterList, data.cidades, boxesSelectedCidades, boxesCidadeFilterSearch);
             setupCityMultiSelect(boxesProdutoFilterBtn, boxesProdutoFilterDropdown, boxesProdutoFilterList, data.produtos || [], boxesSelectedProducts, boxesProdutoFilterSearch, true);
             setupCityMultiSelect(boxesTipovendaFilterBtn, boxesTipovendaFilterDropdown, boxesTipovendaFilterDropdown, data.tipos_venda || [], boxesSelectedTiposVenda);
             setupCityMultiSelect(boxesCategoriaFilterBtn, boxesCategoriaFilterDropdown, boxesCategoriaFilterList, data.categorias || [], boxesSelectedCategorias, boxesCategoriaFilterSearch);
        }
    }

    if (boxesAnoFilter) boxesAnoFilter.addEventListener('change', handleBoxesFilterChange);
    if (boxesMesFilter) boxesMesFilter.addEventListener('change', handleBoxesFilterChange);

    if (boxesTrendToggleBtn) {
        boxesTrendToggleBtn.addEventListener('click', () => {
            boxesTrendActive = !boxesTrendActive;
            const span = document.getElementById('boxes-trend-text');
            
            if (boxesTrendActive) {
                boxesTrendToggleBtn.classList.remove('text-orange-500', 'hover:text-orange-400');
                boxesTrendToggleBtn.classList.add('text-purple-500', 'hover:text-purple-400');
                if (span) span.textContent = 'Ver Realizado';
            } else {
                boxesTrendToggleBtn.classList.remove('text-purple-500', 'hover:text-purple-400');
                boxesTrendToggleBtn.classList.add('text-orange-500', 'hover:text-orange-400');
                if (span) span.textContent = 'Calcular Tendência';
            }
            
            // Re-render only (data already has trend info if RPC updated)
            // But we need to make sure we have the data. 
            // Ideally we re-fetch if we suspect cache is stale, but usually RPC returns trend info always if available.
            // Let's just re-render first.
            loadBoxesView(); 
        });
    }

    // Boxes Export Logic
    let currentBoxesTableData = [];

    if (boxesExportBtn) {
        boxesExportBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            boxesExportDropdown.classList.toggle('hidden');
        });
    }

    if (boxesExportExcelBtn) {
        boxesExportExcelBtn.addEventListener('click', () => {
            exportBoxesTable('excel');
            boxesExportDropdown.classList.add('hidden');
        });
    }

    if (boxesExportPdfBtn) {
        boxesExportPdfBtn.addEventListener('click', () => {
            exportBoxesTable('pdf');
            boxesExportDropdown.classList.add('hidden');
        });
    }

    function exportBoxesTable(format) {
        if (!currentBoxesTableData || currentBoxesTableData.length === 0) {
            window.showToast('error', 'Sem dados para exportar.');
            return;
        }

        const filters = {
            Ano: boxesAnoFilter.value !== 'todos' ? boxesAnoFilter.value : 'Todos',
            Mes: boxesMesFilter.options[boxesMesFilter.selectedIndex]?.text || 'Todos',
            Filiais: boxesSelectedFiliais.length > 0 ? boxesSelectedFiliais.join(', ') : 'Todas',
            Supervisores: boxesSelectedSupervisores.length > 0 ? `${boxesSelectedSupervisores.length} selecionados` : 'Todos',
            Fornecedores: boxesSelectedFornecedores.length > 0 ? `${boxesSelectedFornecedores.length} selecionados` : 'Todos',
            Vendedores: boxesSelectedVendedores.length > 0 ? `${boxesSelectedVendedores.length} selecionados` : 'Todos',
            Cidades: boxesSelectedCidades.length > 0 ? `${boxesSelectedCidades.length} selecionadas` : 'Todas'
        };

        const reportData = currentBoxesTableData.map(row => ({
            "Código": row.produto,
            "Descrição": row.descricao,
            "Caixas": row.caixas,
            "Faturamento": row.faturamento,
            "Peso (kg)": row.peso,
            "Posit.": row.clientes || 0,
            "Última Venda": row.ultima_venda ? new Date(row.ultima_venda).toLocaleDateString('pt-BR') : '-'
        }));

        if (format === 'excel') {
            // Create workbook
            const wb = XLSX.utils.book_new();
            
            // Prepare Filter Info rows
            const filterInfo = [
                ["Relatório de Produtos por Caixas"],
                ["Gerado em:", new Date().toLocaleString('pt-BR')],
                [],
                ["Filtros Aplicados:"],
                ...Object.entries(filters).map(([k, v]) => [k, v]),
                []
            ];

            // Create Worksheet
            const ws = XLSX.utils.aoa_to_sheet(filterInfo);
            
            // Append Data starting at row after filters
            XLSX.utils.sheet_add_json(ws, reportData, { origin: -1 });

            // Append sheet
            XLSX.utils.book_append_sheet(wb, ws, "Produtos");

            // Download
            XLSX.writeFile(wb, `Relatorio_Caixas_${new Date().toISOString().slice(0,10)}.xlsx`);

        } else if (format === 'pdf') {
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();

            doc.setFontSize(16);
            doc.text("Relatório de Produtos por Caixas", 14, 15);
            
            doc.setFontSize(10);
            doc.text(`Gerado em: ${new Date().toLocaleString('pt-BR')}`, 14, 22);

            let yPos = 30;
            doc.text("Filtros Aplicados:", 14, yPos);
            yPos += 5;
            
            doc.setFontSize(9);
            Object.entries(filters).forEach(([k, v]) => {
                doc.text(`${k}: ${v}`, 14, yPos);
                yPos += 5;
            });

            // Table
            doc.autoTable({
                startY: yPos + 5,
                head: [['Código', 'Descrição', 'Caixas', 'Faturamento', 'Peso (kg)', 'Última Venda']],
                body: reportData.map(r => [
                    r["Código"],
                    r["Descrição"],
                    formatInteger(r["Caixas"]),
                    formatCurrency(r["Faturamento"]),
                    formatTons(r["Peso (kg)"], 1),
                    r["Última Venda"]
                ]),
                theme: 'striped',
                headStyles: { fillColor: [22, 163, 74] }, // Emerald-600
                styles: { fontSize: 8 }
            });

            doc.save(`Relatorio_Caixas_${new Date().toISOString().slice(0,10)}.pdf`);
        }
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [boxesFilialFilterDropdown, boxesProdutoFilterDropdown, boxesSupervisorFilterDropdown, boxesVendedorFilterDropdown, boxesFornecedorFilterDropdown, boxesCidadeFilterDropdown, boxesTipovendaFilterDropdown, boxesCategoriaFilterDropdown];
        const btns = [boxesFilialFilterBtn, boxesProdutoFilterBtn, boxesSupervisorFilterBtn, boxesVendedorFilterBtn, boxesFornecedorFilterBtn, boxesCidadeFilterBtn, boxesTipovendaFilterBtn, boxesCategoriaFilterBtn];
        let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);
        
        // Close export dropdown if clicked outside
        if (boxesExportDropdown && !boxesExportDropdown.classList.contains('hidden') && !boxesExportDropdown.contains(e.target) && !boxesExportBtn.contains(e.target)) {
            boxesExportDropdown.classList.add('hidden');
        }

        if (anyClosed && !boxesView.classList.contains('hidden')) {
            handleBoxesFilterChange();
        }
    });

    if (boxesClearFiltersBtn) {
        boxesClearFiltersBtn.addEventListener('click', () => {
            boxesAnoFilter.value = 'todos';
            boxesAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
            boxesMesFilter.value = '';
            boxesMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
            boxesSelectedFiliais.length = 0;
            boxesSelectedProducts.length = 0;
            boxesSelectedSupervisores.length = 0;
            boxesSelectedVendedores.length = 0;
            boxesSelectedFornecedores.length = 0;
            boxesSelectedCidades.length = 0;
            boxesSelectedTiposVenda.length = 0;
            boxesSelectedCategorias.length = 0;
            boxesTrendActive = false; // Reset Trend
            const span = document.getElementById('boxes-trend-text');
            if(span) span.textContent = 'Calcular Tendência';
            if(boxesTrendToggleBtn) {
                boxesTrendToggleBtn.classList.remove('text-purple-500', 'hover:text-purple-400');
                boxesTrendToggleBtn.classList.add('text-orange-500', 'hover:text-orange-400');
            }
            initBoxesFilters().then(loadBoxesView);
        });
    }

    async function initBoxesFilters() {
        const filters = {
            p_ano: null,
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: [],
            p_categoria: []
        };
        const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
        if (error) AppLog.error('Error fetching boxes filters:', error);
        if (!filterData) return;

        if (filterData.anos && boxesAnoFilter) {
            const currentVal = boxesAnoFilter.value;
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            boxesAnoFilter.innerHTML = '<option value="todos">Todos</option>' + filterData.anos.map(a => `<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
            if (currentVal && currentVal !== 'todos') boxesAnoFilter.value = currentVal;
            else if (filterData.anos.length > 0) boxesAnoFilter.value = filterData.anos[0];
            enhanceSelectToCustomDropdown(boxesAnoFilter);
        }

        if (boxesMesFilter && boxesMesFilter.options.length <= 1) {
            const meses = MONTHS_PT;
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            boxesMesFilter.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${i}">${m}</option>`).join('');
            enhanceSelectToCustomDropdown(boxesMesFilter);
        }

        setupCityMultiSelect(boxesFilialFilterBtn, boxesFilialFilterDropdown, boxesFilialFilterDropdown, filterData.filiais, boxesSelectedFiliais);
        setupCityMultiSelect(boxesSupervisorFilterBtn, boxesSupervisorFilterDropdown, boxesSupervisorFilterDropdown, filterData.supervisors, boxesSelectedSupervisores);
        setupCityMultiSelect(boxesVendedorFilterBtn, boxesVendedorFilterDropdown, boxesVendedorFilterList, filterData.vendedores, boxesSelectedVendedores, boxesVendedorFilterSearch);
        setupCityMultiSelect(boxesFornecedorFilterBtn, boxesFornecedorFilterDropdown, boxesFornecedorFilterList, filterData.fornecedores, boxesSelectedFornecedores, boxesFornecedorFilterSearch, true);
        setupCityMultiSelect(boxesCidadeFilterBtn, boxesCidadeFilterDropdown, boxesCidadeFilterList, filterData.cidades, boxesSelectedCidades, boxesCidadeFilterSearch);
        setupCityMultiSelect(boxesTipovendaFilterBtn, boxesTipovendaFilterDropdown, boxesTipovendaFilterDropdown, filterData.tipos_venda || [], boxesSelectedTiposVenda);
        setupCityMultiSelect(boxesCategoriaFilterBtn, boxesCategoriaFilterDropdown, boxesCategoriaFilterList, filterData.categorias || [], boxesSelectedCategorias, boxesCategoriaFilterSearch);
        
        // Products - filterData.produtos
        setupCityMultiSelect(boxesProdutoFilterBtn, boxesProdutoFilterDropdown, boxesProdutoFilterList, filterData.produtos || [], boxesSelectedProducts, boxesProdutoFilterSearch, true);
    }

    async function loadBoxesView() {
        window.showDashboardLoading('boxes-view');

        if (typeof initBoxesFilters === 'function' && boxesAnoFilter && boxesAnoFilter.options.length <= 1) {
             await initBoxesFilters();
        }

        const filters = {
            p_filial: boxesSelectedFiliais.length > 0 ? boxesSelectedFiliais : null,
            p_cidade: boxesSelectedCidades.length > 0 ? boxesSelectedCidades : null,
            p_supervisor: boxesSelectedSupervisores.length > 0 ? boxesSelectedSupervisores : null,
            p_vendedor: boxesSelectedVendedores.length > 0 ? boxesSelectedVendedores : null,
            p_fornecedor: boxesSelectedFornecedores.length > 0 ? boxesSelectedFornecedores : null,
            p_produto: boxesSelectedProducts.length > 0 ? boxesSelectedProducts : null,
            p_tipovenda: boxesSelectedTiposVenda.length > 0 ? boxesSelectedTiposVenda : null,
            p_categoria: boxesSelectedCategorias.length > 0 ? boxesSelectedCategorias : null,
            p_ano: boxesAnoFilter.value === 'todos' ? null : boxesAnoFilter.value,
            p_mes: boxesMesFilter.value === '' ? null : boxesMesFilter.value
        };

        const cacheKey = generateCacheKey('boxes_dashboard_data', filters);
        let data = null;

        try {
            const cachedEntry = await getFromCache(cacheKey);
            if (cachedEntry && cachedEntry.data) {
                AppLog.log('Serving Boxes View from Cache');
                data = cachedEntry.data;
            }
        } catch (e) { AppLog.warn('Cache error:', e); }

        if (!data) {
            const { data: rpcData, error } = await supabase.rpc('get_boxes_dashboard_data', filters);
            
            if (error) {
                AppLog.error(error);
                window.hideDashboardLoading();
                if (error.message.includes('function get_boxes_dashboard_data') && error.message.includes('does not exist')) {
                    window.showToast('error', "Erro: A função 'get_boxes_dashboard_data' não foi encontrada. Aplique o script de migração 'sql/migration_boxes.sql'.");
                }
                return;
            }
            data = rpcData;
            saveToCache(cacheKey, data);
        }

        window.hideDashboardLoading();
        renderBoxesDashboard(data);
    }

    window.renderBoxesDashboard = function renderBoxesDashboard(data) {
        // Trend Data Extraction
        const trendInfo = data.trend_info || { allowed: false, factor: 1, current_month_index: -1 };
        const applyTrend = boxesTrendActive && trendInfo.allowed;
        
        // Safe access helpers
        const safeVal = (v) => v || 0;
        const fmtBRL = (v) => formatCurrency(safeVal(v));
        const fmtKg = (v) => formatTons(safeVal(v), 1);
        const fmtCaixas = (v) => formatInteger(safeVal(v));
        
        const calcVar = (curr, prev) => {
            if (prev > 0) return ((curr / prev) - 1) * 100;
            return curr > 0 ? 100 : 0;
        };
        const fmtVar = (v) => {
            const cls = v >= 0 ? 'text-emerald-400' : 'text-red-400';
            const sign = v > 0 ? '+' : '';
            const span = document.createElement('span');
            span.className = cls;
            span.textContent = `${sign}${v.toFixed(1)}%`;
            return span;
        };

        // Determine View Mode (Year vs Month)
        // If boxesMesFilter is empty -> Year View (Accumulated)
        // If boxesMesFilter has value -> Month View (Specific Month)
        const isYearView = (boxesMesFilter.value === '');

        // --- KPI Logic Update for Trend ---
        const updateBoxKpi = (prefix, key, formatFn) => {
            let curr = safeVal(data.kpi_current[key]);
            const prev = safeVal(data.kpi_previous[key]);
            const tri = safeVal(data.kpi_tri_avg[key]);
            
            let mainDisplayVal = curr;
            let triComparisonVal = curr; // Default: Compare current realized vs Tri Avg

            if (applyTrend) {
                if (isYearView) {
                    // YEAR VIEW + TREND
                    // Main Value: Should be Annual Projection (YTD Realized - Current Realized + Current Trended) / Months * 12
                    // Formula simplified: (YTD_Realized_Excluding_Current + (Current_Realized * Factor)) / Month_Index * 12
                    
                    const filterYear = boxesAnoFilter.value !== 'todos' ? parseInt(boxesAnoFilter.value) : new Date().getFullYear();
                    const currMonthData = (data.chart_data || []).find(d => d.year === filterYear && d.month_index === trendInfo.current_month_index);
                    
                    let currMonthRealized = 0;
                    if (currMonthData) {
                        if (key === 'fat') currMonthRealized = currMonthData.faturamento;
                        else if (key === 'peso') currMonthRealized = currMonthData.peso;
                        else if (key === 'caixas') currMonthRealized = currMonthData.caixas;
                        else if (key === 'clientes') currMonthRealized = currMonthData.clientes || 0;
                    }
                    
                    // Tri Indicator: Trended Current Month vs Tri Avg
                    triComparisonVal = currMonthRealized * trendInfo.factor;
                    
                    // Main Display: Annual Projection
                    // 1. Calculate YTD Realized Excluding Current Month
                    // curr is the total YTD from RPC
                    const ytdExclCurrent = curr - currMonthRealized;
                    
                    // 2. Add Trended Current Month
                    const ytdWithTrend = ytdExclCurrent + triComparisonVal;
                    
                    // 3. Project for Full Year (12 months)
                    // If we are in Jan (index 0), divide by 1 * 12
                    // If we are in Dec (index 11), divide by 12 * 12 (basically identity)
                    const monthsPassed = trendInfo.current_month_index + 1;
                    
                    if (monthsPassed > 0) {
                        mainDisplayVal = (ytdWithTrend / monthsPassed) * 12;
                    } else {
                        mainDisplayVal = ytdWithTrend; // Fallback
                    }
                    
                } else {
                    // MONTH VIEW + TREND
                    // Main Value: Trended Monthly Value.
                    // Tri Indicator: Trended Monthly Value.
                    mainDisplayVal = curr * trendInfo.factor;
                    triComparisonVal = mainDisplayVal;
                }
            } else {
                // NO TREND
                // In Year View: triComparisonVal should ideally be the current month's realized vs Tri Avg?
                // The prompt says: "no indicador de trimestre... sempre será o mês mais recente contra o trimestre mais recente"
                // So even without trend, if in Year View, Tri comparison is Month vs Month.
                if (isYearView) {
                     const filterYear = boxesAnoFilter.value !== 'todos' ? parseInt(boxesAnoFilter.value) : new Date().getFullYear();
                     // Find max month in data or current month index
                     // If trend is not allowed (e.g. past year), use the last month available in data?
                     // Or just use the average of the year vs tri? Usually it's Month vs Tri.
                     
                     // Let's assume for Year View, Tri indicator is always "Last Active Month" vs "Previous 3 Months Avg".
                     // If we are in 2025 (current), it's Current Month.
                     // If we are in 2024 (past), it's Dec 2024 vs Oct-Nov-Dec 2024 avg? Or Jan 2025 vs Q4 2024?
                     // Simplified: If trend allowed (Current Year), use current month.
                     if (trendInfo.allowed) {
                         const currMonthData = (data.chart_data || []).find(d => d.year === filterYear && d.month_index === trendInfo.current_month_index);
                         if (currMonthData) {
                             if (key === 'fat') triComparisonVal = currMonthData.faturamento;
                             else if (key === 'peso') triComparisonVal = currMonthData.peso;
                             else if (key === 'caixas') triComparisonVal = currMonthData.caixas;
                             else if (key === 'clientes') triComparisonVal = currMonthData.clientes || 0;
                         }
                     } else {
                         // If past year, maybe just leave it as average vs average or hide? 
                         // Logic: "always the most recent month".
                         // For now, let's keep triComparisonVal = curr (which is Total Year) ONLY if we can't isolate month, 
                         // but standard logic suggests we shouldn't compare Year Total vs Monthly Average.
                         // Let's stick to: if chart data exists, pick last month.
                         const filterYear = boxesAnoFilter.value !== 'todos' ? parseInt(boxesAnoFilter.value) : new Date().getFullYear();
                         const monthsData = (data.chart_data || []).filter(d => d.year === filterYear).sort((a,b) => b.month_index - a.month_index);
                         if (monthsData.length > 0) {
                             const lastM = monthsData[0];
                             if (key === 'fat') triComparisonVal = lastM.faturamento;
                             else if (key === 'peso') triComparisonVal = lastM.peso;
                             else if (key === 'caixas') triComparisonVal = lastM.caixas;
                             else if (key === 'clientes') triComparisonVal = lastM.clientes || 0;
                         }
                     }
                }
            }

            const elMain = document.getElementById(`boxes-kpi-${prefix}`);
            if(elMain) elMain.textContent = formatFn(mainDisplayVal);

            const elPrevVal = document.getElementById(`boxes-kpi-${prefix}-prev`);
            const elPrevVar = document.getElementById(`boxes-kpi-${prefix}-prev-var`);
            if(elPrevVal) elPrevVal.textContent = formatFn(prev);
            
            // Year vs Year variation (using Main Display Val which might be Trended Month or Realized Year)
            // If Year View: Realized Year vs Previous Year.
            // If Month View + Trend: Trended Month vs Previous Month (same period prev year).
            // Logic: calcVar(mainDisplayVal, prev).
            if(elPrevVar) {
                elPrevVar.innerHTML = '';
                elPrevVar.appendChild(fmtVar(calcVar(mainDisplayVal, prev)));
            }

            const elTriVal = document.getElementById(`boxes-kpi-${prefix}-tri`);
            const elTriVar = document.getElementById(`boxes-kpi-${prefix}-tri-var`);
            if(elTriVal) elTriVal.textContent = formatFn(tri);
            
            // Tri Variation: Always Monthly (Recent/Trended) vs Tri Avg
            if(elTriVar) {
                elTriVar.innerHTML = '';
                elTriVar.appendChild(fmtVar(calcVar(triComparisonVal, tri)));
            }
        };

        updateBoxKpi('fat', 'fat', fmtBRL);
        updateBoxKpi('peso', 'peso', fmtKg);
        updateBoxKpi('caixas', 'caixas', fmtCaixas);
        updateBoxKpi('clientes', 'clientes', fmtCaixas);

        // Chart (2 datasets: Current vs Previous + Trend if active)
        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const labels = [...monthNames];
        const currentYear = new Date().getFullYear(); 
        
        const boxesCurrent = new Array(12).fill(0);
        const boxesPrev = new Array(12).fill(0);
        const chartData = data.chart_data || [];
        
        const filterYear = boxesAnoFilter.value !== 'todos' ? parseInt(boxesAnoFilter.value) : currentYear;
        const prevYear = filterYear - 1;

        chartData.forEach(d => {
            if (d.month_index >= 0 && d.month_index < 12) {
                if (d.year === filterYear) boxesCurrent[d.month_index] = d.caixas;
                if (d.year === prevYear) boxesPrev[d.month_index] = d.caixas;
            }
        });

        const datasets = [
            {
                label: `Ano ${prevYear}`,
                data: boxesPrev,
                borderWidth: 1,
                isPrevious: true
            },
            {
                label: `Ano ${filterYear}`,
                data: boxesCurrent,
                borderWidth: 1,
                isCurrent: true
            }
        ];

        // Chart Trend Logic
        if (applyTrend) {
            // Add "Tendência" Bar
            labels.push('Tendência');
            
            // Calculate Trended Value for the current month
            // We need the realized value of the current month to project
            const currMonthData = chartData.find(d => d.year === filterYear && d.month_index === trendInfo.current_month_index);
            const realizedCaixas = currMonthData ? currMonthData.caixas : 0;
            const trendCaixas = realizedCaixas * trendInfo.factor;

            // Create a dataset for Trend that is empty for months and has value for "Tendência" label
            // BUT simpler: extend current year dataset? No, distinct color.
            // Let's add a new dataset "Tendência" with 13 points (12 null + 1 val)
            // And pad others with 0 or null
            
            // Pad existing
            datasets.forEach(ds => ds.data.push(null));
            
            const trendData = new Array(13).fill(null);
            trendData[12] = trendCaixas;
            
            datasets.push({
                label: `Tendência ${monthNames[trendInfo.current_month_index]}`,
                data: trendData,
                borderWidth: 1,
                isTrend: true
            });
        }

        createChart('boxesChart', 'bar', labels, datasets, (v) => formatChartLabel(v));

        // Table
        const products = data.products_table || [];
        currentBoxesTableData = products; // Store for export

        const tableBody = document.getElementById('boxesProductTableBody');
        if (products.length > 0) {
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            tableBody.innerHTML = products.map(p => `
                <tr class="table-row">
                    <td class="p-2">${escapeHtml(p.produto)}</td>
                    <td class="p-2">${escapeHtml(p.descricao)}</td>
                    <td class="p-2 text-right font-bold text-emerald-400">${escapeHtml(formatInteger(safeVal(p.caixas)))}</td>
                    <td class="p-2 text-right">${escapeHtml(formatCurrency(safeVal(p.faturamento)))}</td>
                    <td class="p-2 text-right">${escapeHtml(formatTons(safeVal(p.peso), 2))}</td>
                    <td class="p-2 text-right text-slate-300 font-bold">${escapeHtml(formatInteger(safeVal(p.clientes)))}</td>
                    <td class="p-2 text-center text-slate-400">${escapeHtml(p.ultima_venda ? new Date(p.ultima_venda).toLocaleDateString('pt-BR') : '-')}</td>
                </tr>
            `).join('');
        } else {
            tableBody.innerHTML = '<tr><td colspan="7" class="p-4 text-center text-slate-500">Nenhum produto encontrado.</td></tr>';
        }
    }

    // Boxes Filter Elements - MOVED UP

    // State
    let currentCityPage = 0;
    const cityPageSize = 50;
    let totalActiveClients = 0;

    let selectedFiliais = [];
    let selectedCidades = [];
    let selectedSupervisores = [];
    let selectedVendedores = [];
    let selectedFornecedores = [];
    let selectedTiposVenda = [];
    let selectedRedes = [];
    let selectedCategorias = [];
    let currentCharts = {};
    let holidays = [];
    let lastSalesDate = null;
    let currentChartMode = 'faturamento'; // 'faturamento' or 'peso'
    let lastDashboardData = null;

    // Prefetch State
    let availableFiltersState = { filiais: [], supervisors: [], cidades: [], vendedores: [], fornecedores: [], tipos_venda: [], redes: [], categorias: [] };
    let prefetchQueue = [];
    let isPrefetching = false;

    // --- Loading Helpers ---
    window.showDashboardLoading = function(targetId = 'main-dashboard-view') {
        const container = document.getElementById(targetId);
        let overlay = document.getElementById('dashboard-loading-overlay');

        // If overlay exists but is in a different container, move it
        if (overlay && overlay.parentElement !== container) {
            overlay.remove();
            overlay = null; 
        }

        if (!overlay && container) {
            overlay = document.createElement('div');
            overlay.id = 'dashboard-loading-overlay';
            overlay.className = 'dashboard-loading-overlay';
            overlay.innerHTML = '<div class="dashboard-loading-spinner"></div>';
            // Make sure container is relative for absolute positioning
            if (getComputedStyle(container).position === 'static') {
                container.style.position = 'relative';
            }
            container.appendChild(overlay);
        } else if (overlay) {
            overlay.classList.remove('hidden');
        }
    }

    window.hideDashboardLoading = function() {
        const overlay = document.getElementById('dashboard-loading-overlay');
        if (overlay) overlay.classList.add('hidden');
    }

    async function initDashboard() {
        window.showDashboardLoading();
        await checkDataVersion(); // Check for invalidation first

        const filters = getCurrentFilters();
        await loadFilters(filters);
        await loadMainDashboardData();
        
        // Trigger background prefetch after main load
        setTimeout(() => {
            queueCommonFilters();
        }, 3000);
        isMainDashboardInitialized = true;
    }

    async function checkDataVersion() {
        try {
            const { data: serverVersion, error } = await supabase.rpc('get_data_version');
            if (error) { AppLog.warn('Erro ao verificar versão:', error); return; }

            const localVersion = localStorage.getItem('dashboard_data_version');
            
            if (serverVersion && serverVersion !== localVersion) {
                AppLog.log('Nova versão de dados detectada. Limpando cache...', serverVersion);
                
                // Clear IndexedDB
                const db = await initDB();
                await db.clear(STORE_NAME);
                
                // Update Local Version
                localStorage.setItem('dashboard_data_version', serverVersion);
            }
        } catch (e) {
            AppLog.error('Falha na validação de cache:', e);
        }
    }

    function getCurrentFilters() {
        return {
            p_filial: selectedFiliais,
            p_cidade: selectedCidades,
            p_supervisor: selectedSupervisores,
            p_vendedor: selectedVendedores,
            p_fornecedor: selectedFornecedores,
            p_ano: anoFilter.value,
            p_mes: mesFilter.value,
            p_tipovenda: selectedTiposVenda,
            p_rede: selectedRedes,
            p_categoria: selectedCategorias
        };
    }

    async function loadFilters(currentFilters, retryCount = 0) {
        // Cache logic for Filters
        const CACHE_TTL = 1000 * 60 * 5; // 5 minutes for filters
        const cacheKey = generateCacheKey('dashboard_filters', currentFilters);
        
        try {
            const cachedEntry = await getFromCache(cacheKey);
            if (cachedEntry && cachedEntry.timestamp) {
                const age = Date.now() - cachedEntry.timestamp;
                if (age < CACHE_TTL) {
                    AppLog.log('Serving filters from cache (fresh)');
                    applyFiltersData(cachedEntry.data);
                    return; 
                }
            }
        } catch (e) { AppLog.warn('Cache error:', e); }

        const { data, error } = await supabase.rpc('get_dashboard_filters', currentFilters);
        if (error) {
            if (retryCount < 1) {
                 await new Promise(r => setTimeout(r, 1000));
                 return loadFilters(currentFilters, retryCount + 1);
            }
            return;
        }

        await saveToCache(cacheKey, data);
        applyFiltersData(data);
    }

    window.setupMultiSelect = function(btn, dropdown, container, items, selectedArray, labelCallback, isObject = false, searchInput = null) {
        if(!btn || !dropdown) return;
        if (!container) {
            AppLog.warn('Container not found for filter', btn?.id);
            return;
        }
        const MAX_ITEMS = 100;
        btn.onclick = (e) => {
        e.stopPropagation();
        const isHidden = dropdown.classList.contains('hidden');
        // Close all dropdowns
        closeAllDropdowns();
        // Restore this one if it was hidden
        if (isHidden) {
            dropdown.classList.remove('hidden');
        }
    };
        
        let debounceTimer;
        const renderItems = (filterText = '') => {
            container.innerHTML = '';
            let filteredItems = items || [];
            if (filterText) {
                const lower = filterText.toLowerCase();
                filteredItems = filteredItems.filter(item => {
                    const nameVal = isObject ? item.name : item;
                    const codVal = isObject ? item.cod : '';
                    return String(nameVal).toLowerCase().includes(lower) || (isObject && String(codVal).toLowerCase().includes(lower));
                });
            }
            
                        // Sort items so selected ones appear first
            // ⚡ Bolt Optimization: Use a Set for O(1) lookups during sorting instead of O(N) array.includes()
            const selectedSet = new Set(selectedArray);
            filteredItems.sort((a, b) => {
                const valA = String(isObject ? a.cod : a);
                const valB = String(isObject ? b.cod : b);
                const isSelectedA = selectedSet.has(valA);
                const isSelectedB = selectedSet.has(valB);

                if (isSelectedA && !isSelectedB) return -1;
                if (!isSelectedA && isSelectedB) return 1;
                return 0;
            });

            const displayItems = filteredItems.slice(0, MAX_ITEMS);

            // 🧹 Tidy Optimization: Batch DOM creation using template strings for better readability and performance
            container.innerHTML = displayItems.map(item => {
                const value = String(isObject ? item.cod : item);
                const label = isObject ? item.name : item;
                const isSelected = selectedSet.has(value);
                return `
                    <div class="flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded filter-item-row" data-value="${escapeHtml(value)}">
                        <input type="checkbox" value="${escapeHtml(value)}" class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2" ${isSelected ? 'checked' : ''}>
                        <label class="ml-2 text-sm text-slate-200 cursor-pointer flex-1">${escapeHtml(label)}</label>
                    </div>
                `;
            }).join('');

            // Attach event listeners after rendering
            container.querySelectorAll('.filter-item-row').forEach(div => {
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    const val = checkbox.value;

                    if (checkbox.checked) {
                        if (!selectedArray.includes(val)) {
                            selectedArray.push(val);
                        }
                    } else {
                        const idx = selectedArray.indexOf(val);
                        if (idx > -1) {
                            selectedArray.splice(idx, 1);
                        }
                    }
                    updateBtnLabel();
                };
            });

            if (filteredItems.length > MAX_ITEMS) {
                const limitMsg = document.createElement('div');
                limitMsg.className = 'p-2 text-xs text-slate-500 text-center border-t border-slate-700 mt-1';
                limitMsg.textContent = `Exibindo ${MAX_ITEMS} de ${filteredItems.length}. Use a busca.`;
                container.appendChild(limitMsg);
            }

            if (filteredItems.length === 0) container.innerHTML = '<div class="p-2 text-sm text-slate-500 text-center">Nenhum item encontrado</div>';
        };
        const updateBtnLabel = () => {
            const span = btn.querySelector('span');
            if (!span) {
                // Fallback if no span, to prevent crash
                return;
            }
            if (selectedArray.length === 0) {
                span.textContent = 'Todas';
                if(btn.id.includes('vendedor') || btn.id.includes('fornecedor') || btn.id.includes('supervisor') || btn.id.includes('tipovenda')) span.textContent = 'Todos';
            } else if (selectedArray.length === 1) {
                const val = selectedArray[0];
                let found;
                // ⚡ Bolt Optimization: Use loose equality '==' to avoid unnecessary String() conversions and allocations in O(N) search
                if (isObject) found = (items || []).find(i => i.cod == val); else found = (items || []).find(i => i == val);
                if (found) span.textContent = isObject ? found.name : found; else span.textContent = val;
            } else { span.textContent = `${selectedArray.length} selecionados`; }
        };
        renderItems();
        updateBtnLabel();
        if (searchInput) { 
            searchInput.oninput = (e) => {
                clearTimeout(debounceTimer);
                debounceTimer = setTimeout(() => renderItems(e.target.value), 300);
            }; 
            searchInput.onclick = (e) => e.stopPropagation(); 
        }
    }

    window.enhanceSelectToCustomDropdown = function(selectElement) {
        if (!selectElement) return;

        // Return if already enhanced
        if (selectElement.hasAttribute('data-enhanced')) return;
        selectElement.setAttribute('data-enhanced', 'true');

        // Hide original select
        selectElement.style.display = 'none';

        // Create Button
        const btn = document.createElement('button');
        // Copy select classes, remove appearance-none, add button classes
        const classes = selectElement.className.replace('appearance-none', '').split(' ').filter(c => c.trim() !== '');
        btn.className = [...new Set([...classes, 'text-left', 'flex', 'justify-between', 'items-center'])].join(' ');
        btn.type = 'button';

        const span = document.createElement('span');
        span.className = 'truncate';

        // Find initial selected option
        const initialSelectedOption = selectElement.options[selectElement.selectedIndex];
        span.textContent = initialSelectedOption ? initialSelectedOption.text : '';

        const icon = document.createElement('div');
        icon.innerHTML = '<svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>';

        btn.appendChild(span);
        btn.appendChild(icon.firstChild);

        // Create Dropdown Container
        const dropdown = document.createElement('div');
        dropdown.className = 'hidden absolute z-[50] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2';

        // Insert after select
        selectElement.parentNode.insertBefore(btn, selectElement.nextSibling);
        selectElement.parentNode.insertBefore(dropdown, btn.nextSibling);

        const renderOptions = () => {
            // 🧹 Tidy Optimization: Batch DOM creation for options
            dropdown.innerHTML = Array.from(selectElement.options).map(opt => {
                const isSelected = selectElement.value === opt.value;
                const labelClasses = isSelected ? 'text-orange-500 font-bold' : 'text-slate-200';
                return `
                    <div class="flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded custom-dropdown-item" data-value="${escapeHtml(opt.value)}">
                        <input type="checkbox" class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2 pointer-events-none" readonly ${isSelected ? 'checked' : ''}>
                        <label class="ml-2 text-sm cursor-pointer flex-1 ${labelClasses}">${escapeHtml(opt.text)}</label>
                    </div>
                `;
            }).join('');

            // Attach event listeners
            dropdown.querySelectorAll('.custom-dropdown-item').forEach(itemDiv => {
                itemDiv.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const val = itemDiv.getAttribute('data-value');
                    const opt = Array.from(selectElement.options).find(o => o.value === val);

                    if (opt) {
                        selectElement.value = opt.value;
                        span.textContent = opt.text;
                    }

                    // Update visual state of all items
                    dropdown.querySelectorAll('.custom-dropdown-item').forEach(child => {
                        const cb = child.querySelector('input');
                        if (cb) cb.checked = false;
                        const lbl = child.querySelector('label');
                        if (lbl) {
                            lbl.classList.remove('text-orange-500', 'font-bold');
                            lbl.classList.add('text-slate-200');
                        }
                    });

                    // Check the clicked one
                    const clickedCb = itemDiv.querySelector('input');
                    if (clickedCb) clickedCb.checked = true;
                    const clickedLbl = itemDiv.querySelector('label');
                    if (clickedLbl) {
                        clickedLbl.classList.remove('text-slate-200');
                        clickedLbl.classList.add('text-orange-500', 'font-bold');
                    }
                });
            });

            // Update span text just in case value changed
            const selectedOpt = selectElement.options[selectElement.selectedIndex];
            if (selectedOpt) span.textContent = selectedOpt.text;
        };

        renderOptions();

        // Force update visual state without recreating DOM to fix unselected bug on reopen
        const updateVisualState = () => {
            const selectedOpt = selectElement.options[selectElement.selectedIndex];
            if (selectedOpt) span.textContent = selectedOpt.text;

            Array.from(dropdown.children).forEach((child, index) => {
                const opt = selectElement.options[index];
                if (!opt) return;

                const isSelected = selectElement.value === opt.value;
                const cb = child.querySelector('input');
                if (cb) cb.checked = isSelected;

                const lbl = child.querySelector('label');
                if (lbl) {
                    if (isSelected) {
                        lbl.classList.remove('text-slate-200');
                        lbl.classList.add('text-orange-500', 'font-bold');
                    } else {
                        lbl.classList.remove('text-orange-500', 'font-bold');
                        lbl.classList.add('text-slate-200');
                    }
                }
            });
        };

        // Observe changes to the select options
        const observer = new MutationObserver((mutations) => {
            // Re-render full options when DOM changes
            renderOptions();
        });
        observer.observe(selectElement, { childList: true });

        let initialValueOnOpen = selectElement.value;

        // Handle button click
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const isHidden = dropdown.classList.contains('hidden');

            // Close all dropdowns
            closeAllDropdowns();

            if (isHidden) {
                updateVisualState(); // Sync visuals just before opening
                dropdown.classList.remove('hidden');
                initialValueOnOpen = selectElement.value; // Store value when opened
            } else {
                dropdown.classList.add('hidden');
                // Trigger change if value changed while open
                if (selectElement.value !== initialValueOnOpen) {
                    selectElement.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
        });

        // Close on click outside
        document.addEventListener('click', (e) => {
            if (!dropdown.classList.contains('hidden') && !dropdown.contains(e.target) && !btn.contains(e.target)) {
                dropdown.classList.add('hidden');
                // We dispatch change if the actual selectElement.value changed since we opened it.
                // However, clicking an option inside the dropdown *already* dispatches a change event?
                // NO, the option click inside `renderOptions` just does `selectElement.value = opt.value` but doesn't dispatch change.
                // It only dispatches change on close!
                // Wait! If it dispatches change on close, and we open another one, it triggers click outside, closing the first, and dispatching change!
                // But why would it flash if value DID NOT change?
                // Let's ensure `initialValueOnOpen` is kept strictly updated!
                if (selectElement.value !== initialValueOnOpen) {
                    initialValueOnOpen = selectElement.value; // Prevent multiple dispatches
                    selectElement.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
        });

        // Update when original select changes its value externally
        selectElement.addEventListener('change', (e) => {
            updateVisualState();
        });
    }

    function applyFiltersData(data) {
        // Capture available options for prefetcher
        availableFiltersState.filiais = data.filiais || [];
        availableFiltersState.supervisors = data.supervisors || [];
        availableFiltersState.cidades = data.cidades || [];
        availableFiltersState.vendedores = data.vendedores || [];
        availableFiltersState.fornecedores = data.fornecedores || []; // Array of objects
        availableFiltersState.tipos_venda = data.tipos_venda || [];
        availableFiltersState.redes = data.redes || [];
        availableFiltersState.categorias = data.categorias || [];


    const updateSingleSelect = (element, items) => {
            const currentVal = element.value;
            // Always add 'Todos' option (value='todos' for year, '' for others)
            const allVal = (element.id === 'ano-filter') ? 'todos' : '';
            let html = `<option value="${allVal}">Todos</option>`;
            if (items) {
                html += items.map(item => `<option value="${escapeHtml(item)}">${escapeHtml(item)}</option>`).join('');
            }
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            element.innerHTML = html;
            // Logic to set default or preserve selection
            if (currentVal && Array.from(element.options).some(o => o.value === currentVal)) {
                element.value = currentVal;
        } else if (element.id === 'ano-filter' && items && items.length > 0 && currentVal !== 'todos') {
             // Default to first year only if not explicitly 'todos' and 'todos' isn't valid (though we just added it)
             // Actually, if currentVal was 'todos', it matches the first option we added.
             // If currentVal was something else invalid, fallback to items[0].
             // But if we want default 'Todos', we should let it fall through to first option?
             // If the user wants specific year by default on load, logic handles it.
             // If user wants 'Todos' (e.g. clear filters), it matches.
             
             // If currentVal was invalid (e.g. old year not in list), default to Todos (index 0) or First Year?
             // Usually defaulting to 'Todos' (index 0) is safer now that we added it.
             if (!element.value) element.value = 'todos';
            }
        };
        updateSingleSelect(anoFilter, data.anos);
        if (mesFilter.options.length <= 1) { 
            const meses = MONTHS_PT;
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            mesFilter.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${i}">${m}</option>`).join('');
        }
        window.setupMultiSelect(filialFilterBtn, filialFilterDropdown, filialFilterDropdown, data.filiais, selectedFiliais, () => {});
        window.setupMultiSelect(cidadeFilterBtn, cidadeFilterDropdown, cidadeFilterList, data.cidades, selectedCidades, () => {}, false, cidadeFilterSearch);
        window.setupMultiSelect(supervisorFilterBtn, supervisorFilterDropdown, supervisorFilterDropdown, data.supervisors, selectedSupervisores, () => {});
        window.setupMultiSelect(vendedorFilterBtn, vendedorFilterDropdown, vendedorFilterList, data.vendedores, selectedVendedores, () => {}, false, vendedorFilterSearch);
        window.setupMultiSelect(fornecedorFilterBtn, fornecedorFilterDropdown, fornecedorFilterList, data.fornecedores, selectedFornecedores, () => {}, true, fornecedorFilterSearch);
        window.setupMultiSelect(tipovendaFilterBtn, tipovendaFilterDropdown, tipovendaFilterDropdown, data.tipos_venda, selectedTiposVenda, () => {});
        // Enhance select filters to match multi-select appearance
        const selectsToEnhance = [
            document.getElementById('ano-filter'),
            document.getElementById('mes-filter'),
            document.getElementById('branch-ano-filter'),
            document.getElementById('branch-mes-filter'),
            document.getElementById('boxes-ano-filter'),
            document.getElementById('boxes-mes-filter'),
            document.getElementById('city-ano-filter'),
            document.getElementById('city-mes-filter'),
            document.getElementById('comparison-ano-filter'),
            document.getElementById('comparison-mes-filter'),
            document.getElementById('comparison-pasta-filter')
        ];
        selectsToEnhance.forEach(el => {
            if (el) enhanceSelectToCustomDropdown(el);
        });

        window.setupMultiSelect(categoriaFilterBtn, categoriaFilterDropdown, categoriaFilterList, data.categorias, selectedCategorias, () => {}, false, categoriaFilterSearch);

        // Rede Logic with "Com Rede" and "Sem Rede"
        const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
        window.setupMultiSelect(redeFilterBtn, redeFilterDropdown, redeFilterList, redes, selectedRedes, () => {}, false, redeFilterSearch);
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [filialFilterDropdown, cidadeFilterDropdown, supervisorFilterDropdown, vendedorFilterDropdown, fornecedorFilterDropdown, tipovendaFilterDropdown, redeFilterDropdown, categoriaFilterDropdown];
        const btns = [filialFilterBtn, cidadeFilterBtn, supervisorFilterBtn, vendedorFilterBtn, fornecedorFilterBtn, tipovendaFilterBtn, redeFilterBtn, categoriaFilterBtn];
        let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);
        if (anyClosed && !mainDashboardView.classList.contains('hidden')) {
            handleFilterChange();
        }
    });

    let filterDebounceTimer;
    let lastMainDashboardFiltersStr = "";
    const handleFilterChange = async () => {
        const filters = getCurrentFilters();
        const currentFiltersStr = JSON.stringify(filters);
        if (currentFiltersStr === lastMainDashboardFiltersStr) return; // No changes made
        lastMainDashboardFiltersStr = currentFiltersStr;
        
        clearTimeout(filterDebounceTimer);
        filterDebounceTimer = setTimeout(async () => {
            window.showDashboardLoading();
            try { await loadFilters(filters); } catch (err) { AppLog.error("Failed to load filters:", err); }
            try { await loadMainDashboardData(); } catch (err) { AppLog.error("Failed to load dashboard data:", err); }
            if (!cityView.classList.contains('hidden')) { currentCityPage = 0; await loadCityView(); }
        }, 500);
    };
    anoFilter.onchange = handleFilterChange;
    mesFilter.onchange = handleFilterChange;

    // Unified Fetch & Cache Logic
    async function fetchDashboardData(filters, isBackground = false, forceRefresh = false) {
        const cacheKey = generateCacheKey('dashboard_data', filters);
        const CACHE_TTL = 1000 * 60 * 60 * 24; // 24 Hours TTL (Relies on checkDataVersion for invalidation)

        // 1. Try Cache (unless forceRefresh is true)
        if (!forceRefresh) {
            try {
                const cachedEntry = await getFromCache(cacheKey);
                if (cachedEntry && cachedEntry.timestamp && cachedEntry.data) {
                    const age = Date.now() - cachedEntry.timestamp;
                    if (age < CACHE_TTL) {
                        if (!isBackground) AppLog.log('Serving from Cache (Instant)');
                        return { data: cachedEntry.data, source: 'cache', timestamp: cachedEntry.timestamp };
                    } else {
                         return { data: cachedEntry.data, source: 'stale', timestamp: cachedEntry.timestamp };
                    }
                }
            } catch (e) { AppLog.warn('Cache error:', e); }
        } else {
            AppLog.log('Force Refresh: Bypassing cache.');
        }

        // 2. Network Request
        if (isBackground) AppLog.log(`[Background] Fetching data from API...`);
        const { data, error } = await supabase.rpc('get_main_dashboard_data', filters);
        
        if (error) {
            AppLog.error('API Error:', error);
            return { data: null, error };
        }

        // 3. Save to Cache
        await saveToCache(cacheKey, data);
        if (isBackground) AppLog.log(`[Background] Cached successfully.`);

        return { data, source: 'api' };
    }

    async function loadMainDashboardData(forceRefresh = false) {
        const filters = getCurrentFilters();
        const cacheKey = generateCacheKey('dashboard_data', filters);
        
        // 1. Stale-While-Revalidate: Try Cache & Render Immediately
        if (!forceRefresh) {
            try {
                const cachedEntry = await getFromCache(cacheKey);
                if (cachedEntry && cachedEntry.data) {
                    AppLog.log('SWR: Rendering cached data immediately...');
                    renderDashboard(cachedEntry.data);
                    loadFrequencyTable(filters);
                    lastDashboardData = cachedEntry.data;

                    const age = Date.now() - cachedEntry.timestamp;
                    if (age < 60 * 1000) { // Fresh enough (1 min)
                         AppLog.log('SWR: Cache is fresh (<1min), skipping background fetch.');
                         await fetchLastSalesDate();
                         window.hideDashboardLoading();
                         prefetchViews(filters);
                         return;
                    } else {
                        AppLog.log('SWR: Cache is stale, fetching update in background...');
                        window.showDashboardLoading(); // Optional: show loading indicator non-intrusively
                    }
                } else {
                    window.showDashboardLoading();
                }
            } catch (e) {
                AppLog.warn('SWR Cache Error:', e);
                window.showDashboardLoading();
            }
        } else {
            window.showDashboardLoading();
        }

        // 2. Network Fetch (Background or Foreground)
        const [dashboardResult, _] = await Promise.all([
            fetchDashboardData(filters, false, true), // Force network fetch logic reusing existing func but we handle flow here
            fetchLastSalesDate()
        ]);

        const { data, error } = dashboardResult;
        
        if (data && !error) {
            AppLog.log('SWR: Updated with fresh data.');
            lastDashboardData = data;
            renderDashboard(data);
            await loadFrequencyTable(filters);

            // Prefetch Next
            prefetchViews(filters);
        }
        
        window.hideDashboardLoading();
    }

    // Prefetch Background Logic
    let prefetchDebounce;
    async function prefetchViews(filters) {
        clearTimeout(prefetchDebounce);

        const runPrefetch = async () => {
            if (document.hidden) return; // Save resources if tab hidden

            AppLog.log('[Prefetch] Starting background fetch for other views...');

            // 1. Branch Data (Aggregated RPC)
            const branchKey = generateCacheKey('branch_data', filters);
            const cachedBranch = await getFromCache(branchKey);

            if (!cachedBranch) {
                supabase.rpc('get_branch_comparison_data', filters)
                    .then(({ data, error }) => {
                        if (data && !error) saveToCache(branchKey, data);
                    });
            }

            // 2. City Data (First Page Only)
            const cityFilters = { ...filters, p_page: 0, p_limit: 50 };
            const cityKey = generateCacheKey('city_view_data', cityFilters);
            const cachedCity = await getFromCache(cityKey);

            if (!cachedCity) {
                supabase.rpc('get_city_view_data', cityFilters)
                    .then(({ data, error }) => {
                        if (data && !error) saveToCache(cityKey, data);
                    });
            }
        };

        prefetchDebounce = setTimeout(() => {
            if ('requestIdleCallback' in window) {
                requestIdleCallback(() => runPrefetch(), { timeout: 10000 });
            } else {
                setTimeout(runPrefetch, 100);
            }
        }, 5000);
    }

    async function fetchLastSalesDate() {
        if (lastSalesDate) return;

        try {
            const { data, error } = await supabase
                .from('data_detailed')
                .select('dtped')
                .order('dtped', { ascending: false })
                .limit(1)
                .maybeSingle();
            
            if (data && data.dtped) {
                // dtped is timestamp with time zone, e.g., "2026-01-20T14:00:00+00:00"
                // We want just the date part in YYYY-MM-DD for comparison
                lastSalesDate = data.dtped.split('T')[0];
            } else {
                lastSalesDate = null;
            }
        } catch (e) {
            AppLog.error("Error fetching last sales date:", e);
        }
    }

    // --- Background Prefetch Logic ---

    async function queueCommonFilters() {
        AppLog.log('[Background] Iniciando estratégia de pré-carregamento massivo...');
        const currentFilters = getCurrentFilters();
        const baseFilters = {
            p_ano: currentFilters.p_ano,
            p_mes: currentFilters.p_mes,
            p_filial: [], p_cidade: [], p_supervisor: [], p_vendedor: [], p_fornecedor: [], p_tipovenda: []
        };
        
        // Helper to check and add
        const checkAndAdd = async (label, filters) => {
             const key = generateCacheKey('dashboard_data', filters);
             const cached = await getFromCache(key);
             // We check existence only; validity is handled by data version clear
             if (!cached) {
                 addToPrefetchQueue(label, filters);
             }
        };

        const tasks = [];
        
        // 1. Filiais
        availableFiltersState.filiais.forEach(v => tasks.push(checkAndAdd(`Filial: ${v}`, { ...baseFilters, p_filial: [v] })));

        // 2. Supervisors
        availableFiltersState.supervisors.forEach(v => tasks.push(checkAndAdd(`Superv: ${v}`, { ...baseFilters, p_supervisor: [v] })));

        // 3. Cidades
        availableFiltersState.cidades.forEach(v => tasks.push(checkAndAdd(`Cidade: ${v}`, { ...baseFilters, p_cidade: [v] })));

        // 4. Vendedores
        availableFiltersState.vendedores.forEach(v => tasks.push(checkAndAdd(`Vend: ${v}`, { ...baseFilters, p_vendedor: [v] })));

        // 5. Fornecedores (Handle Object Structure)
        availableFiltersState.fornecedores.forEach(v => {
            const cod = v.cod || v; // Handle if object or raw
            tasks.push(checkAndAdd(`Forn: ${cod}`, { ...baseFilters, p_fornecedor: [String(cod)] }));
        });

        // 6. Tipos Venda
        availableFiltersState.tipos_venda.forEach(v => tasks.push(checkAndAdd(`Tipo: ${v}`, { ...baseFilters, p_tipovenda: [v] })));
        
        // 7. Redes
        availableFiltersState.redes.forEach(v => tasks.push(checkAndAdd(`Rede: ${v}`, { ...baseFilters, p_rede: [v] })));

        // 8. Categorias
        availableFiltersState.categorias.forEach(v => tasks.push(checkAndAdd(`Categoria: ${v}`, { ...baseFilters, p_categoria: [v] })));

        // Wait for all checks
        await Promise.all(tasks);

        if (prefetchQueue.length > 0) {
            AppLog.log(`[Background] ${prefetchQueue.length} filtros novos agendados.`);
            processQueue();
        } else {
            AppLog.log('[Background] Todos os filtros comuns já estão em cache.');
        }
    }

    function addToPrefetchQueue(label, filters) {
        // Avoid duplicates in queue
        const key = generateCacheKey('dashboard_data', filters);
        // Simple check if already queued (could be improved)
        if (!prefetchQueue.some(item => item.key === key)) {
            prefetchQueue.push({ label, filters, key });
        }
    }

    async function processQueue() {
        if (isPrefetching || prefetchQueue.length === 0) return;

        isPrefetching = true;
        const task = prefetchQueue.shift();
        
        AppLog.log(`[Background] Processando filtro para: ${task.label} (${prefetchQueue.length} restantes)`);
        
        // We use fetchDashboardData which handles the "Check Cache -> Fetch -> Save Cache" loop
        // We pass isBackground=true to suppress standard logs and enable specific ones
        await fetchDashboardData(task.filters, true);
        
        isPrefetching = false;
        
        // Schedule next task with a delay to yield to main thread (UI responsiveness)
        setTimeout(processQueue, 500); 
    }

    function renderDashboard(data) {
        // Init Holidays
        holidays = data.holidays || [];
        // Calendar is now rendered on modal open

        document.getElementById('kpi-clients-attended').textContent = formatInteger(data.kpi_clients_attended);
        const baseEl = document.getElementById('kpi-clients-base');
        if (data.kpi_clients_base > 0) {
            baseEl.textContent = `de ${formatInteger(data.kpi_clients_base)} na base`;
            baseEl.classList.remove('hidden');
        } else { baseEl.classList.add('hidden'); }

        let currentData = data.monthly_data_current || [];
        let previousData = data.monthly_data_previous || [];
        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const targetIndex = data.target_month_index;

        // KPI Calculation Variables
        let currFat, currKg, prevFat, prevKg, triAvgFat, triAvgPeso;
        let kpiTitleFat, kpiTitleKg;
        
        // --- KPI LOGIC (Scenario Check) ---
        if (mesFilter.value === '') {
            // SCENARIO A: Month All -> Show Year vs Previous Year (Accumulated)
            
            const sumData = (dataset, useTrend) => {
                let sumFat = 0; 
                let sumKg = 0;
                // Sum available months (0 to 11)
                dataset.forEach(d => {
                    // Check if this month is the trend month and use trend data if applicable
                    if (useTrend && data.trend_allowed && data.trend_data && d.month_index === data.trend_data.month_index) {
                        sumFat += data.trend_data.faturamento;
                        sumKg += data.trend_data.peso;
                    } else {
                        sumFat += d.faturamento;
                        sumKg += d.peso;
                    }
                });
                return { faturamento: sumFat, peso: sumKg };
            };

            const currSums = sumData(currentData, true);
            const prevSums = sumData(previousData, false);

            // Logic for Annual Trend Projection (Current Year Only)
            if (data.trend_allowed && data.trend_data) {
                // Formula: (Accumulated YTD + Projected Current Month) / (Months Passed) * 12
                // Note: sumData already includes the Projected Current Month if trend_allowed is true.
                const monthsPassed = data.trend_data.month_index + 1;

                currFat = (currSums.faturamento / monthsPassed) * 12;
                currKg = (currSums.peso / monthsPassed) * 12;
            } else {
                currFat = currSums.faturamento;
                currKg = currSums.peso;
            }

            prevFat = prevSums.faturamento;
            prevKg = prevSums.peso;
            
            kpiTitleFat = `Tend. Anual FAT vs Ano Ant.`;
            kpiTitleKg = `Tend. Anual TON vs Ano Ant.`;

        } else {
            // SCENARIO B: Default (Month vs Month or Filtered Month)
            
            if (mesFilter.value !== '') {
                const selectedMonthIndex = parseInt(mesFilter.value);
                currentData = currentData.filter(d => d.month_index === selectedMonthIndex);
                previousData = previousData.filter(d => d.month_index === selectedMonthIndex);
            }

            const currMonthData = currentData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };
            const prevMonthData = previousData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };

            // Helper for Trend Logic
            const getTrendValue = (key, baseValue) => {
                if (data.trend_allowed && data.trend_data && data.trend_data.month_index === targetIndex) {
                    return data.trend_data[key] || 0;
                }
                return baseValue;
            };

            currFat = getTrendValue('faturamento', currMonthData.faturamento);
            currKg = getTrendValue('peso', currMonthData.peso);
            prevFat = prevMonthData.faturamento;
            prevKg = prevMonthData.peso;

            const mName = monthNames[targetIndex]?.toUpperCase() || "";
            kpiTitleFat = `Tend. FAT ${mName} vs Ano Ant.`;
            kpiTitleKg = `Tend. TON ${mName} vs Ano Ant.`;
        }

        // Variation Calc
        const calcEvo = (curr, prev) => prev > 0 ? ((curr / prev) - 1) * 100 : (curr > 0 ? 100 : 0);

        // --- KPI Updates ---
        // Calc indicators for table (Perda/Devolução)
        const processIndicators = (d) => {
            const fat = d.faturamento || 0;
            const fatBase = d.total_sold_base || fat; // Use specific base if available, else fat
            d.perc_perda = fatBase > 0 ? (d.bonificacao / fatBase) * 100 : null;
            d.perc_devolucao = fatBase > 0 ? (d.devolucao / fatBase) * 100 : null;
        };
        currentData.forEach(processIndicators);
        previousData.forEach(processIndicators);
        if (data.trend_data) processIndicators(data.trend_data);

        // --- NEW KPIs (Bonification, Devolution, Mix) ---
        try {
            // Calculate Totals for Selected Period
            let kpiBonifCurr = 0, kpiBonifPrev = 0;
            let kpiDevolCurr = 0, kpiDevolPrev = 0;
            let kpiMixCurr = 0, kpiMixPrev = 0;
            let kpiTotalSoldBaseCurr = 0;

            let kpiMixCountCurr = 0, kpiMixCountPrev = 0;

            // Current Period Aggregation
            const aggCurrent = (d) => {
                kpiBonifCurr += (d.bonificacao || 0);
                kpiDevolCurr += (d.devolucao || 0);
                // Use total_sold_base if available, else fallback to faturamento
                kpiTotalSoldBaseCurr += (d.total_sold_base !== undefined ? d.total_sold_base : (d.faturamento || 0));
                if (d.mix_pdv > 0) { kpiMixCurr += d.mix_pdv; kpiMixCountCurr++; }
            };

            // Previous Period Aggregation
            const aggPrevious = (d) => {
                kpiBonifPrev += (d.bonificacao || 0);
                kpiDevolPrev += (d.devolucao || 0);
                if (d.mix_pdv > 0) { kpiMixPrev += d.mix_pdv; kpiMixCountPrev++; }
            };

            // Use filtered month data if month selected, otherwise all months
            const activeCurrentData = (mesFilter.value !== '') ? currentData.filter(d => d.month_index === targetIndex) : currentData;

            // Logic for Previous:
            // If Month selected, compare to same month prev year.
            // If Year selected, compare ONLY to the months available in the current year.
            let activePreviousData = [];
            if (mesFilter.value !== '') {
                activePreviousData = previousData.filter(d => d.month_index === targetIndex);
            } else {
                // Find the maximum month_index in the current year's data that has actual sales
                const maxCurrentMonthIndex = currentData.length > 0
                    ? Math.max(...currentData.map(d => d.month_index))
                    : -1;

                // Filter previous year's data to only include months up to maxCurrentMonthIndex
                activePreviousData = previousData.filter(d => d.month_index <= maxCurrentMonthIndex);
            }

            // Handle Trend for Current Year/Month
            activeCurrentData.forEach(d => {
                // If viewing Year and this is the trend month, use trend data
                if (data.trend_allowed && data.trend_data && d.month_index === data.trend_data.month_index) {
                    aggCurrent(data.trend_data);
                } else {
                    aggCurrent(d);
                }
            });
            activePreviousData.forEach(aggPrevious);

            // Averages for Mix
            const avgMixCurr = kpiMixCountCurr > 0 ? kpiMixCurr / kpiMixCountCurr : 0;
            const avgMixPrev = kpiMixCountPrev > 0 ? kpiMixPrev / kpiMixCountPrev : 0;

            // Calculate Percentages
            const percBonif = kpiTotalSoldBaseCurr > 0 ? (kpiBonifCurr / kpiTotalSoldBaseCurr) * 100 : 0;
            const percDevol = kpiTotalSoldBaseCurr > 0 ? (kpiDevolCurr / kpiTotalSoldBaseCurr) * 100 : 0;

            const varBonif = calcEvo(kpiBonifCurr, kpiBonifPrev);
            const varDevol = calcEvo(kpiDevolCurr, kpiDevolPrev);
            const varMix = calcEvo(avgMixCurr, avgMixPrev);

            // Render New KPIs
            const fmtBRL = (v) => formatCurrency(v);
            const fmtPerc = (v) => `${(isNaN(v) ? 0 : v).toFixed(1)}%`;

            // 1. Bonification
            document.getElementById('kpi-bonif-val').textContent = fmtBRL(kpiBonifCurr);
            const elBonifPerc = document.getElementById('kpi-bonif-perc');
            elBonifPerc.textContent = fmtPerc(percBonif);
            elBonifPerc.className = `text-lg font-bold ${percBonif <= 1.5 ? 'text-emerald-400' : 'text-red-400'}`;
            document.getElementById('kpi-bonif-sec').textContent = fmtBRL(kpiTotalSoldBaseCurr);

            // Update Corner Types (05, 11) - Defensive check
            const safeTypes = (typeof selectedTiposVenda !== 'undefined' && Array.isArray(selectedTiposVenda)) ? selectedTiposVenda : [];
            const types = safeTypes.filter(t => t === '5' || t === '11').sort().join(' e ');
            const typeLabel = types ? types : '05 e 11';
            document.getElementById('kpi-bonif-types').textContent = typeLabel;
            document.getElementById('kpi-bonif-var-types').textContent = typeLabel;

            // 2. Bonification Variation
            document.getElementById('kpi-bonif-var-val').textContent = fmtBRL(kpiBonifCurr);
            const elBonifVarPerc = document.getElementById('kpi-bonif-var-perc');
            elBonifVarPerc.textContent = `${varBonif > 0 ? '+' : ''}${varBonif.toFixed(1)}%`;
            elBonifVarPerc.className = `text-lg font-bold ${varBonif <= 0 ? 'text-emerald-400' : 'text-red-400'}`;
            document.getElementById('kpi-bonif-var-sec').textContent = fmtBRL(kpiBonifPrev);

            // 3. Devolução
            document.getElementById('kpi-devol-val').textContent = fmtBRL(kpiDevolCurr);
            const elDevolPerc = document.getElementById('kpi-devol-perc');
            elDevolPerc.textContent = fmtPerc(percDevol);
            elDevolPerc.className = `text-lg font-bold ${percDevol > 0 ? 'text-red-400' : 'text-emerald-400'}`;
            document.getElementById('kpi-devol-sec').textContent = fmtBRL(kpiTotalSoldBaseCurr);

            // 4. Devolução Variation
            document.getElementById('kpi-devol-var-val').textContent = fmtBRL(kpiDevolCurr);
            const elDevolVarPerc = document.getElementById('kpi-devol-var-perc');
            elDevolVarPerc.textContent = `${varDevol > 0 ? '+' : ''}${varDevol.toFixed(1)}%`;
            elDevolVarPerc.className = `text-lg font-bold ${varDevol <= 0 ? 'text-emerald-400' : 'text-red-400'}`;
            document.getElementById('kpi-devol-var-sec').textContent = fmtBRL(kpiDevolPrev);

            // 5. Mix PDV
            document.getElementById('kpi-mix-val').textContent = formatNumber(avgMixCurr, 2);
            const elMixPerc = document.getElementById('kpi-mix-perc');
            elMixPerc.textContent = `${varMix > 0 ? '+' : ''}${varMix.toFixed(1)}%`;
            elMixPerc.className = `text-lg font-bold ${varMix >= 0 ? 'text-emerald-400' : 'text-red-400'}`;
            document.getElementById('kpi-mix-sec').textContent = formatNumber(avgMixPrev, 2);
        } catch (err) {
            AppLog.error('Error updating new KPIs:', err);
        }

        updateKpiCard({
            prefix: 'fat',
            trendVal: currFat,
            prevVal: prevFat,
            fmt: (v) => formatCurrency(v),
            calcEvo
        });
        
        updateKpiCard({
            prefix: 'kg',
            trendVal: currKg,
            prevVal: prevKg,
            fmt: (v) => formatTons(v, 1),
            calcEvo
        });

        // --- KPI Month vs Trimester (Keep standard logic based on target month) ---
        let triSumFat = 0, triSumPeso = 0, triCount = 0;
        for (let i = 1; i <= 3; i++) {
            const idx = targetIndex - i;
            let mData;
            if (idx >= 0) {
                mData = data.monthly_data_current.find(d => d.month_index === idx);
            } else {
                const prevIdx = 12 + idx;
                mData = data.monthly_data_previous.find(d => d.month_index === prevIdx);
            }
            if (mData) { triSumFat += mData.faturamento; triSumPeso += mData.peso; triCount++; }
        }
        triAvgFat = triCount > 0 ? triSumFat / triCount : 0;
        triAvgPeso = triCount > 0 ? triSumPeso / triCount : 0;

        let currMonthFatForTri, currMonthKgForTri;
        
        if (mesFilter.value === '') {
             // In Year View, we still want the Tri card to make sense (Current Month vs Tri).
             // Let's re-fetch the specific current month data for the Tri calculation.
             const cMonthData = data.monthly_data_current.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };
             if (data.trend_allowed && data.trend_data && data.trend_data.month_index === targetIndex) {
                 currMonthFatForTri = data.trend_data.faturamento;
                 currMonthKgForTri = data.trend_data.peso;
             } else {
                 currMonthFatForTri = cMonthData.faturamento;
                 currMonthKgForTri = cMonthData.peso;
             }
        } else {
             // In Month View, currFat is already the monthly value
             currMonthFatForTri = currFat;
             currMonthKgForTri = currKg;
        }

        updateKpiCard({
            prefix: 'tri-fat',
            trendVal: currMonthFatForTri,
            prevVal: triAvgFat,
            fmt: (v) => formatCurrency(v),
            calcEvo
        });

        updateKpiCard({
            prefix: 'tri-kg',
            trendVal: currMonthKgForTri,
            prevVal: triAvgPeso,
            fmt: (v) => formatTons(v, 2),
            calcEvo
        });

        const mName = monthNames[targetIndex]?.toUpperCase() || "";
        
        // Update Titles
        document.getElementById('kpi-title-evo-ano-fat').textContent = kpiTitleFat;
        document.getElementById('kpi-title-evo-ano-kg').textContent = kpiTitleKg;
        document.getElementById('kpi-title-evo-tri-fat').textContent = `Tend. FAT ${mName} vs Trim. Ant.`;
        document.getElementById('kpi-title-evo-tri-kg').textContent = `Tend. TON ${mName} vs Trim. Ant.`;

        // --- CHART PREP (Responsive to Mode) ---
        const mainChartTitle = document.getElementById('main-chart-title');
        
        // Determine Bonification Mode
        const isBonifMode = isBonificationMode(getCurrentFilters().p_tipovenda);

        // Data Mapping Helper based on Mode
        const getDataValue = (d) => {
            if (isBonifMode && currentChartMode === 'faturamento') return d.bonificacao;
            return currentChartMode === 'faturamento' ? d.faturamento : d.peso;
        };
        
        // Formatters
        const currencyFormatter = (v) => formatChartLabel(v);
        const weightFormatter = (v) => formatChartLabel(v, ' Ton');
        const currentFormatter = currentChartMode === 'faturamento' ? currencyFormatter : weightFormatter;

        if (currentChartMode === 'faturamento') {
            mainChartTitle.textContent = isBonifMode ? "BONIFICADO MENSAL" : "FATURAMENTO MENSAL";
        } else {
            mainChartTitle.textContent = "TONELAGEM MENSAL";
        }

        const mapTo12 = (arr) => { 
            const res = new Array(12).fill(0); 
            arr.forEach(d => res[d.month_index] = getDataValue(d)); 
            return res; 
        };
        
        const datasets = [];

        datasets.push({ label: `Ano ${data.previous_year}`, data: mapTo12(previousData), isPrevious: true });
        datasets.push({ label: `Ano ${data.current_year}`, data: mapTo12(currentData), isCurrent: true });

        // Trend Logic (Chart)
        if (data.trend_allowed && data.trend_data) {
            const trendArray = new Array(13).fill(null); // Increased to 13 to separate trend
            // Pad previous datasets to 13
            datasets.forEach(ds => ds.data.push(null));
            
            trendArray[12] = getDataValue(data.trend_data); // Use 13th slot
            
            datasets.push({ 
                label: `Tendência ${monthNames[data.trend_data.month_index]}`, 
                data: trendArray,
                isTrend: true 
            });
        }

        const chartLabels = [...monthNames];
        if (data.trend_allowed) chartLabels.push('Tendência');

        createChart('main-chart', 'bar', chartLabels, datasets, currentFormatter);
        updateTable(currentData, previousData, data.current_year, data.previous_year, data.trend_allowed ? data.trend_data : null);
    }

    function updateKpi(id, value) {
        const el = document.getElementById(id);
        if(!el) return;
        el.textContent = `${value.toFixed(1)}%`;
        el.className = `text-2xl font-bold ${value >= 0 ? 'text-green-400' : 'text-red-400'}`;
    }

    function updateKpiCard({ prefix, trendVal, prevVal, fmt, calcEvo }) {
        const evo = calcEvo(trendVal, prevVal);
        
        const elTrend = document.getElementById(`kpi-value-trend-${prefix}`);
        const elPrev = document.getElementById(`kpi-value-prev-${prefix}`);
        const elVar = document.getElementById(`kpi-var-${prefix}`);

        if (elTrend) elTrend.textContent = fmt(trendVal);
        if (elPrev) elPrev.textContent = fmt(prevVal);
        if (elVar) {
            elVar.textContent = `${evo > 0 ? '+' : ''}${evo.toFixed(1)}%`;
            elVar.className = `font-bold ${evo >= 0 ? 'text-emerald-400' : 'text-red-400'}`;
        }
    }

    function formatChartLabel(v, suffix = '') {
        if (!v) return '';
        if (v >= 1000000) {
            return formatNumber(v / 1000000, 1) + ' M' + suffix;
        } else if (v >= 1000) {
            return (v / 1000).toFixed(0) + 'K' + suffix;
        }
        return v.toFixed(0) + suffix;
    }
    window.createChart = function createChart(canvasId, type, labels, datasetsData, formatterVal) {
        const container = document.getElementById(canvasId + 'Container');
        if (!container) return;
        container.innerHTML = '';
        const newCanvas = document.createElement('canvas');
        newCanvas.id = canvasId;
        container.appendChild(newCanvas);

        const ctx = newCanvas.getContext('2d');
        const professionalPalette = { 'current': '#379fae', 'previous': '#eaf7f8', 'trend': '#ffaa4d' };

        const datasets = datasetsData.map((d, i) => {
            let color = '#94a3b8'; // default
            if (d.isPrevious) color = professionalPalette.previous;
            if (d.isCurrent) color = professionalPalette.current;
            if (d.isTrend) color = professionalPalette.trend;
            
            return {
                ...d,
                label: d.label,
                data: d.data,
                backgroundColor: d.backgroundColor || color,
                borderColor: d.borderColor || color,
                borderWidth: d.borderWidth !== undefined ? d.borderWidth : (type === 'line' ? 2 : 0),
                borderSkipped: 'bottom',
                borderRadius: {
                    topLeft: 6,
                    topRight: 6,
                },
                skipNull: true
            };
        });

        if (currentCharts[canvasId]) currentCharts[canvasId].destroy();

        currentCharts[canvasId] = new Chart(ctx, {
            type: type,
            data: { labels, datasets },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: { top: 20 }
                },
                plugins: {
                    legend: { labels: { color: '#cbd5e1' } },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                let label = context.dataset.label || '';
                                if (label) {
                                    label += ': ';
                                }
                                if (context.parsed.y !== null) {
                                    label += formatInteger(context.parsed.y);
                                }
                                return label;
                            }
                        }
                    },
                    datalabels: {
                        display: true,
                        anchor: 'end',
                        align: 'top',
                        offset: 4,
                        color: '#cbd5e1',
                        font: { size: 11, weight: 'bold' },
                        formatter: formatterVal || ((v) => formatChartLabel(v))
                    }
                },
                scales: {
                    y: { 
                        grace: '10%',
                        ticks: { color: '#94a3b8' }, 
                        grid: { color: 'rgba(255, 255, 255, 0.05)' },
                        afterFit: (axis) => { axis.width = 150; } // Force Y-axis width to match table first column
                    },
                    x: { 
                        ticks: { color: '#94a3b8' }, 
                        grid: { color: 'rgba(255, 255, 255, 0.05)' } 
                    }
                }
            },
            plugins: [ChartDataLabels]
        });
    }

    window.toggleSummaryTable = function() {
        const table = document.getElementById('monthly-summary-table');
        if (table) {
            table.classList.toggle('collapsed-table');
        }
    };

    function updateTable(currData, prevData, currYear, prevYear, trendData) {
        const tableBody = document.getElementById('monthly-summary-table-body');
        const tableHead = document.querySelector('#monthly-summary-table thead tr');
        tableBody.innerHTML = '';

        const monthInitials = MONTHS_PT_INITIALS;
        let headerHTML = `
            <th class="px-2 py-2 text-left bg-transparent border-b border-white/50 relative">
                <div class="flex items-center gap-2">
                    <span>Indicadores</span>
                    <div id="summary-table-toggle-icon" class="hidden" style="display: none;"></div>
                </div>
            </th>`;
        monthInitials.forEach(m => headerHTML += `<th class="px-2 py-2 text-center bg-transparent border-b border-white/50 font-light text-xs text-gray-300 summary-col-header transition-opacity duration-300 opacity-0">${m}</th>`);
        if (trendData) {
            headerHTML += `<th class="px-2 py-2 text-center bg-transparent border-b border-white/50 text-[#ffaa4d] drop-shadow-[0_0_2px_rgba(255,170,77,0.5)] font-bold text-xs summary-col-header transition-opacity duration-300 opacity-0">Tendência</th>`;
        }
        tableHead.innerHTML = headerHTML;

        // Add cursor-pointer and onclick to the entire row, rather than just the first header cell
        tableHead.className = "cursor-pointer hover:text-gray-300 transition-colors";
        tableHead.onclick = window.toggleSummaryTable;

        const indicators = [
            { name: 'POSITIVAÇÃO', key: 'positivacao', fmt: v => formatInteger(v) },
            { name: 'FATURAMENTO', key: 'faturamento', fmt: v => formatCurrency(v) },
            { name: 'Mix PDV', key: 'mix_pdv', fmt: v => formatNumber(v, 2) },
            { name: 'Ticket Médio', key: 'ticket_medio', fmt: v => formatCurrency(v) },
            { name: 'BONIFICAÇÃO', key: 'bonificacao', fmt: v => formatCurrency(v) },
            { name: '% Perda', key: 'perc_perda', allowNull: true, fmt: v => v !== null ? `${v.toFixed(1)}%` : '-' },
            { name: 'DEVOLUÇÃO', key: 'devolucao', isRed: true, fmt: v => formatCurrency(v) },
            { name: '% Devolução', key: 'perc_devolucao', allowNull: true, fmt: v => v !== null ? `${v.toFixed(1)}%` : '-' },
            { name: 'TON VENDIDA', key: 'peso', fmt: v => `${(v/1000).toFixed(2)} Kg` }
        ];

        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        let tableHTML = '';
        indicators.forEach(ind => {
            tableHTML += `<tr class="table-row">`;
            tableHTML += `<td class="font-bold p-2 text-left">${escapeHtml(ind.name)}</td>`;

            for (let i = 0; i < 12; i++) {
                const d = currData.find(x => x.month_index === i);
                let val = d ? d[ind.key] : null;
                if (val === undefined) val = null;
                if (val === null && !ind.allowNull) val = 0;

                tableHTML += `<td class="px-2 py-1.5 text-center">`;
                if (ind.isRed) {
                    tableHTML += `<span class="text-red-400">${escapeHtml(ind.fmt(val))}</span>`;
                } else {
                    tableHTML += `${escapeHtml(ind.fmt(val))}`;
                }
                tableHTML += `</td>`;
            }
            if (trendData) {
                 let tVal = trendData[ind.key];
                 if (tVal === undefined) tVal = null;
                 if (tVal === null && !ind.allowNull) tVal = 0;

                 tableHTML += `<td class="px-2 py-1.5 text-center font-bold text-white">`;
                 if (ind.isRed) {
                     tableHTML += `<span class="text-red-400">${escapeHtml(ind.fmt(tVal))}</span>`;
                 } else {
                     tableHTML += `${escapeHtml(ind.fmt(tVal))}`;
                 }
                 tableHTML += `</td>`;
            }
            tableHTML += `</tr>`;
        });
        tableBody.innerHTML = tableHTML;
    }


    let citySelectedFiliais = [];
    let citySelectedCidades = [];
    let citySelectedSupervisores = [];
    let citySelectedVendedores = [];
    let citySelectedFornecedores = [];
    let citySelectedTiposVenda = [];
    let citySelectedRedes = [];
    let citySelectedCategorias = [];

    let cityFilterDebounceTimer;
    let lastCityFiltersStr = "";
    const handleCityFilterChange = () => {
        const filters = {
            p_filial: citySelectedFiliais.length > 0 ? citySelectedFiliais : null,
            p_cidade: citySelectedCidades.length > 0 ? citySelectedCidades : null,
            p_supervisor: citySelectedSupervisores.length > 0 ? citySelectedSupervisores : null,
            p_vendedor: citySelectedVendedores.length > 0 ? citySelectedVendedores : null,
            p_fornecedor: citySelectedFornecedores.length > 0 ? citySelectedFornecedores : null,
            p_tipovenda: citySelectedTiposVenda.length > 0 ? citySelectedTiposVenda : null,
            p_rede: citySelectedRedes.length > 0 ? citySelectedRedes : null,
            p_categoria: citySelectedCategorias.length > 0 ? citySelectedCategorias : null,
            p_ano: cityAnoFilter.value === 'todos' ? null : cityAnoFilter.value,
            p_mes: cityMesFilter.value === '' ? null : cityMesFilter.value
        };
        const currentFiltersStr = JSON.stringify(filters);
        if (currentFiltersStr === lastCityFiltersStr) return;
        lastCityFiltersStr = currentFiltersStr;
        
        clearTimeout(cityFilterDebounceTimer);
        cityFilterDebounceTimer = setTimeout(() => {
            currentCityPage = 0; 
            loadCityView();
        }, 500);
    };

    if (cityAnoFilter) cityAnoFilter.addEventListener('change', handleCityFilterChange);
    if (cityMesFilter) cityMesFilter.addEventListener('change', handleCityFilterChange);

    if (cityClearFiltersBtn) {
        cityClearFiltersBtn.addEventListener('click', () => {
             cityAnoFilter.value = 'todos';
             cityAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
             cityMesFilter.value = '';
             cityMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
             citySelectedFiliais.length = 0;
             citySelectedCidades.length = 0;
             citySelectedSupervisores.length = 0;
             citySelectedVendedores.length = 0;
             citySelectedFornecedores.length = 0;
             citySelectedTiposVenda.length = 0;
             citySelectedRedes.length = 0;
             citySelectedCategorias.length = 0;
             initCityFilters().then(loadCityView);
        });
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [cityFilialFilterDropdown, cityCidadeFilterDropdown, citySupervisorFilterDropdown, cityVendedorFilterDropdown, cityFornecedorFilterDropdown, cityTipovendaFilterDropdown, cityRedeFilterDropdown, cityCategoriaFilterDropdown];
        const btns = [cityFilialFilterBtn, cityCidadeFilterBtn, citySupervisorFilterBtn, cityVendedorFilterBtn, cityFornecedorFilterBtn, cityTipovendaFilterBtn, cityRedeFilterBtn, cityCategoriaFilterBtn];
        let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);
        if (anyClosed && !cityView.classList.contains('hidden')) {
            handleCityFilterChange();
        }
    });

    function setupCityMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
    return window.setupMultiSelect(btn, dropdown, container, items, selectedArray, () => {}, isObject, searchInput);
}

    async function initCityFilters() {
        const filters = {
            p_ano: null,
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: [],
            p_categoria: []
        };
         const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
         if (error) AppLog.error('Error fetching city filters:', error);
         if (!filterData) return;

         if (filterData.anos && cityAnoFilter) {
             const currentVal = cityAnoFilter.value;
             // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
             cityAnoFilter.innerHTML = '<option value="todos">Todos</option>' + filterData.anos.map(a => `<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
             if (currentVal && currentVal !== 'todos') cityAnoFilter.value = currentVal;
             else if (filterData.anos.length > 0) cityAnoFilter.value = filterData.anos[0];
             enhanceSelectToCustomDropdown(cityAnoFilter);
         }
         
         if (cityMesFilter && cityMesFilter.options.length <= 1) {
            const meses = MONTHS_PT;
            // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
            cityMesFilter.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${i}">${m}</option>`).join('');
            enhanceSelectToCustomDropdown(cityMesFilter);
        }

        setupCityMultiSelect(cityFilialFilterBtn, cityFilialFilterDropdown, cityFilialFilterDropdown, filterData.filiais, citySelectedFiliais);
        setupCityMultiSelect(cityCidadeFilterBtn, cityCidadeFilterDropdown, cityCidadeFilterList, filterData.cidades, citySelectedCidades, cityCidadeFilterSearch);
        setupCityMultiSelect(citySupervisorFilterBtn, citySupervisorFilterDropdown, citySupervisorFilterDropdown, filterData.supervisors, citySelectedSupervisores);
        setupCityMultiSelect(cityVendedorFilterBtn, cityVendedorFilterDropdown, cityVendedorFilterList, filterData.vendedores, citySelectedVendedores, cityVendedorFilterSearch);
        setupCityMultiSelect(cityFornecedorFilterBtn, cityFornecedorFilterDropdown, cityFornecedorFilterList, filterData.fornecedores, citySelectedFornecedores, cityFornecedorFilterSearch, true);
        setupCityMultiSelect(cityTipovendaFilterBtn, cityTipovendaFilterDropdown, cityTipovendaFilterDropdown, filterData.tipos_venda, citySelectedTiposVenda);
        setupCityMultiSelect(cityCategoriaFilterBtn, cityCategoriaFilterDropdown, cityCategoriaFilterList, filterData.categorias || [], citySelectedCategorias, cityCategoriaFilterSearch);

        const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
        setupCityMultiSelect(cityRedeFilterBtn, cityRedeFilterDropdown, cityRedeFilterList, redes, citySelectedRedes, cityRedeFilterSearch);
    }

    async function loadCityView() {
        window.showDashboardLoading('city-view');

        if (typeof initCityFilters === 'function' && cityAnoFilter && cityAnoFilter.options.length <= 1) {
             await initCityFilters();
        }

        const filters = {
            p_filial: citySelectedFiliais.length > 0 ? citySelectedFiliais : null,
            p_cidade: citySelectedCidades.length > 0 ? citySelectedCidades : null,
            p_supervisor: citySelectedSupervisores.length > 0 ? citySelectedSupervisores : null,
            p_vendedor: citySelectedVendedores.length > 0 ? citySelectedVendedores : null,
            p_fornecedor: citySelectedFornecedores.length > 0 ? citySelectedFornecedores : null,
            p_tipovenda: citySelectedTiposVenda.length > 0 ? citySelectedTiposVenda : null,
            p_rede: citySelectedRedes.length > 0 ? citySelectedRedes : null,
            p_categoria: citySelectedCategorias.length > 0 ? citySelectedCategorias : null,
            p_ano: cityAnoFilter.value === 'todos' ? null : cityAnoFilter.value,
            p_mes: cityMesFilter.value === '' ? null : cityMesFilter.value,
            p_page: currentCityPage,
            p_limit: cityPageSize
        };

        const { data, error } = await supabase.rpc('get_city_view_data', filters);
        
        window.hideDashboardLoading();

        if(error) { AppLog.error(error); return; }

        totalActiveClients = data.total_active_count || 0;

        // Helper to map array rows to object based on cols
        const mapRows = (dataObj) => {
             if (!dataObj || !dataObj.cols || !dataObj.rows) return dataObj || []; // Fallback for legacy format
             const cols = dataObj.cols;
             return dataObj.rows.map(row => {
                 const obj = {};
                 cols.forEach((col, idx) => {
                     obj[col] = row[idx];
                 });
                 return obj;
             });
        };

        const activeClients = Array.isArray(data.active_clients) ? data.active_clients : mapRows(data.active_clients);
        const cityRanking = data.city_ranking ? (Array.isArray(data.city_ranking) ? data.city_ranking : mapRows(data.city_ranking)) : [];

        // Refactored to use declarative template literals and innerHTML instead of verbose document.createElement logic.
        // This improves readability, maintainability, and significantly reduces code size while preserving XSS safety via escapeHtml.
        const renderTable = (bodyId, items) => {
            const body = document.getElementById(bodyId);
            if (!body) return;

            if (items && items.length > 0) {
                body.innerHTML = items.map(c => `
                    <tr class="table-row">
                        <td class="p-2">${escapeHtml(c['Código'] || '')}</td>
                        <td class="p-2">${escapeHtml(c.fantasia || c.razaoSocial || '')}</td>
                        ${c.totalFaturamento !== undefined ? `<td class="p-2 text-right">${escapeHtml(formatCurrency(c.totalFaturamento))}</td>` : ''}
                        <td class="p-2">${escapeHtml(c.cidade || '')}</td>
                        <td class="p-2">${escapeHtml(c.bairro || '')}</td>
                        ${c.ultimaCompra ? `<td class="p-2 text-center">${escapeHtml(new Date(c.ultimaCompra).toLocaleDateString('pt-BR'))}</td>` : ''}
                        <td class="p-2">${escapeHtml(c.rca1 || '-')}</td>
                    </tr>
                `).join('');
            } else {
                body.innerHTML = `<tr><td colspan="7" class="p-4 text-center text-slate-500">Nenhum registro encontrado.</td></tr>`;
            }
        };

        // Refactored to use declarative template literals and innerHTML instead of verbose document.createElement logic.
        // This improves readability, maintainability, and significantly reduces code size while preserving XSS safety via escapeHtml.
        const renderRankingTable = (bodyId, items) => {
            const body = document.getElementById(bodyId);
            if (!body) return;

            if (items && items.length > 0) {
                body.innerHTML = items.map(c => {
                    const varClass = c['Variação'] > 0 ? 'text-emerald-400' : (c['Variação'] < 0 ? 'text-red-400' : 'text-slate-400');
                    const varArrow = c['Variação'] > 0 ? '▲' : (c['Variação'] < 0 ? '▼' : '-');
                    return `
                        <tr class="table-row">
                            <td class="p-2 font-semibold">${escapeHtml(c['Cidade'] || '')}</td>
                            <td class="p-2 text-right text-cyan-400 font-bold">${escapeHtml(parseFloat(c['% Share']).toFixed(2))}%</td>
                            <td class="p-2 text-right font-bold ${varClass}">${varArrow} ${escapeHtml(Math.abs(c['Variação']).toFixed(2))}%</td>
                        </tr>
                    `;
                }).join('');
            } else {
                body.innerHTML = `<tr><td colspan="3" class="p-4 text-center text-slate-500">Nenhum registro encontrado.</td></tr>`;
            }
        };

        renderTable('city-active-detail-table-body', activeClients);
        renderRankingTable('city-ranking-table-body', cityRanking);

        renderCityPaginationControls();
    }


    let branchSelectedFiliais = [];
    let branchSelectedCidades = [];
    let branchSelectedSupervisores = [];
    let branchSelectedVendedores = [];
    let branchSelectedFornecedores = [];
    let branchSelectedTiposVenda = [];
    let branchSelectedRedes = [];
    let branchSelectedCategorias = [];
    let currentBranchChartMode = 'faturamento';

    // Filter Change Handler
    let branchFilterDebounceTimer;
    let lastBranchFiltersStr = "";
    const handleBranchFilterChange = () => {
        const filters = {
            p_ano: branchAnoFilter.value === 'todos' ? null : branchAnoFilter.value,
            p_mes: branchMesFilter.value === '' ? null : branchMesFilter.value,
            p_filial: branchSelectedFiliais.length > 0 ? branchSelectedFiliais : null,
            p_cidade: branchSelectedCidades.length > 0 ? branchSelectedCidades : null,
            p_supervisor: branchSelectedSupervisores.length > 0 ? branchSelectedSupervisores : null,
            p_vendedor: branchSelectedVendedores.length > 0 ? branchSelectedVendedores : null,
            p_fornecedor: branchSelectedFornecedores.length > 0 ? branchSelectedFornecedores : null,
            p_tipovenda: branchSelectedTiposVenda.length > 0 ? branchSelectedTiposVenda : null,
            p_rede: branchSelectedRedes.length > 0 ? branchSelectedRedes : null,
            p_categoria: branchSelectedCategorias.length > 0 ? branchSelectedCategorias : null
        };
        const currentFiltersStr = JSON.stringify(filters);
        if (currentFiltersStr === lastBranchFiltersStr) return;
        lastBranchFiltersStr = currentFiltersStr;
        
        clearTimeout(branchFilterDebounceTimer);
        branchFilterDebounceTimer = setTimeout(loadBranchView, 500);
    };

    if (branchAnoFilter) branchAnoFilter.addEventListener('change', handleBranchFilterChange);
    if (branchMesFilter) branchMesFilter.addEventListener('change', handleBranchFilterChange);
    if (branchCalendarBtn) branchCalendarBtn.addEventListener('click', openCalendar);
    if (branchChartToggleBtn) {
        branchChartToggleBtn.addEventListener('click', () => {
            currentBranchChartMode = currentBranchChartMode === 'faturamento' ? 'peso' : 'faturamento';
            loadBranchView();
        });
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [branchFilialFilterDropdown, branchCidadeFilterDropdown, branchSupervisorFilterDropdown, branchVendedorFilterDropdown, branchFornecedorFilterDropdown, branchTipovendaFilterDropdown, branchRedeFilterDropdown, branchCategoriaFilterDropdown];
        const btns = [branchFilialFilterBtn, branchCidadeFilterBtn, branchSupervisorFilterBtn, branchVendedorFilterBtn, branchFornecedorFilterBtn, branchTipovendaFilterBtn, branchRedeFilterBtn, branchCategoriaFilterBtn];
        let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);
        if (anyClosed && !branchView.classList.contains('hidden')) {
            handleBranchFilterChange();
        }
    });
    
    branchClearFiltersBtn?.addEventListener('click', () => {
         branchAnoFilter.value = 'todos';
         branchAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
         branchMesFilter.value = '';
         branchMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
         branchSelectedFiliais.length = 0; // Reset but re-init will likely pick first 2
         branchSelectedCidades.length = 0;
         branchSelectedSupervisores.length = 0;
         branchSelectedVendedores.length = 0;
         branchSelectedFornecedores.length = 0;
         branchSelectedTiposVenda.length = 0;
         branchSelectedRedes.length = 0;
         branchSelectedCategorias.length = 0;
         // Re-init filters to update UI
         initBranchFilters().then(loadBranchView);
    });


    async function initBranchFilters() {
        const filters = {
            p_ano: null,
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: [],
            p_categoria: []
        };
         const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
         if (error) AppLog.error('Error fetching branch filters:', error);
         if (!filterData) return;

         // Years
         if (filterData.anos) {
             const currentVal = branchAnoFilter.value;
             // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
             branchAnoFilter.innerHTML = '<option value="todos">Todos</option>' + filterData.anos.map(a => `<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
             // Preserve selection or default to current year
             if (currentVal && currentVal !== 'todos') branchAnoFilter.value = currentVal;
             else if (filterData.anos.length > 0) branchAnoFilter.value = filterData.anos[0];
             enhanceSelectToCustomDropdown(branchAnoFilter);
         }
         
         // Months
         if (branchMesFilter.options.length <= 1) {
            const meses = MONTHS_PT;
            branchMesFilter.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${i}">${m}</option>`).join('');
            enhanceSelectToCustomDropdown(branchMesFilter);
        }

        // Multi Selects
        setupBranchFilialSelect(branchFilialFilterBtn, branchFilialFilterDropdown, branchFilialFilterDropdown, filterData.filiais, branchSelectedFiliais);
        setupBranchMultiSelect(branchCidadeFilterBtn, branchCidadeFilterDropdown, branchCidadeFilterList, filterData.cidades, branchSelectedCidades, branchCidadeFilterSearch);
        setupBranchMultiSelect(branchSupervisorFilterBtn, branchSupervisorFilterDropdown, branchSupervisorFilterDropdown, filterData.supervisors, branchSelectedSupervisores);
        setupBranchMultiSelect(branchVendedorFilterBtn, branchVendedorFilterDropdown, branchVendedorFilterList, filterData.vendedores, branchSelectedVendedores, branchVendedorFilterSearch);
        setupBranchMultiSelect(branchFornecedorFilterBtn, branchFornecedorFilterDropdown, branchFornecedorFilterList, filterData.fornecedores, branchSelectedFornecedores, branchFornecedorFilterSearch, true);
        setupBranchMultiSelect(branchTipovendaFilterBtn, branchTipovendaFilterDropdown, branchTipovendaFilterDropdown, filterData.tipos_venda, branchSelectedTiposVenda);
        setupBranchMultiSelect(branchCategoriaFilterBtn, branchCategoriaFilterDropdown, branchCategoriaFilterList, filterData.categorias || [], branchSelectedCategorias, branchCategoriaFilterSearch);

        const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
        setupBranchMultiSelect(branchRedeFilterBtn, branchRedeFilterDropdown, branchRedeFilterList, redes, branchSelectedRedes, branchRedeFilterSearch);
    }
    
    // Specific setup for Branch Filter to enforce 2 selections
    function setupBranchFilialSelect(btn, dropdown, container, items, selectedArray) {
        // If nothing selected, default to first 2
        if (selectedArray.length === 0 && items && items.length > 0) {
            selectedArray.push(String(items[0]));
            if(items.length > 1) selectedArray.push(String(items[1]));
        }

        btn.onclick = (e) => {
        e.stopPropagation();
        const isHidden = dropdown.classList.contains('hidden');
        // Close all dropdowns
        closeAllDropdowns();
        // Restore this one if it was hidden
        if (isHidden) {
            dropdown.classList.remove('hidden');
        }
    };
        
        const selectedSet = new Set(selectedArray);
        const renderItems = () => {
            container.innerHTML = '';
            const fragment = document.createDocumentFragment();
            (items || []).forEach(item => {
                const val = String(item);
                const isSelected = selectedSet.has(val);
                const div = document.createElement('div');
                div.className = 'flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded';

                const input = document.createElement('input');
                input.type = 'checkbox';
                input.value = val;
                input.className = 'w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2';
                if (isSelected) input.checked = true;

                const labelEl = document.createElement('label');
                labelEl.className = 'ml-2 text-sm text-slate-200 cursor-pointer flex-1';
                labelEl.textContent = val;

                div.appendChild(input);
                div.appendChild(labelEl);
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    // Toggle logic
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    
                    if (checkbox.checked) {
                        if (!selectedSet.has(val)) {
                            selectedSet.add(val);
                            selectedArray.push(val);
                            // Enforce max 2: remove first added
                            if (selectedArray.length > 2) {
                                const removed = selectedArray.shift();
                                selectedSet.delete(removed);
                            }
                        }
                    } else {
                        if (selectedSet.has(val)) {
                            selectedSet.delete(val);
                            const idx = selectedArray.indexOf(val);
                            if (idx > -1) selectedArray.splice(idx, 1);
                        }
                    }
                    
                    renderItems(); // Re-render to update checks visually (e.g. if one was auto-removed)
                    updateBtnLabel();
                };
                fragment.appendChild(div);
            });
            container.appendChild(fragment);
            if (!items || items.length === 0) container.innerHTML = '<div class="p-2 text-sm text-slate-500 text-center">Nenhum item encontrado</div>';
        };
        
        const updateBtnLabel = () => {
            const span = btn.querySelector('span');
            if (selectedArray.length === 0) span.textContent = 'Selecione 2';
            else span.textContent = `${selectedArray.length} selecionadas`;
        };
        
        renderItems();
        updateBtnLabel();
    }

    function setupBranchMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
    return window.setupMultiSelect(btn, dropdown, container, items, selectedArray, () => {}, isObject, searchInput);
}

    async function loadBranchView() {
        window.showDashboardLoading('branch-view');

        // Populate Dropdowns if needed
        if (branchAnoFilter.options.length <= 1) {
            await initBranchFilters(); 
        }

        // Prepare Filters for RPC
        const selectedYear = branchAnoFilter.value === 'todos' ? null : branchAnoFilter.value;
        const selectedMonth = branchMesFilter.value === '' ? null : branchMesFilter.value;

        const filters = {
            p_ano: selectedYear,
            p_mes: selectedMonth,
            p_filial: branchSelectedFiliais.length > 0 ? branchSelectedFiliais : null,
            p_cidade: branchSelectedCidades.length > 0 ? branchSelectedCidades : null,
            p_supervisor: branchSelectedSupervisores.length > 0 ? branchSelectedSupervisores : null,
            p_vendedor: branchSelectedVendedores.length > 0 ? branchSelectedVendedores : null,
            p_fornecedor: branchSelectedFornecedores.length > 0 ? branchSelectedFornecedores : null,
            p_tipovenda: branchSelectedTiposVenda.length > 0 ? branchSelectedTiposVenda : null,
            p_rede: branchSelectedRedes.length > 0 ? branchSelectedRedes : null,
            p_categoria: branchSelectedCategorias.length > 0 ? branchSelectedCategorias : null
        };

        // Aggregated Fetch (Fast Response)
        const cacheKey = generateCacheKey('branch_data', filters);
        let branchDataMap = null;

        try {
            const cachedEntry = await getFromCache(cacheKey);
            if (cachedEntry && cachedEntry.data) {
                AppLog.log('Serving Branch View from Cache');
                branchDataMap = cachedEntry.data;
            } else {
                const { data, error } = await supabase.rpc('get_branch_comparison_data', filters);
                if (!error && data) {
                    branchDataMap = data;
                    saveToCache(cacheKey, data);
                } else {
                    AppLog.error('Erro ao carregar filiais:', error);
                }
            }
        } catch (e) {
            AppLog.error("Erro geral no fetch de filiais:", e);
        }
        
        window.hideDashboardLoading();
        if (branchDataMap) {
            renderBranchDashboard(branchDataMap, selectedYear, selectedMonth);
        }
    }

    function renderBranchDashboard(branchDataMap, selectedYear, selectedMonth) {
         const now = new Date();
         const branches = Object.keys(branchDataMap).sort();
         const kpiBranches = {}; 
         const chartBranches = {};
         const monthNames = MONTHS_PT;

         // Determine Bonification Mode
         const isBonifMode = isBonificationMode(branchSelectedTiposVenda);

         // Title Logic
         const chartTitleEl = document.getElementById('branch-chart-title');
         if (chartTitleEl) {
             if (currentBranchChartMode === 'faturamento') {
                 chartTitleEl.textContent = isBonifMode ? "COMPARATIVO POR FILIAL - BONIFICADO" : "COMPARATIVO POR FILIAL - FATURAMENTO";
             } else {
                 chartTitleEl.textContent = "COMPARATIVO POR FILIAL - TONELAGEM";
             }
         }

         // Process Data from RPC Results
         branches.forEach(b => {
             const data = branchDataMap[b];
             let monthlyData = data.monthly_data_current || [];
             
             // If month is selected, filter data
             if (selectedMonth !== null && selectedMonth !== undefined && selectedMonth !== '') {
                 const monthIdx = parseInt(selectedMonth);
                 monthlyData = monthlyData.filter(d => d.month_index === monthIdx);
             }

             // Chart Data: Map to 12 months array
             const chartArr = new Array(12).fill(0);
             monthlyData.forEach(d => {
                 // d has month_index (0-11)
                 if (d.month_index >= 0 && d.month_index < 12) {
                     if (currentBranchChartMode === 'faturamento') {
                         chartArr[d.month_index] = isBonifMode ? d.bonificacao : d.faturamento;
                     } else {
                         chartArr[d.month_index] = d.peso;
                     }
                 }
             });
             chartBranches[b] = chartArr;

             // KPI Data
             let kpiFat = 0;
             let kpiKg = 0;

             if (!selectedYear || selectedYear === 'todos') {
                 // "Todos" -> Current Month (of Current Year)
                 // If month is NOT selected via filter (default view)
                 const targetMonthIdx = now.getMonth();
                 const mData = monthlyData.find(d => d.month_index === targetMonthIdx);
                 if (mData) {
                     kpiFat = mData.faturamento || 0;
                     kpiKg = mData.peso || 0;
                 }
             } else {
                 // Specific Year -> Sum of returned monthly data
                 // If month is selected, monthlyData is already filtered, so this sums just that month
                 monthlyData.forEach(d => {
                     kpiFat += (d.faturamento || 0);
                     kpiKg += (d.peso || 0);
                 });
             }
             
             kpiBranches[b] = { faturamento: kpiFat, peso: kpiKg };
         });

         // --- KPI Rendering ---
         // Ensure we display consistent order as fetched/selected
         const b1 = branches[0] || 'N/A';
         const b2 = branches[1] || 'N/A';
         
         const val1Fat = kpiBranches[b1]?.faturamento || 0;
         const val2Fat = kpiBranches[b2]?.faturamento || 0;
         const val1Kg = kpiBranches[b1]?.peso || 0;
         const val2Kg = kpiBranches[b2]?.peso || 0;

         const elB1Name = document.getElementById('branch-name-1'); if(elB1Name) elB1Name.textContent = b1;
         const elB2Name = document.getElementById('branch-name-2'); if(elB2Name) elB2Name.textContent = b2;
         const elVal1Fat = document.getElementById('branch-val-1-fat'); if(elVal1Fat) elVal1Fat.textContent = formatCurrency(val1Fat);
         const elVal2Fat = document.getElementById('branch-val-2-fat'); if(elVal2Fat) elVal2Fat.textContent = formatCurrency(val2Fat);
         
         // Variations Logic
         // Share of Total (Val / Total)
         
         const calcShare = (val, total) => {
             if (total > 0) return (val / total) * 100;
             return 0;
         };
         
         const totalFat = val1Fat + val2Fat;
         const share1Fat = calcShare(val1Fat, totalFat);
         const share2Fat = calcShare(val2Fat, totalFat);

         const elVar1Fat = document.getElementById('branch-var-1-fat');
         if(elVar1Fat) {
             elVar1Fat.textContent = `${share1Fat.toFixed(1)}%`;
             elVar1Fat.className = `text-sm font-bold mt-1 ${share1Fat >= 50 ? 'text-emerald-400' : 'text-red-400'}`;
         }
         const elVar2Fat = document.getElementById('branch-var-2-fat');
         if(elVar2Fat) {
             elVar2Fat.textContent = `${share2Fat.toFixed(1)}%`;
             elVar2Fat.className = `text-sm font-bold mt-1 ${share2Fat >= 50 ? 'text-emerald-400' : 'text-red-400'}`;
         }


         const elB1NameKg = document.getElementById('branch-name-1-kg'); if(elB1NameKg) elB1NameKg.textContent = b1;
         const elB2NameKg = document.getElementById('branch-name-2-kg'); if(elB2NameKg) elB2NameKg.textContent = b2;
         const elVal1Kg = document.getElementById('branch-val-1-kg'); if(elVal1Kg) elVal1Kg.textContent = formatTons(val1Kg, 1);
         const elVal2Kg = document.getElementById('branch-val-2-kg'); if(elVal2Kg) elVal2Kg.textContent = formatTons(val2Kg, 1);

         const totalKg = val1Kg + val2Kg;
         const share1Kg = calcShare(val1Kg, totalKg);
         const share2Kg = calcShare(val2Kg, totalKg);

         const elVar1Kg = document.getElementById('branch-var-1-kg');
         if(elVar1Kg) {
             elVar1Kg.textContent = `${share1Kg.toFixed(1)}%`;
             elVar1Kg.className = `text-sm font-bold mt-1 ${share1Kg >= 50 ? 'text-emerald-400' : 'text-red-400'}`;
         }
         const elVar2Kg = document.getElementById('branch-var-2-kg');
         if(elVar2Kg) {
             elVar2Kg.textContent = `${share2Kg.toFixed(1)}%`;
             elVar2Kg.className = `text-sm font-bold mt-1 ${share2Kg >= 50 ? 'text-emerald-400' : 'text-red-400'}`;
         }
         
         // Update Title Context
         let kpiContext;
         if (!selectedYear || selectedYear === 'todos') {
             kpiContext = `Mês Atual (${now.toLocaleDateString('pt-BR', { month: 'long' })})`;
         } else {
             if (selectedMonth !== null && selectedMonth !== undefined && selectedMonth !== '') {
                 kpiContext = `${monthNames[parseInt(selectedMonth)]} ${selectedYear}`;
             } else {
                 kpiContext = `Ano ${selectedYear}`;
             }
         }
         const elTitleFat = document.getElementById('branch-kpi-title-fat'); if(elTitleFat) elTitleFat.textContent = `Faturamento (${kpiContext})`;
         const elTitleKg = document.getElementById('branch-kpi-title-kg'); if(elTitleKg) elTitleKg.textContent = `Tonelagem (${kpiContext})`;

         const elTotalTitleFat = document.getElementById('branch-total-kpi-title-fat'); if(elTotalTitleFat) elTotalTitleFat.textContent = `Faturamento Total (${kpiContext})`;
         const elTotalTitleKg = document.getElementById('branch-total-kpi-title-kg'); if(elTotalTitleKg) elTotalTitleKg.textContent = `Tonelagem Total (${kpiContext})`;

         const elTotalValFat = document.getElementById('branch-total-fat-val'); if(elTotalValFat) elTotalValFat.textContent = formatCurrency(totalFat);
         const elTotalValKg = document.getElementById('branch-total-kg-val'); if(elTotalValKg) elTotalValKg.textContent = formatTons(totalKg, 1);


         // --- Chart Rendering ---
         const datasets = [];
         const colors = ['#379fae', '#eaf7f8', '#06b6d4', '#8b5cf6'];
         const trendColors = ['#ffaa4d', '#ffce99', '#ff8b3d', '#ffdfb3'];

         branches.forEach((b, idx) => {
             datasets.push({
                 label: b,
                 data: chartBranches[b] || new Array(12).fill(0),
                 backgroundColor: colors[idx % colors.length],
                 borderColor: colors[idx % colors.length],
                 borderWidth: 1
             });
         });
         
         const chartYear = (!selectedYear || selectedYear === 'todos') ? now.getFullYear() : parseInt(selectedYear);
         
         // Check if ANY branch has trend data available
         const hasTrendData = branches.some(b => {
             const bData = branchDataMap[b];
             return bData && bData.trend_allowed && bData.trend_data;
         });
         
         if (hasTrendData) {
             branches.forEach((b, idx) => {
                 const bData = branchDataMap[b];
                 if (bData && bData.trend_allowed && bData.trend_data) {
                     const tVal = currentBranchChartMode === 'faturamento' ? (bData.trend_data.faturamento || 0) : (bData.trend_data.peso || 0);
                     if (datasets[idx]) datasets[idx].data.push(tVal);
                 } else {
                     if (datasets[idx]) datasets[idx].data.push(0);
                 }
                 
                 // Update colors to highlight trend
                 const baseColor = colors[idx % colors.length];
                 const trendColor = trendColors[idx % trendColors.length];
                 
                 // Create array of colors: 12 months + 1 trend
                 const bgColors = new Array(12).fill(baseColor);
                 bgColors.push(trendColor);
                 
                 datasets[idx].backgroundColor = bgColors;
                 datasets[idx].borderColor = bgColors;
             });
             
             const labels = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez", "Tendência"];
             const fmt = currentBranchChartMode === 'faturamento' 
                ? (v) => formatChartLabel(v)
                : (v) => formatChartLabel(v, ' Ton');
             createChart('branch-chart', 'bar', labels, datasets, fmt);
         } else {
             const labels = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
             const fmt = currentBranchChartMode === 'faturamento' 
                ? (v) => formatChartLabel(v)
                : (v) => formatChartLabel(v, ' Ton');
             createChart('branch-chart', 'bar', labels, datasets, fmt);
         }
    }

    function renderCityPaginationControls() {
        const container = document.getElementById('city-pagination-container');
        const totalPages = Math.ceil(totalActiveClients / cityPageSize);
        const startItem = (currentCityPage * cityPageSize) + 1;
        const endItem = Math.min((currentCityPage + 1) * cityPageSize, totalActiveClients);

        container.innerHTML = '';

        const wrapper = document.createElement('div');
        wrapper.className = 'flex justify-between items-center mt-4 px-4 text-sm text-slate-400';

        const infoDiv = document.createElement('div');
        infoDiv.textContent = `Mostrando ${totalActiveClients > 0 ? startItem : 0} a ${endItem} de ${totalActiveClients}`;

        const controlsDiv = document.createElement('div');
        controlsDiv.className = 'flex gap-2';

        const prevBtn = document.createElement('button');
        prevBtn.id = 'city-prev-btn';
        prevBtn.className = 'px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed';
        prevBtn.textContent = 'Anterior';
        if (currentCityPage === 0) {
            prevBtn.disabled = true;
            prevBtn.title = 'Primeira página';
        }
        prevBtn.addEventListener('click', () => {
            if (currentCityPage > 0) { currentCityPage--; loadCityView(); }
        });

        const pageSpan = document.createElement('span');
        pageSpan.textContent = `${currentCityPage + 1} / ${totalPages || 1}`;

        const nextBtn = document.createElement('button');
        nextBtn.id = 'city-next-btn';
        nextBtn.className = 'px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed';
        nextBtn.textContent = 'Próxima';
        if (currentCityPage >= totalPages - 1) {
            nextBtn.disabled = true;
            nextBtn.title = 'Última página';
        }
        nextBtn.addEventListener('click', () => {
            if (currentCityPage < totalPages - 1) { currentCityPage++; loadCityView(); }
        });

        controlsDiv.appendChild(prevBtn);
        controlsDiv.appendChild(pageSpan);
        controlsDiv.appendChild(nextBtn);

        wrapper.appendChild(infoDiv);
        wrapper.appendChild(controlsDiv);

        container.appendChild(wrapper);
    }

    // --- Calendar Logic ---
    function renderCalendar() {
        if (!calendarModalContent) return;

        const now = new Date();
        let year = now.getFullYear();
        let month = now.getMonth();
        
        // Respect Filters if selected
        if (anoFilter && anoFilter.value !== 'todos') {
            year = parseInt(anoFilter.value);
            // If year selected but month is "Todos", default to January for that year
            // Unless it's current year, then maybe current month?
            if (mesFilter && mesFilter.value === '') {
                 if (year !== now.getFullYear()) {
                     month = 0;
                 }
            }
        }
        
        if (mesFilter && mesFilter.value !== '') {
            month = parseInt(mesFilter.value);
        }

        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        
        const daysInMonth = lastDay.getDate();
        const startingDay = firstDay.getDay(); // 0 = Sunday

        const monthNames = MONTHS_PT;

        let html = `<div class="mb-2 font-bold text-slate-300 text-center">${escapeHtml(monthNames[month])} ${escapeHtml(year)}</div>`;
        html += `<div class="grid grid-cols-7 gap-1 text-center">`;
        
        const weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
        weekDays.forEach(day => html += `<div class="w-8 h-8 flex items-center justify-center text-xs font-bold text-slate-500 cursor-default">${escapeHtml(day)}</div>`);

        // Empty cells for starting day
        for (let i = 0; i < startingDay; i++) {
            html += `<div></div>`;
        }

        // Days
        for (let day = 1; day <= daysInMonth; day++) {
            const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const isHoliday = holidays.includes(dateStr);
            const isToday = (day === now.getDate() && month === now.getMonth() && year === now.getFullYear());
            const isLastSalesDay = (dateStr === lastSalesDate);
            
            let classes = 'calendar-day w-8 h-8 flex items-center justify-center rounded cursor-pointer text-xs transition-colors';

            if (isHoliday) {
                classes += ' bg-red-600 text-white font-bold hover:bg-red-700';
            } else {
                classes += ' text-slate-300 hover:bg-slate-700';
            }

            if (isToday) classes += ' ring-1 ring-inset ring-cyan-500';
            if (isLastSalesDay) classes += ' border-2 border-emerald-500 bg-emerald-500/20 text-emerald-400 font-bold';
            
            html += `<div class="${classes}" data-date="${escapeHtml(dateStr)}" title="${isLastSalesDay ? 'Última Venda' : ''}">${escapeHtml(day)}</div>`;
        }
        
        html += `</div>`;
        
        // Legend
        html += `
            <div class="mt-4 flex flex-col gap-2 text-xs text-slate-400">
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 bg-red-600 rounded"></div>
                    <span>Feriado</span>
                </div>
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 border-2 border-emerald-500 bg-emerald-500/20 rounded"></div>
                    <span>Última Venda (Base Tendência)</span>
                </div>
                <div class="flex items-center gap-2">
                    <div class="w-3 h-3 border border-cyan-500 rounded"></div>
                    <span>Data Atual (Hoje)</span>
                </div>
            </div>
        `;

        calendarModalContent.innerHTML = html;

        // Add Click Listeners
        calendarModalContent.querySelectorAll('.calendar-day[data-date]').forEach(el => {
            el.addEventListener('click', async () => {
                AppLog.log("Calendar day clicked:", el.getAttribute('data-date'));
                
                if (window.userRole !== 'adm') {
                    AppLog.warn("User role not adm:", window.userRole);
                    window.showToast('error', "Apenas administradores podem alterar feriados.");
                    return;
                }
                
                const date = el.getAttribute('data-date');
                const isSelected = el.classList.contains('selected');
                const [y, m, d] = date.split('-');
                const formattedDate = `${d}/${m}/${y}`;
                
                const confirmMsg = isSelected 
                    ? `Você deseja remover o feriado de ${formattedDate}?` 
                    : `Você deseja selecionar ${formattedDate} como feriado?`;

                if (!confirm(confirmMsg)) return;

                // Optimistic UI Update
                el.classList.toggle('selected');
                
                // Call RPC
                const { data: result, error } = await supabase.rpc('toggle_holiday', { p_date: date });
                if (error) {
                    AppLog.error("Error toggling holiday:", error);
                    el.classList.toggle('selected'); // Revert
                    window.showToast('error', "Erro ao alterar feriado: " + error.message);
                } else {
                    AppLog.log("Holiday toggled successfully.");
                    
                    // Update local holidays array
                    if (isSelected) {
                        holidays = holidays.filter(h => h !== date);
                    } else {
                        holidays.push(date);
                    }

                    // Reload Data to update trend
                    // Force refresh to bypass cache and get updated trend/holiday data
                    loadMainDashboardData(true);
                }
            });
        });
    }
 

        let selectedComparisonSupervisors = [];
        let selectedComparisonSellers = [];
        let selectedComparisonSuppliers = [];
        let selectedComparisonProducts = [];
        let selectedComparisonTiposVenda = [];
        let selectedComparisonRedes = [];
        let selectedComparisonFiliais = [];
    let selectedComparisonCities = [];
        let selectedComparisonCategorias = [];
        let useTendencyComparison = false;
        let comparisonChartType = 'weekly';
        let comparisonMonthlyMetric = 'faturamento';

        let comparisonFilterDebounceTimer;
        let lastComparisonFiltersStr = "";
        const handleComparisonFilterChange = () => {
            let pFornecedorValue = selectedComparisonSuppliers.length > 0 ? selectedComparisonSuppliers : null;
            
            // Apply "Pasta" filter logic on top of existing fornecedor if 'ambas' is not selected
            // "Pasta" is conceptually a macro-fornecedor. 
            if (comparisonPastaFilter && comparisonPastaFilter.value !== 'ambas') {
                const pastaSuppliers = comparisonPastaFilter.value === 'ELMA' ? ['707', '708', '752'] : ['1119'];
                if (!pFornecedorValue) {
                    pFornecedorValue = [...pastaSuppliers];
                } else {
                    const combined = new Set([...pFornecedorValue, ...pastaSuppliers]);
                    pFornecedorValue = Array.from(combined);
                }
            }

            const filters = {
                p_filial: selectedComparisonFiliais.length > 0 ? selectedComparisonFiliais : null,
                p_cidade: selectedComparisonCities.length > 0 ? selectedComparisonCities : null,
                p_supervisor: selectedComparisonSupervisors.length > 0 ? selectedComparisonSupervisors : null,
                p_vendedor: selectedComparisonSellers.length > 0 ? selectedComparisonSellers : null,
                p_fornecedor: pFornecedorValue,
                p_produto: selectedComparisonProducts.length > 0 ? selectedComparisonProducts : null,
                p_tipovenda: selectedComparisonTiposVenda.length > 0 ? selectedComparisonTiposVenda : null,
                p_rede: selectedComparisonRedes.length > 0 ? selectedComparisonRedes : null,
                p_categoria: selectedComparisonCategorias.length > 0 ? selectedComparisonCategorias : null,
                p_ano: comparisonAnoFilter.value,
                p_mes: comparisonMesFilter.value
            };
            const currentFiltersStr = JSON.stringify(filters);
            if (currentFiltersStr === lastComparisonFiltersStr) return;
            lastComparisonFiltersStr = currentFiltersStr;
            
            clearTimeout(comparisonFilterDebounceTimer);
            comparisonFilterDebounceTimer = setTimeout(() => {
                loadComparisonView();
            }, 500);
        };

        if (comparisonAnoFilter) comparisonAnoFilter.addEventListener('change', handleComparisonFilterChange);
        if (comparisonMesFilter) comparisonMesFilter.addEventListener('change', handleComparisonFilterChange);


        if (comparisonPastaFilter) comparisonPastaFilter.addEventListener('change', handleComparisonFilterChange);


        if (comparisonTendencyToggle) {
            comparisonTendencyToggle.addEventListener('click', () => {
                useTendencyComparison = !useTendencyComparison;
                comparisonTendencyToggle.textContent = useTendencyComparison ? 'Ver Dados Reais' : 'Calcular Tendência';
                comparisonTendencyToggle.classList.toggle('bg-orange-600');
                comparisonTendencyToggle.classList.toggle('hover:bg-orange-500');
                comparisonTendencyToggle.classList.toggle('bg-purple-600');
                comparisonTendencyToggle.classList.toggle('hover:bg-purple-500');
                loadComparisonView(); // Re-render
            });
        }

        if (toggleWeeklyBtn) {
            toggleWeeklyBtn.addEventListener('click', () => {
                comparisonChartType = 'weekly';
                toggleWeeklyBtn.classList.add('active');
                toggleMonthlyBtn.classList.remove('active');
                document.getElementById('comparison-monthly-metric-container').classList.add('hidden');
                loadComparisonView(); // Re-render charts
            });
        }

        if (toggleMonthlyBtn) {
            toggleMonthlyBtn.addEventListener('click', () => {
                comparisonChartType = 'monthly';
                toggleMonthlyBtn.classList.add('active');
                toggleWeeklyBtn.classList.remove('active');
                loadComparisonView(); // Re-render charts
            });
        }

        if (toggleMonthlyFatBtn && toggleMonthlyClientsBtn) {
            toggleMonthlyFatBtn.addEventListener('click', () => {
                comparisonMonthlyMetric = 'faturamento';
                toggleMonthlyFatBtn.classList.add('active');
                toggleMonthlyClientsBtn.classList.remove('active');
                loadComparisonView();
            });

            toggleMonthlyClientsBtn.addEventListener('click', () => {
                comparisonMonthlyMetric = 'clientes';
                toggleMonthlyClientsBtn.classList.add('active');
                toggleMonthlyFatBtn.classList.remove('active');
                loadComparisonView();
            });
        }

        if (clearComparisonFiltersBtn) {
            clearComparisonFiltersBtn.addEventListener('click', async () => {
                await fetchLastSalesDate();
                if (lastSalesDate) {
                    const lastDate = new Date(lastSalesDate + 'T12:00:00');
                    comparisonAnoFilter.value = String(lastDate.getFullYear());
                    comparisonAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
                    comparisonMesFilter.value = String(lastDate.getMonth());
                    comparisonMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
                } else {
                    const now = new Date();
                    comparisonAnoFilter.value = String(now.getFullYear());
                    comparisonAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
                    comparisonMesFilter.value = String(now.getMonth());
                    comparisonMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
                }

                selectedComparisonSupervisors = [];
                selectedComparisonSellers = [];
                selectedComparisonSuppliers = [];
                selectedComparisonProducts = [];
                selectedComparisonTiposVenda = [];
                selectedComparisonRedes = [];
                selectedComparisonCategorias = [];
                selectedComparisonCities = [];
                selectedComparisonFiliais = [];
                if (comparisonPastaFilter) comparisonPastaFilter.value = 'ambas';

                initComparisonFilters().then(loadComparisonView);
            });
        }

        document.addEventListener('click', (e) => {
            const dropdowns = [comparisonFilialFilterDropdown, comparisonSupervisorFilterDropdown, comparisonVendedorFilterDropdown, comparisonSupplierFilterDropdown, comparisonProductFilterDropdown, comparisonTipoVendaFilterDropdown, comparisonRedeFilterDropdown, comparisonCityFilterDropdown, comparisonCategoriaFilterDropdown];
            const btns = [comparisonFilialFilterBtn, comparisonSupervisorFilterBtn, comparisonVendedorFilterBtn, comparisonSupplierFilterBtn, comparisonProductFilterBtn, comparisonTipoVendaFilterBtn, comparisonRedeFilterBtn, comparisonCityFilterBtn, comparisonCategoriaFilterBtn];
            let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);

            if (anyClosed) {
                handleComparisonFilterChange();
            }
        });

        async function initComparisonFilters() {
            const filters = {
                p_ano: null,
                p_mes: null,
                p_filial: [],
                p_cidade: [],
                p_supervisor: [],
                p_vendedor: [],
                p_fornecedor: [],
                p_tipovenda: [],
                p_rede: [],
                p_categoria: []
            };
            const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
            if (error) AppLog.error('Error fetching comparison filters:', error);
            if (!filterData) return;

            if (filterData.anos && comparisonAnoFilter) {
                const currentVal = comparisonAnoFilter.value;
                // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
                comparisonAnoFilter.innerHTML = filterData.anos.map(a => `<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
                await fetchLastSalesDate();
                if (currentVal && currentVal !== 'todos' && currentVal !== '') {
                    comparisonAnoFilter.value = currentVal;
                } else if (lastSalesDate) {
                    const lastDate = new Date(lastSalesDate + 'T12:00:00');
                    comparisonAnoFilter.value = String(lastDate.getFullYear());
                    comparisonAnoFilter.dispatchEvent(new Event('change', { bubbles: true }));
                } else if (filterData.anos.length > 0) {
                    comparisonAnoFilter.value = filterData.anos[0];
                }
                enhanceSelectToCustomDropdown(comparisonAnoFilter);
            }

            if (comparisonMesFilter && comparisonMesFilter.options.length <= 1) {
                // Get the current value BEFORE we wipe the options
                const currentMesVal = comparisonMesFilter.value;

                const meses = MONTHS_PT;
                // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
                comparisonMesFilter.innerHTML = meses.map((m, i) => `<option value="${i}">${m}</option>`).join('');

                // If there's an active valid selected month (not empty), keep it
                // Otherwise, default to the last sales date month
                if (currentMesVal && currentMesVal !== '') {
                    comparisonMesFilter.value = currentMesVal;
                } else {
                    if (lastSalesDate) {
                        const lastDate = new Date(lastSalesDate + 'T12:00:00');
                        comparisonMesFilter.value = String(lastDate.getMonth());
                    } else {
                        const now = new Date();
                        comparisonMesFilter.value = String(now.getMonth());
                    }
                    comparisonMesFilter.dispatchEvent(new Event('change', { bubbles: true }));
                }
                enhanceSelectToCustomDropdown(comparisonMesFilter);
            }

                        if (comparisonPastaFilter) enhanceSelectToCustomDropdown(comparisonPastaFilter);

            try {
        // Helper
                const getList = (id) => document.getElementById(id);
                
                // Filiais
                setupCityMultiSelect(comparisonFilialFilterBtn, comparisonFilialFilterDropdown, comparisonFilialFilterDropdown, filterData.filiais, selectedComparisonFiliais);

                // Supervisors
                const supList = getList('comparison-supervisor-filter-list') || comparisonSupervisorFilterDropdown;
                setupCityMultiSelect(comparisonSupervisorFilterBtn, comparisonSupervisorFilterDropdown, supList, filterData.supervisors, selectedComparisonSupervisors);
                
                // Vendedores
                const vendList = getList('comparison-vendedor-filter-list') || comparisonVendedorFilterDropdown;
                setupCityMultiSelect(comparisonVendedorFilterBtn, comparisonVendedorFilterDropdown, vendList, filterData.vendedores, selectedComparisonSellers);
                
                // Suppliers
                const suppList = getList('comparison-supplier-filter-list') || comparisonSupplierFilterDropdown;
                setupCityMultiSelect(comparisonSupplierFilterBtn, comparisonSupplierFilterDropdown, suppList, filterData.fornecedores, selectedComparisonSuppliers, null, true);
                
                // Tipos Venda
                const tipoList = getList('comparison-tipo-venda-filter-list') || comparisonTipoVendaFilterDropdown;
                setupCityMultiSelect(comparisonTipoVendaFilterBtn, comparisonTipoVendaFilterDropdown, tipoList, filterData.tipos_venda, selectedComparisonTiposVenda);

                // Products (Using same structure as boxes if available, assuming filterData.produtos is present or empty)
                const prodList = getList('comparison-product-list') || comparisonProductFilterDropdown;
                const prodSearch = document.getElementById('comparison-product-search-input');
                setupCityMultiSelect(comparisonProductFilterBtn, comparisonProductFilterDropdown, prodList, filterData.produtos || [], selectedComparisonProducts, prodSearch, true);

                // Cities (Multi Select)
                setupCityMultiSelect(comparisonCityFilterBtn, comparisonCityFilterDropdown, comparisonCityFilterList, filterData.cidades || [], selectedComparisonCities, comparisonCityFilterSearch);

                // Categories
                const catList = getList('comparison-categoria-filter-list') || comparisonCategoriaFilterDropdown;
                const catSearch = document.getElementById('comparison-categoria-filter-search');
                setupCityMultiSelect(comparisonCategoriaFilterBtn, comparisonCategoriaFilterDropdown, catList, filterData.categorias || [], selectedComparisonCategorias, catSearch);

                // Redes
                const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
                const redeList = getList('comparison-rede-filter-list') || comparisonRedeFilterDropdown;
                setupCityMultiSelect(comparisonRedeFilterBtn, comparisonRedeFilterDropdown, redeList, redes, selectedComparisonRedes, document.getElementById('comparison-rede-filter-search'));
            } catch (e) {
                AppLog.error('Error setting up comparison filters:', e);
            }
        }

        async function loadComparisonView() {
            window.showDashboardLoading('comparison-view');

            if (typeof initComparisonFilters === 'function' && (!comparisonSupervisorFilterDropdown.children.length || comparisonSupervisorFilterDropdown.children.length === 0)) {
                await initComparisonFilters();
            }

            let pFornecedorValue = selectedComparisonSuppliers.length > 0 ? selectedComparisonSuppliers : null;
            if (comparisonPastaFilter && comparisonPastaFilter.value !== 'ambas') {
                const pastaSuppliers = comparisonPastaFilter.value === 'ELMA' ? ['707', '708', '752'] : ['1119'];
                if (!pFornecedorValue) {
                    pFornecedorValue = [...pastaSuppliers];
                } else {
                    const combined = new Set([...pFornecedorValue, ...pastaSuppliers]);
                    pFornecedorValue = Array.from(combined);
                }
            }

            const filters = {
                p_filial: selectedComparisonFiliais.length > 0 ? selectedComparisonFiliais : null,
                p_cidade: selectedComparisonCities.length > 0 ? selectedComparisonCities : null,
                p_supervisor: selectedComparisonSupervisors.length > 0 ? selectedComparisonSupervisors : null,
                p_vendedor: selectedComparisonSellers.length > 0 ? selectedComparisonSellers : null,
                p_fornecedor: pFornecedorValue,
                p_produto: selectedComparisonProducts.length > 0 ? selectedComparisonProducts : null,
                p_tipovenda: selectedComparisonTiposVenda.length > 0 ? selectedComparisonTiposVenda : null,
                p_rede: selectedComparisonRedes.length > 0 ? selectedComparisonRedes : null,
                p_categoria: selectedComparisonCategorias.length > 0 ? selectedComparisonCategorias : null,
                p_ano: comparisonAnoFilter.value,
                p_mes: comparisonMesFilter.value
            };


            const cacheKey = generateCacheKey('comparison_view_data', filters);
            let data = null;

            try {
                const cachedEntry = await getFromCache(cacheKey);
                if (cachedEntry && cachedEntry.data) {
                    AppLog.log('Serving Comparison View from Cache');
                    data = cachedEntry.data;
                }
            } catch (e) { AppLog.warn('Cache error:', e); }

            if (!data) {
                const { data: rpcData, error } = await supabase.rpc('get_comparison_view_data', filters);

                if (error) {
                    AppLog.error("RPC Error:", error);
                    window.hideDashboardLoading();
                    if (error.message.includes('function get_comparison_view_data') && error.message.includes('does not exist')) {
                        window.showToast('error', "A função 'get_comparison_view_data' não foi encontrada no banco de dados. \n\nPor favor, execute o script 'sql/comparison_view_rpc.sql' no Supabase SQL Editor para corrigir isso.");
                    }
                    return;
                }
                data = rpcData;
                saveToCache(cacheKey, data);
            }

            // Map RPC Data to UI format
            const metrics = mapRpcDataToMetrics(data);

            // Render KPIs
            renderKpiCards(metrics.kpis);

            // Render Charts
            renderComparisonCharts(metrics.charts);

            // Render Table
            renderSupervisorTable(metrics.supervisorData);

            window.hideDashboardLoading();
        }

        function mapRpcDataToMetrics(data) {
            if (!data) return { kpis: [], charts: {}, supervisorData: {} };

            // Trend Factor
            const trendFactor = (useTendencyComparison && data.trend_info && data.trend_info.allowed) ? data.trend_info.factor : 1;

            // Apply Trend to Current Base Values
            const curF = data.current_kpi.f * trendFactor;
            const curP = data.current_kpi.p * trendFactor;
            const curC = Math.round(data.current_kpi.c * trendFactor);

            // 1. Process KPIs
            const kpis = [
                { title: 'Faturamento Total', current: curF, history: data.history_kpi.f / 3, format: 'currency' },
                { title: 'Peso Total (Ton)', current: curP/1000, history: (data.history_kpi.p/3)/1000, format: 'decimal' },
                { title: 'Clientes Atendidos', current: curC, history: data.history_kpi.c / 3, format: 'integer' },
                { title: 'Ticket Médio', 
                  current: curC > 0 ? curF / curC : 0, 
                  history: data.history_kpi.c > 0 ? (data.history_kpi.f/3) / (data.history_kpi.c/3) : 0, 
                  format: 'currency' 
                },
                { title: 'Mix por PDV (Pepsico)', current: Number(data.current_kpi.mix_pepsico.toFixed(2)), history: Number((data.history_kpi.sum_mix_pepsico / 3).toFixed(2)), format: 'decimal_2' },
                { title: 'Mix Salty', current: Math.round(data.current_kpi.pos_salty * trendFactor), history: Math.round(data.history_kpi.sum_pos_salty / 3), format: 'integer' },
                { title: 'Mix Foods', current: Math.round(data.current_kpi.pos_foods * trendFactor), history: Math.round(data.history_kpi.sum_pos_foods / 3), format: 'integer' }
            ];

            // 2. Weekly Chart Logic
            const currentDaily = data.current_daily || [];
            const historyDaily = data.history_daily || [];
            
            const getWeekIdx = (dateStr) => {
                const d = new Date(dateStr);
                const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
                const offset = firstDay.getDay(); 
                const dayOfMonth = d.getDate();
                return Math.floor((dayOfMonth + offset - 1) / 7);
            };

            const weeklyCurrent = new Array(6).fill(0);
            const weeklyHistory = new Array(6).fill(0);

            // 4. Daily Chart Init (moved up for shared logic)
            const dailyDataByWeek = new Array(6).fill(0).map(() => new Array(7).fill(0)); // 6 weeks, 7 days

            // --- Trend Logic Implementation ---
            // 1. Calculate Actuals & Find Last Sales Date
            let maxDateStr = '0000-00-00';
            let currentActualTotal = 0;

            currentDaily.forEach(item => {
                if (item.d > maxDateStr) maxDateStr = item.d;
                currentActualTotal += item.f;
                
                const idx = getWeekIdx(item.d + 'T12:00:00');
                if (idx >= 0 && idx < 6) {
                    weeklyCurrent[idx] += item.f;
                    
                    // Fill Daily Actuals
                    const d = new Date(item.d + 'T12:00:00');
                    const dayIdx = d.getDay();
                    dailyDataByWeek[idx][dayIdx] += item.f;
                }
            });

            // 2. Apply Trend Projection (if enabled and applicable)
            if (useTendencyComparison && data.trend_info && data.trend_info.allowed && maxDateStr !== '0000-00-00') {
                const lastSalesDate = new Date(maxDateStr + 'T12:00:00');
                const year = lastSalesDate.getFullYear();
                const month = lastSalesDate.getMonth();
                const monthStart = new Date(year, month, 1);
                const monthEnd = new Date(year, month + 1, 0);

                const isWorkingDay = (d) => {
                    const day = d.getDay();
                    const dateStr = d.toISOString().split('T')[0];
                    // Access global holidays if available
                    const hols = (typeof holidays !== 'undefined') ? holidays : []; 
                    return day !== 0 && day !== 6 && !hols.includes(dateStr);
                };

                // A. Process History to build Weights Matrix [Week][Day]
                const historySums = new Array(6).fill(0).map(() => new Array(7).fill(0));
                const historyCounts = new Array(6).fill(0).map(() => new Array(7).fill(0));

                historyDaily.forEach(item => {
                    const idx = getWeekIdx(item.d + 'T12:00:00');
                    if (idx >= 0 && idx < 6) {
                        const d = new Date(item.d + 'T12:00:00');
                        const dayIdx = d.getDay();
                        historySums[idx][dayIdx] += item.f;
                        historyCounts[idx][dayIdx]++;
                    }
                });

                const historyWeights = historySums.map((week, wIdx) => 
                    week.map((sum, dIdx) => {
                        const count = historyCounts[wIdx][dIdx];
                        return count > 0 ? sum / count : 0;
                    })
                );

                // B. Calculate Run Rate and Total Projected Pot
                let passedWorkingDays = 0;
                let curr = new Date(monthStart);
                while (curr <= lastSalesDate) {
                    if (isWorkingDay(curr)) passedWorkingDays++;
                    curr.setDate(curr.getDate() + 1);
                }

                const dailyRunRate = passedWorkingDays > 0 ? currentActualTotal / passedWorkingDays : 0;
                
                // Identify Future Working Days
                const futureDays = []; 
                let iter = new Date(lastSalesDate);
                iter.setDate(iter.getDate() + 1); // Start from next day

                while (iter <= monthEnd) {
                    if (isWorkingDay(iter)) {
                        const idx = getWeekIdx(iter.toISOString());
                        const dayIdx = iter.getDay();
                        if (idx >= 0 && idx < 6) {
                            futureDays.push({ weekIdx: idx, dayIdx: dayIdx });
                        }
                    }
                    iter.setDate(iter.getDate() + 1);
                }

                const totalProjectedPot = dailyRunRate * futureDays.length;

                // C. Distribute Pot
                let totalWeightDenominator = 0;
                futureDays.forEach(day => {
                    totalWeightDenominator += historyWeights[day.weekIdx][day.dayIdx];
                });

                futureDays.forEach(day => {
                    let allocation = 0;
                    if (totalWeightDenominator > 0) {
                        const weight = historyWeights[day.weekIdx][day.dayIdx];
                        allocation = totalProjectedPot * (weight / totalWeightDenominator);
                    } else {
                        // Fallback to equal distribution if no history for these specific slots
                        allocation = dailyRunRate; 
                    }
                    
                    weeklyCurrent[day.weekIdx] += allocation;
                    dailyDataByWeek[day.weekIdx][day.dayIdx] += allocation;
                });
            }

            historyDaily.forEach(item => {
                const idx = getWeekIdx(item.d + 'T12:00:00'); // Safe Timezone
                if (idx >= 0 && idx < 6) weeklyHistory[idx] += item.f;
            });

            // Normalize History (Quarter Sum -> Average Month)
            for(let i=0; i<6; i++) weeklyHistory[i] = weeklyHistory[i] / 3;

            // Trim empty tail weeks dynamically
            let lastActiveIndex = -1;
            for (let i = 5; i >= 0; i--) {
                if (weeklyCurrent[i] > 0 || weeklyHistory[i] > 0) {
                    lastActiveIndex = i;
                    break;
                }
            }
            const numWeeksToKeep = Math.max(4, lastActiveIndex + 1);

            const trimmedWeeklyCurrent = weeklyCurrent.slice(0, numWeeksToKeep);
            const trimmedWeeklyHistory = weeklyHistory.slice(0, numWeeksToKeep);
            const trimmedDailyDataByWeek = dailyDataByWeek.slice(0, numWeeksToKeep);

            const weeklyLabels = Array.from({ length: numWeeksToKeep }, (_, i) => `Semana ${i + 1}`);

            // 3. Monthly Chart (History Months + Current)
            const monthlyData = (data.history_monthly || []).map(m => ({
                label: m.m, // YYYY-MM
                fat: m.f,
                clients: m.c
            }));
            
            monthlyData.push({ label: 'Atual', fat: curF, clients: curC });

            // 4. Daily Chart Datasets
            const dayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
            const dailyColors = [
                '#94a3b8', // Domingo (Slate)
                '#60a5fa', // Segunda (Blue)
                '#379fae', // Terca (Powder Blue - new palette)
                '#eaf7f8', // Quarta (Light Blue - new palette)
                '#ffaa4d', // Quinta (Orange - alternative)
                '#316a9a', // Sexta (Dark Blue - new palette)
                '#a78bfa'  // Sabado (Purple)
            ];

            const datasetsDaily = dayNames.map((name, i) => ({
                label: name,
                data: trimmedDailyDataByWeek.map(weekData => weekData[i]),
                backgroundColor: dailyColors[i],
                borderColor: dailyColors[i]
            }));

            // 5. Supervisor Table
            const supervisorData = {};
            (data.supervisor_data || []).forEach(s => {
                supervisorData[s.name] = { current: s.current * trendFactor, history: s.history / 3 };
            });

            return {
                kpis,
                charts: {
                    weeklyCurrent: trimmedWeeklyCurrent,
                    weeklyHistory: trimmedWeeklyHistory,
                    monthlyData,
                    dailyData: {
                        labels: weeklyLabels,
                        datasets: datasetsDaily
                    }
                },
                supervisorData
            };
        }

        function getMonthWeeksDistribution(date) {
            const year = date.getFullYear(); // Local time for simplicity
            const month = date.getMonth();

            const startOfMonth = new Date(year, month, 1);
            const endOfMonth = new Date(year, month + 1, 0);

            const weeks = [];
            let currentStart = new Date(startOfMonth);

            while (currentStart <= endOfMonth) {
                // Find end of week (Saturday or end of month)
                const dayOfWeek = currentStart.getDay(); // 0 (Sun) -> 6 (Sat)
                const daysToSaturday = 6 - dayOfWeek;

                let currentEnd = new Date(currentStart);
                currentEnd.setDate(currentStart.getDate() + daysToSaturday);

                if (currentEnd > endOfMonth) currentEnd = new Date(endOfMonth);

                // Count working days (Mon-Fri)
                let workingDays = 0;
                const temp = new Date(currentStart);
                while(temp <= currentEnd) {
                    const d = temp.getDay();
                    if (d >= 1 && d <= 5) workingDays++;
                    temp.setDate(temp.getDate() + 1);
                }

                weeks.push({ start: new Date(currentStart), end: new Date(currentEnd), workingDays });

                // Next week starts Sunday (or day after currentEnd)
                currentStart = new Date(currentEnd);
                currentStart.setDate(currentStart.getDate() + 1);
            }

            return { weeks };
        }

        function calculateUnifiedMetrics(currentSales, historySales) {
            // Determine Reference Date (Target Month)
            // Re-using logic from fetchComparisonData or inferring from currentSales
            // Ideally we pass refDate, but we can infer from currentSales[0] or default
            let refDate;
            if (currentSales && currentSales.length > 0 && currentSales[0].dtped) {
                refDate = new Date(currentSales[0].dtped);
            } else {
                // Fallback: If no current sales, use filter logic or lastSalesDate
                const selectedYear = comparisonAnoFilter.value;
                const selectedMonth = comparisonMesFilter.value;
                const defaultRefDate = lastSalesDate ? new Date(lastSalesDate) : new Date();

                if (selectedYear && selectedYear !== 'todos' && selectedYear !== '') {
                    const year = parseInt(selectedYear);
                    if (selectedMonth && selectedMonth !== '') {
                        refDate = new Date(Date.UTC(year, parseInt(selectedMonth), 15));
                    } else {
                        const currentYear = defaultRefDate.getFullYear();
                        if (year === currentYear) refDate = defaultRefDate;
                        else refDate = new Date(Date.UTC(year, 11, 15));
                    }
                } else {
                    refDate = defaultRefDate;
                }
            }

            const currentYear = refDate.getFullYear();
            const currentMonth = refDate.getMonth(); // 0-11 local or UTC depending on how we handle

            // Generate weeks structure for current (target) month
            // Ensure refDate is handled correctly as UTC or Local.
            // The getMonthWeeksDistribution uses local Date methods (getFullYear, getMonth).
            // We should ensure consistency.
            const { weeks } = getMonthWeeksDistribution(refDate);
            const currentMonthWeeks = weeks;

            const metrics = {
                current: { fat: 0, peso: 0, clients: 0, mixPepsico: 0, positivacaoSalty: 0, positivacaoFoods: 0 },
                history: { fat: 0, peso: 0, avgFat: 0, avgPeso: 0, avgClients: 0, avgMixPepsico: 0, avgPositivacaoSalty: 0, avgPositivacaoFoods: 0 },
                charts: {
                    weeklyCurrent: new Array(currentMonthWeeks.length).fill(0),
                    weeklyHistory: new Array(currentMonthWeeks.length).fill(0),
                    monthlyData: [], // { label, fat, clients }
                    dailyData: { datasets: [], labels: [] }
                },
                supervisorData: {} // { sup: { current, history } }
            };

            // Helper to get week index
            const getWeekIndex = (date) => {
                const d = typeof date === 'number' ? new Date(date) : new Date(date);
                if (!d || isNaN(d.getTime())) return -1;
                for(let i=0; i<currentMonthWeeks.length; i++) {
                    if (d >= currentMonthWeeks[i].start && d <= currentMonthWeeks[i].end) return i;
                }
                return -1;
            };

            // 1. Process Current Sales
            const currentClientsSet = new Set();

            currentSales.forEach(s => {
                const val = Number(s.vlvenda) || 0;
                const peso = Number(s.totpesoliq) || 0;

                metrics.current.fat += val;
                metrics.current.peso += peso;

                if (s.codcli) currentClientsSet.add(s.codcli);

                // Supervisor
                if (s.superv) {
                    if (!metrics.supervisorData[s.superv]) metrics.supervisorData[s.superv] = { current: 0, history: 0 };
                    metrics.supervisorData[s.superv].current += val;
                }

                // Weekly Chart
                const d = s.dtped ? new Date(s.dtped) : null;
                if (d) {
                    const wIdx = getWeekIndex(d);
                    if (wIdx !== -1) metrics.charts.weeklyCurrent[wIdx] += val;
                }
            });
            metrics.current.clients = currentClientsSet.size;

            // 2. Process History Sales
            const historyMonths = new Map(); // monthKey -> { fat, clients: Set }

            historySales.forEach(s => {
                const val = Number(s.vlvenda) || 0;
                const d = s.dtped ? new Date(s.dtped) : null;

                metrics.history.fat += val;
                metrics.history.peso += (Number(s.totpesoliq) || 0);

                // Supervisor
                if (s.superv) {
                    if (!metrics.supervisorData[s.superv]) metrics.supervisorData[s.superv] = { current: 0, history: 0 };
                    metrics.supervisorData[s.superv].history += val;
                }

                if (d) {
                    // Weekly History (Approximate mapping: map day of month to week index)
                    // If we want rigorous average per week number, we should map based on day 1-7, 8-14, etc?
                    // Or match week index of the historical month?
                    // Let's use getWeekIndex concept applied to the historical date's day-of-month projected to current month structure?
                    // Simple approach: Map by day of month to current week ranges
                    // This aligns "Start of month" behavior.

                    // Project date to current month/year for bucket finding
                    const projectedDate = new Date(Date.UTC(currentYear, currentMonth, d.getUTCDate()));
                    const wIdx = getWeekIndex(projectedDate);
                    if (wIdx !== -1) metrics.charts.weeklyHistory[wIdx] += val;

                    // Monthly Data Aggregation
                    const monthKey = `${d.getUTCFullYear()}-${d.getUTCMonth()}`;
                    if (!historyMonths.has(monthKey)) historyMonths.set(monthKey, { fat: 0, clients: new Set() });
                    const mData = historyMonths.get(monthKey);
                    mData.fat += val;
                    if(s.codcli) mData.clients.add(s.codcli);
                }
            });

            // 3. Averages
            const historyMonthCount = historyMonths.size || 1;
            metrics.history.avgFat = metrics.history.fat / historyMonthCount;
            metrics.history.avgPeso = metrics.history.peso / historyMonthCount;

            let totalHistoryClients = 0;
            historyMonths.forEach(m => totalHistoryClients += m.clients.size);
            metrics.history.avgClients = totalHistoryClients / historyMonthCount;

            // Normalize Weekly History
            metrics.charts.weeklyHistory = metrics.charts.weeklyHistory.map(v => v / historyMonthCount);
            // Normalize Supervisor History
            Object.values(metrics.supervisorData).forEach(d => d.history /= historyMonthCount);

            // Prepare Monthly Chart Data (History Months + Current Month)
            // Sort history months
            const sortedMonths = Array.from(historyMonths.keys()).sort();
            sortedMonths.forEach(key => {
                const [y, m] = key.split('-');
                const label = new Date(Date.UTC(y, m, 1)).toLocaleDateString('pt-BR', { month: 'short' });
                const mData = historyMonths.get(key);
                metrics.charts.monthlyData.push({ label, fat: mData.fat, clients: mData.clients.size });
            });
            // Add Current
            metrics.charts.monthlyData.push({
                label: 'Atual',
                fat: metrics.current.fat,
                clients: metrics.current.clients
            });

            // Prepare Daily Chart (Current Month Day-by-Day or Week-Day breakdown?)
            // External app shows "Faturamento por Dia da Semana" (Daily Breakdown by Week)
            // It maps Mon-Sun for each week.
            const dayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
            const dailyDataByWeek = currentMonthWeeks.map(() => new Array(7).fill(0));

            currentSales.forEach(s => {
                const d = s.dtped ? new Date(s.dtped) : null;
                if(d) {
                    const wIdx = getWeekIndex(d);
                    if(wIdx !== -1) {
                        dailyDataByWeek[wIdx][d.getUTCDay()] += (Number(s.vlvenda) || 0);
                    }
                }
            });

            const dailyColors = [
                '#94a3b8', // Domingo (Slate)
                '#60a5fa', // Segunda (Blue)
                '#379fae', // Terca (Powder Blue - new palette)
                '#eaf7f8', // Quarta (Light Blue - new palette)
                '#ffaa4d', // Quinta (Orange - alternative)
                '#316a9a', // Sexta (Dark Blue - new palette)
                '#a78bfa'  // Sabado (Purple)
            ];

            const datasetsDaily = dayNames.map((name, i) => ({
                label: name,
                data: dailyDataByWeek.map(weekData => weekData[i]),
                backgroundColor: dailyColors[i],
                borderColor: dailyColors[i]
            }));

            metrics.charts.dailyData = {
                labels: currentMonthWeeks.map((_, i) => `Semana ${i+1}`),
                datasets: datasetsDaily
            };

            const kpis = [
                { title: 'Faturamento Total', current: metrics.current.fat, history: metrics.history.avgFat, format: 'currency' },
                { title: 'Peso Total (Ton)', current: metrics.current.peso/1000, history: metrics.history.avgPeso/1000, format: 'decimal' },
                { title: 'Clientes Atendidos', current: metrics.current.clients, history: metrics.history.avgClients, format: 'integer' },
                // Placeholder for Mix (requires product details logic not fully implemented in simplified version)
                { title: 'Ticket Médio', current: metrics.current.clients ? metrics.current.fat/metrics.current.clients : 0, history: metrics.history.avgClients ? metrics.history.avgFat/metrics.history.avgClients : 0, format: 'currency' }
            ];

            return { kpis, charts: metrics.charts, supervisorData: metrics.supervisorData };
        }

        function renderKpiCards(kpis) {
            const container = document.getElementById('comparison-kpi-container');
            if (!container) return;

            const fmt = (val, format) => {
                if (format === 'currency') return formatCurrency(val);
                if (format === 'decimal') return formatNumber(val, 3);
                if (format === 'decimal_2') return formatNumber(val, 2);
                return formatInteger(val);
            };

            container.innerHTML = '';
            const frag = document.createDocumentFragment();
            kpis.forEach(kpi => {
                const variation = kpi.history > 0 ? ((kpi.current - kpi.history) / kpi.history) * 100 : 0;
                const colorClass = variation > 0 ? 'text-green-400' : 'text-red-400';

                // Determine glow color
                let glowClass = 'kpi-glow-blue';
                if (kpi.title.includes('Faturamento')) glowClass = 'kpi-glow-green';
                else if (kpi.title.includes('Peso')) glowClass = 'kpi-glow-blue';
                else if (kpi.title.includes('Clientes')) glowClass = 'kpi-glow-purple';

                const div = document.createElement('div');
                div.className = `kpi-card p-4 rounded-lg text-center kpi-glow-base ${glowClass}`;

                const pTitle = document.createElement('p');
                pTitle.className = 'text-slate-300 text-sm';
                pTitle.textContent = kpi.title;
                div.appendChild(pTitle);

                const pCurrent = document.createElement('p');
                pCurrent.className = 'text-2xl font-bold text-white my-2';
                pCurrent.textContent = fmt(kpi.current, kpi.format);
                div.appendChild(pCurrent);

                const pVar = document.createElement('p');
                pVar.className = `text-sm ${colorClass}`;
                pVar.textContent = `${variation > 0 ? '+' : ''}${variation.toFixed(1)}% vs Média`;
                div.appendChild(pVar);

                const pAvg = document.createElement('p');
                pAvg.className = 'text-xs text-slate-500';
                pAvg.textContent = `Média: ${fmt(kpi.history, kpi.format)}`;
                div.appendChild(pAvg);

                frag.appendChild(div);
            });
            container.appendChild(frag);
        }

        function renderComparisonCharts(chartsData) {
            // Weekly Chart
            if (comparisonChartType === 'weekly') {
                document.getElementById('monthlyComparisonChartContainer').classList.add('hidden');
                document.getElementById('weeklyComparisonChartContainer').classList.remove('hidden');

                createChart('weeklyComparisonChart', 'line',
                    chartsData.weeklyCurrent.map((_, i) => `Semana ${i+1}`),
                    [
                        { label: 'Mês Atual', data: chartsData.weeklyCurrent, borderColor: '#379fae', backgroundColor: '#379fae', tension: 0.4, isCurrent: true },
                        { label: 'Média Histórica', data: chartsData.weeklyHistory, borderColor: '#eaf7f8', backgroundColor: '#eaf7f8', tension: 0.4, isPrevious: true }
                    ]
                );
            } else {
                // Monthly Chart
                document.getElementById('weeklyComparisonChartContainer').classList.add('hidden');
                document.getElementById('monthlyComparisonChartContainer').classList.remove('hidden');

                const labels = chartsData.monthlyData.map(d => d.label);
                const isFat = comparisonMonthlyMetric === 'faturamento';
                const values = chartsData.monthlyData.map(d => isFat ? d.fat : d.clients);

                createChart('monthlyComparisonChart', 'bar', labels, [{
                    label: isFat ? 'Faturamento' : 'Clientes',
                    data: values,
                    backgroundColor: '#379fae'
                }]);
            }

            // Daily Chart
            if (chartsData.dailyData && chartsData.dailyData.datasets.length > 0) {
                createChart('dailyWeeklyComparisonChart', 'bar',
                    chartsData.dailyData.labels,
                    chartsData.dailyData.datasets
                );
            } else {
                showNoDataMessage('dailyWeeklyComparisonChart', 'Sem dados diários disponíveis');
            }
        }

        // Refactored to use declarative template literals and innerHTML instead of verbose document.createElement logic.
        // This improves readability, maintainability, and significantly reduces code size while preserving XSS safety via escapeHtml.
        function renderSupervisorTable(data) {
            const tbody = document.getElementById('supervisorComparisonTableBody');
            if (!tbody) return;

            tbody.innerHTML = Object.entries(data).map(([sup, vals]) => {
                const variation = vals.history > 0 ? ((vals.current - vals.history) / vals.history) * 100 : 0;
                const colorClass = variation > 0 ? 'text-green-400' : 'text-red-400';
                return `
                    <tr class="hover:bg-slate-700">
                        <td class="px-4 py-2">${escapeHtml(sup)}</td>
                        <td class="px-4 py-2 text-right">${escapeHtml(formatCurrency(vals.history))}</td>
                        <td class="px-4 py-2 text-right">${escapeHtml(formatCurrency(vals.current))}</td>
                        <td class="px-4 py-2 text-right ${colorClass}">${escapeHtml(variation.toFixed(2))}%</td>
                    </tr>
                `;
            }).join('');
        }
// --- INOVACOES VIEW LOGIC ---
let innovationsChart = null;
let currentInnovationsFilters = {};

async function updateInnovationsMonthView() {
    window.showDashboardLoading('innovations-month-view');

    const anoSelect = document.getElementById('innovations-ano-filter');
    const mesSelect = document.getElementById('innovations-mes-filter');

    const mappedRedes = innovationsSelectedRedes.map(r => {
        if (r === 'C/ REDE') return 'com_ramo';
        if (r === 'S/ REDE') return 'sem_ramo';
        return r;
    });

    const filters = {
        p_ano: anoSelect ? (anoSelect.value === 'todos' ? null : anoSelect.value) : null,
        p_mes: mesSelect ? (mesSelect.value === '' ? null : mesSelect.value) : null,
        p_cidade: innovationsSelectedCidades,
        p_filial: innovationsSelectedFiliais,
        p_supervisor: innovationsSelectedSupervisors,
        p_vendedor: innovationsSelectedVendedores,
        p_rede: mappedRedes,
        p_tipovenda: innovationsSelectedTiposVenda,
        p_categoria_inovacao: innovationsSelectedCategorias
    };

    // Replace empty arrays with null to avoid PostgREST overloading resolution issues
    const rpcFilters = {
        p_ano: filters.p_ano || null,
        p_mes: filters.p_mes || null,
        p_filial: filters.p_filial.length ? filters.p_filial : null,
        p_cidade: filters.p_cidade.length ? filters.p_cidade : null,
        p_supervisor: filters.p_supervisor.length ? filters.p_supervisor : null,
        p_vendedor: filters.p_vendedor.length ? filters.p_vendedor : null,
        p_rede: filters.p_rede.length ? filters.p_rede : null,
        p_tipovenda: filters.p_tipovenda.length ? filters.p_tipovenda : null,
        p_categoria_inovacao: filters.p_categoria_inovacao && filters.p_categoria_inovacao.length ? filters.p_categoria_inovacao[0] : null // Categoria Inovacao was a text param
    };

    const cacheKey = generateCacheKey('innovations_view_data', rpcFilters);
    let data = null;

    try {
        const cachedEntry = await getFromCache(cacheKey);
        if (cachedEntry && cachedEntry.data) {
            AppLog.log('Serving Innovations View from Cache');
            data = cachedEntry.data;
        }
    } catch (e) { AppLog.warn('Cache error:', e); }

    if (!data) {
        try {
            const { data: rpcData, error } = await supabase.rpc('get_innovations_data', rpcFilters);

            if (error) {
                AppLog.error('Error fetching innovations:', error);
                window.hideDashboardLoading();
                return;
            }
            data = rpcData;
            saveToCache(cacheKey, data);
        } catch (err) {
            AppLog.error('Exception fetching innovations:', err);
            window.hideDashboardLoading();
            return;
        }
    }

    try {
        // Tira o peso da renderização síncrona, desdobrando o frontend.
        requestAnimationFrame(() => {
            renderInnovationsKPIs(data);
            renderInnovationsChart(data);

            // Renderiza a tabela depois que o gráfico e os números grandes acendem
            setTimeout(() => {
                try {
                    renderInnovationsTable(data);
                } catch(e) {
                    AppLog.error('Error in table:', e);
                } finally {
                    window.hideDashboardLoading();
                }
            }, 10);
        });
    } catch (err) {
        AppLog.error('Error rendering innovations:', err);
        window.hideDashboardLoading();
    }
}

function renderInnovationsKPIs(data) {
    if (!data) return;

    // We use data.kpi_clients_attended for new penetration math if available, fallback to active_clients
    const activeClients = data.active_clients || 0;

    // The base is kpi_clients_base (total clients in the database applying filters)
    const baseClients = data.kpi_clients_base || 0;

    // Total Clients (Base Total)
    const activeClientsEl = document.getElementById('innovations-month-active-clients-kpi');
    if (activeClientsEl) activeClientsEl.textContent = formatNumber(baseClients, 0);

    // Calculate Best Coverage & Avg Per Client
    let bestCategory = null;
    let maxCoverage = -1;
    let maxCoverageCount = 0;
    let bestAvgPerClient = 0;

    const categories = data.categories || [];
    let totalSelectionPos = 0;

    categories.forEach(cat => {
        let cov = activeClients > 0 ? (cat.pos_current / activeClients) * 100 : 0;
        if (cov > maxCoverage) {
            maxCoverage = cov;
            bestCategory = cat.name;
            maxCoverageCount = cat.pos_current;
            // distinct_clients_current comes from the new SQL aggregation
            let distClients = cat.distinct_clients_current || 1;
            let prodSum = cat.products_pos_sum_current || cat.pos_current;
            bestAvgPerClient = (prodSum / distClients);
            if(cat.pos_current === 0) bestAvgPerClient = 0;
        }
        totalSelectionPos += cat.pos_current;
    });

    const topCovTitle = document.getElementById('innovations-month-top-coverage-title');
    const topCovKpi = document.getElementById('innovations-month-top-coverage-kpi');
    const topCovCount = document.getElementById('innovations-month-top-coverage-count-kpi');
    const topCovValue = document.getElementById('innovations-month-top-coverage-value-kpi');
    const topCovLabel = document.getElementById('innovations-month-top-coverage-label');

    if (topCovTitle) topCovTitle.textContent = bestCategory || 'N/A';
    if (topCovLabel) topCovLabel.textContent = 'Melhor Categoria';
    
    // Changing the count label to the calculated average
    if (topCovKpi) topCovKpi.textContent = bestAvgPerClient > 0 ? bestAvgPerClient.toFixed(2) : '0.00';
    if (topCovCount) topCovCount.textContent = 'Média Produtos';
    
    if (topCovValue) topCovValue.textContent = '';

    // Selection Percent
    const selCovValue = document.getElementById('innovations-month-selection-coverage-value-kpi');
    let selPercent = 0;

    // Check if we have the new direct counts
    if (data.kpi_innovations_attended !== undefined && data.kpi_clients_attended !== undefined) {
        selPercent = data.kpi_clients_attended > 0 ? (data.kpi_innovations_attended / data.kpi_clients_attended) * 100 : 0;
    } else {
        // Fallback logic
        selPercent = activeClients > 0 ? (totalSelectionPos / (activeClients * (categories.length > 0 ? categories.length : 1))) * 100 : 0;
    }
    if (selCovValue) selCovValue.textContent = selPercent.toFixed(2) + '%';

    // Selection Count
    const selCovCount = document.getElementById('innovations-month-selection-coverage-count-kpi');
    if (selCovCount) {
        if (data.kpi_innovations_attended !== undefined && data.kpi_clients_attended !== undefined) {
            selCovCount.textContent = `${data.kpi_innovations_attended} de ${data.kpi_clients_attended}`;
        } else {
            selCovCount.textContent = totalSelectionPos + ' de ' + (activeClients * categories.length);
        }
    }
}

function renderInnovationsChart(data) {
    const ctx = document.getElementById('innovations-month-chartContainer');
    if (!ctx || !data || !data.categories) return;

    if (innovationsChart) {
        innovationsChart.destroy();
    }

    const categories = data.categories.sort((a,b) => b.pos_current - a.pos_current);

    const labels = categories.map(c => c.name);

    // Calcular % usando a Base Atendida (positivação geral) dinâmica de cada mês específico
    const baseCurrent = data.attended_current || 1;
    const baseM1 = data.attended_prev_m1 || 1;
    const baseM2 = data.attended_prev_m2 || 1;
    const baseM3 = data.attended_prev_m3 || 1;

    const currentData = categories.map(c => ((c.pos_current / baseCurrent) * 100).toFixed(1));
    const prevM1Data = categories.map(c => ((c.pos_prev_m1 / baseM1) * 100).toFixed(1));
    const prevM2Data = categories.map(c => ((c.pos_prev_m2 / baseM2) * 100).toFixed(1));
    const prevM3Data = categories.map(c => ((c.pos_prev_m3 / baseM3) * 100).toFixed(1));

    // Get month labels based on the selected target date in the filters
    const yearFilter = document.getElementById('innovations-ano-filter')?.value;
    const monthFilter = document.getElementById('innovations-mes-filter')?.value;

    let targetDate = new Date();
    if(yearFilter && yearFilter !== 'todos' && monthFilter) {
        targetDate = new Date(yearFilter, monthFilter - 1, 1);
    }

    const monthNames = MONTHS_PT_SHORT;

    const getMonthName = (date, subtractMonths) => {
        let d = new Date(date);
        d.setMonth(d.getMonth() - subtractMonths);
        return monthNames[d.getMonth()];
    };

    const labelCurrent = getMonthName(targetDate, 0);
    const labelM1 = getMonthName(targetDate, 1);
    const labelM2 = getMonthName(targetDate, 2);
    const labelM3 = getMonthName(targetDate, 3);

    innovationsChart = new Chart(ctx, {
        plugins: [ChartDataLabels],
        type: 'bar',
        data: {
            labels: labels,
                                                datasets: [
                {
                    label: labelM3,
                    data: prevM3Data,
                    backgroundColor: '#eaf7f8',
                    borderSkipped: 'bottom',
                    borderRadius: { topLeft: 6, topRight: 6, bottomLeft: 0, bottomRight: 0 }
                },
                {
                    label: labelM2,
                    data: prevM2Data,
                    backgroundColor: '#379fae',
                    borderSkipped: 'bottom',
                    borderRadius: { topLeft: 6, topRight: 6, bottomLeft: 0, bottomRight: 0 }
                },
                {
                    label: labelM1,
                    data: prevM1Data,
                    backgroundColor: '#316a9a',
                    borderSkipped: 'bottom',
                    borderRadius: { topLeft: 6, topRight: 6, bottomLeft: 0, bottomRight: 0 }
                },
                {
                    label: labelCurrent + ' (Mês Atual)',
                    data: currentData,
                    backgroundColor: '#ffaa4d',
                    borderSkipped: 'bottom',
                    borderRadius: { topLeft: 6, topRight: 6, bottomLeft: 0, bottomRight: 0 }
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                    labels: {
                        color: '#94a3b8',
                        font: { size: 10 }
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.dataset.label + ': ' + context.parsed.y + '%';
                        }
                    }
                },
                datalabels: {
                    display: function(context) {
                        return context.dataset.data[context.dataIndex] > 0;
                    },
                    color: '#fff',
                    font: { weight: 'bold', size: 10 },
                    anchor: 'end',
                    align: 'top',
                    offset: 2,
                    formatter: function(value) {
                        return value + '%';
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#94a3b8', font: { size: 10 }, callback: function(value) { return value + '%'; } }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#94a3b8', font: { size: 10, weight: 'bold' } }
                }
            }
        }
    });
}

// Make global to be accessible by inline onclick handler
window.toggleInnovationRow = function(safeId) {
    const childRows = document.querySelectorAll(`.innovations-child-${safeId}`);
    const icon = document.getElementById(`icon-innovations-${safeId}`);
    
    if (childRows.length === 0) return;
    
    const isHidden = childRows[0].classList.contains('hidden');
    
    childRows.forEach(row => {
        if (isHidden) {
            row.classList.remove('hidden');
        } else {
            row.classList.add('hidden');
        }
    });
    
    if (icon) {
        if (isHidden) {
            // Expand (Minus icon)
            icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path>';
        } else {
            // Collapse (Plus icon)
            icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>';
        }
    }
};

window.renderInnovationsTable = function(data) {
    const tbody = document.getElementById('innovations-month-table-body');
    if (!tbody || !data || !data.categories) return;

    let html = '';
    
    // Use dynamic period-specific attended bases instead of a fixed 12m active base
    // Fallback to 1 to prevent division by zero
    const attCurrent = data.attended_current || 1;
    const attPrevYear = data.attended_prev_year || 1;
    const attPrevM1 = data.attended_prev_m1 || 1;
    const attAvg12m = data.attended_12m > 0 ? (data.attended_12m / 3.0) : 1; 

    // Pre-group products by category for O(N+M) performance
    const productsByCategory = new Map();
    if (data.products && Array.isArray(data.products)) {
        for (const p of data.products) {
            if (!productsByCategory.has(p.category)) {
                productsByCategory.set(p.category, []);
            }
            productsByCategory.get(p.category).push(p);
        }
    }

    data.categories.forEach((cat, idx) => {
        let catPosAtual = Math.round(cat.pos_current || 0);
        let catPosPrevYear = Math.round(cat.pos_prev_year || 0);
        let catPosPrevM1 = Math.round(cat.pos_prev_m1 || 0);
        let catPosAvg12m = Math.round(cat.pos_avg_12m || 0);
        let catEstoque = Math.round(cat.estoque_current || 0);
        
        let varPercent = cat.pos_prev_m1 > 0 ? (((cat.pos_current - cat.pos_prev_m1) / cat.pos_prev_m1) * 100).toFixed(1) : (cat.pos_current > 0 ? 100 : 0);
        let varColor = varPercent >= 0 ? 'text-green-400' : 'text-red-400';
        
        const safeId = cat.name.replace(/[^a-zA-Z0-9]/g, '_');

        // Category Row (Parent)
        html += `
            <tr class="hover:bg-slate-700/30 transition-colors cursor-pointer bg-slate-800/30" onclick="toggleInnovationRow('${safeId}')">
                <td class="px-4 py-4 text-white font-bold whitespace-normal flex items-center gap-2">
                    <svg id="icon-innovations-${safeId}" class="w-4 h-4 text-orange-500 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>
                    ${escapeHtml(cat.name)}
                </td>
                <td class="px-4 py-4 text-slate-400 text-xs italic"></td>
                <td class="px-4 py-4 text-center font-bold text-white">${escapeHtml(catEstoque)} cx</td>
                <td class="px-4 py-4 text-center text-slate-400">${escapeHtml(catPosAvg12m)}</td>
                <td class="px-4 py-4 text-center text-slate-400">${escapeHtml(catPosPrevYear)}</td>
                <td class="px-4 py-4 text-center text-slate-400">${escapeHtml(catPosPrevM1)}</td>
                <td class="px-4 py-4 text-center font-bold text-white">${escapeHtml(catPosAtual)}</td>
                <td class="px-4 py-4 text-center ${escapeHtml(varColor)} font-bold">${escapeHtml(varPercent)}%</td>
            </tr>
        `;

        // Product Rows (Children)
        const productsInCat = productsByCategory.get(cat.name) || [];
        productsInCat.forEach(p => {
            let posAtual = Math.round(p.pos_current || 0);
            let posPrevYear = Math.round(p.pos_prev_year || 0);
            let posPrevM1 = Math.round(p.pos_prev_m1 || 0);
            let posAvg12m = Math.round(p.pos_avg_12m || 0);
            let pEstoque = Math.round(p.estoque_current || 0);
            
            let pVarPercent = p.pos_prev_m1 > 0 ? (((p.pos_current - p.pos_prev_m1) / p.pos_prev_m1) * 100).toFixed(1) : (p.pos_current > 0 ? 100 : 0);
            let pVarColor = pVarPercent >= 0 ? 'text-green-400' : 'text-red-400';

            html += `
                <tr class="hover:bg-slate-700/30 transition-colors hidden innovations-child-${safeId}">
                    <td class="px-4 py-4 pl-10 text-slate-400 text-xs flex items-center gap-2">
                        <svg class="w-3 h-3 text-slate-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                    </td>
                    <td class="px-4 py-4 text-slate-300 text-xs">${escapeHtml(p.code)} - ${escapeHtml(p.name)}</td>
                    <td class="px-4 py-4 text-center font-medium text-slate-300">${escapeHtml(pEstoque)} cx</td>
                    <td class="px-4 py-4 text-center text-slate-500">${escapeHtml(posAvg12m)}</td>
                    <td class="px-4 py-4 text-center text-slate-500">${escapeHtml(posPrevYear)}</td>
                    <td class="px-4 py-4 text-center text-slate-500">${escapeHtml(posPrevM1)}</td>
                    <td class="px-4 py-4 text-center font-medium text-slate-300">${escapeHtml(posAtual)}</td>
                    <td class="px-4 py-4 text-center ${escapeHtml(pVarColor)} text-xs font-bold">${escapeHtml(pVarPercent)}%</td>
                </tr>
            `;
        });
    });

    if (data.categories.length === 0) {
        html = '<tr><td colspan="8" class="p-4 text-center text-slate-500">Nenhum dado encontrado para os filtros selecionados.</td></tr>';
    }

    tbody.innerHTML = html;
};

// Helper para pegar valor de inputs (pode precisar ajuste dependendo de como voce estruturou os selects)
function getSelectedValues(id) {
    const el = document.getElementById(id);
    if (!el) return [];
    if (el.tagName === 'SELECT') {
        return Array.from(el.selectedOptions).map(o => o.value);
    }
    if (el.tagName === 'INPUT' && el.type === 'hidden') {
         return el.value ? [el.value] : [];
    }

    // Suporte para o dropdown customizado
    const tagsContainer = el.querySelector('.flex.flex-wrap.gap-1.items-center');
    if (tagsContainer) {
        const values = [];
        tagsContainer.querySelectorAll('.px-2.py-0\\.5').forEach(tag => {
            const text = tag.textContent.trim().replace('×', '').trim();
            if (text && text !== 'Todos') values.push(text);
        });
        return values.length > 0 ? values : [];
    }

    // Tentativa generica caso seja input text
    if (el.tagName === 'INPUT' && el.type === 'text') {
        return el.value ? [el.value] : [];
    }

    // Se é um wrapper, verifica se tem um select dentro
    const selectInside = el.querySelector('select');
    if (selectInside) {
        return Array.from(selectInside.selectedOptions).map(o => o.value);
    }

    return [];
}

// Global Filter Setup for new pages
let innovationsSelectedSupervisors = [];
let innovationsSelectedVendedores = [];
let innovationsSelectedCidades = [];
let innovationsSelectedTiposVenda = [];
let innovationsSelectedRedes = [];
let innovationsSelectedFiliais = [];
let innovationsSelectedCategorias = [];

// DOM Elements
const innovationsSupervisorFilterBtn = document.getElementById('innovations-supervisor-filter-btn');
const innovationsSupervisorFilterDropdown = document.getElementById('innovations-supervisor-filter-dropdown');
const innovationsVendedorFilterBtn = document.getElementById('innovations-vendedor-filter-btn');
const innovationsVendedorFilterDropdown = document.getElementById('innovations-vendedor-filter-dropdown');
const innovationsVendedorFilterList = document.getElementById('innovations-vendedor-filter-list');
const innovationsVendedorFilterSearch = document.getElementById('innovations-vendedor-filter-search');
const innovationsCidadeFilterBtn = document.getElementById('innovations-cidade-filter-btn');
const innovationsCidadeFilterDropdown = document.getElementById('innovations-cidade-filter-dropdown');
const innovationsCidadeFilterList = document.getElementById('innovations-cidade-filter-list');
const innovationsCidadeFilterSearch = document.getElementById('innovations-cidade-filter-search');
const innovationsTipovendaFilterBtn = document.getElementById('innovations-tipovenda-filter-btn');
const innovationsTipovendaFilterDropdown = document.getElementById('innovations-tipovenda-filter-dropdown');
const innovationsRedeFilterBtn = document.getElementById('innovations-rede-filter-btn');
const innovationsRedeFilterDropdown = document.getElementById('innovations-rede-filter-dropdown');
const innovationsRedeFilterList = document.getElementById('innovations-rede-filter-list');
const innovationsRedeFilterSearch = document.getElementById('innovations-rede-filter-search');
const innovationsFilialFilterBtn = document.getElementById('innovations-filial-filter-btn');
const innovationsFilialFilterDropdown = document.getElementById('innovations-filial-filter-dropdown');
const innovationsCategoriaFilterBtn = document.getElementById('innovations-categoria-filter-btn');
const innovationsCategoriaFilterDropdown = document.getElementById('innovations-categoria-filter-dropdown');

// Filter change handler
const handleInnovationsFilterChange = () => {
    updateInnovationsMonthView();
};

document.addEventListener('click', (e) => {
    const dropdowns = [
        innovationsSupervisorFilterDropdown, innovationsVendedorFilterDropdown,
        innovationsCidadeFilterDropdown, innovationsTipovendaFilterDropdown,
        innovationsRedeFilterDropdown, innovationsFilialFilterDropdown,
        innovationsCategoriaFilterDropdown
    ];
    const btns = [
        innovationsSupervisorFilterBtn, innovationsVendedorFilterBtn,
        innovationsCidadeFilterBtn, innovationsTipovendaFilterBtn,
        innovationsRedeFilterBtn, innovationsFilialFilterBtn,
        innovationsCategoriaFilterBtn
    ];
    let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);

    if (anyClosed && innovationsMonthView && !innovationsMonthView.classList.contains('hidden')) {
        handleInnovationsFilterChange();
    }
});


const setupInnovationsFilters = async () => {
    if (isInnovationsInitialized) return;

    window.showDashboardLoading('innovations-month-view');

    const filters = {
        p_ano: null,
        p_mes: null,
        p_filial: [],
        p_cidade: [],
        p_supervisor: [],
        p_vendedor: [],
        p_fornecedor: [],
        p_tipovenda: [],
        p_rede: [],
        p_categoria: []
    };

    const cacheKey = generateCacheKey('dashboard_filters', filters);
    let filterData = null;

    try {
        const cachedEntry = await getFromCache(cacheKey);
        if (cachedEntry && cachedEntry.data) {
            AppLog.log('Serving Innovations Filters from Cache');
            filterData = cachedEntry.data;
        }
    } catch (e) { AppLog.warn('Cache error:', e); }

    if (!filterData) {
        const { data } = await supabase.rpc('get_dashboard_filters', filters);
        filterData = data;
        if (filterData) saveToCache(cacheKey, filterData);
    }

    if (!filterData) {
        window.hideDashboardLoading();
        return;
    }

    // Load Ano and Mes
    const anoSelect = document.getElementById('innovations-ano-filter');
    const mesSelect = document.getElementById('innovations-mes-filter');
    
    await fetchLastSalesDate();
    const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);

    if (anoSelect && filterData.anos) {
        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        anoSelect.innerHTML = '<option value="todos">Todos</option>' + filterData.anos.map(ano => `<option value="${escapeHtml(ano)}">${escapeHtml(ano)}</option>`).join('');

        // Initial filter values
        let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
        anoSelect.value = hasYear ? currentYear : 'todos';

        enhanceSelectToCustomDropdown(anoSelect);
        anoSelect.addEventListener('change', handleInnovationsFilterChange);
    }
    
    if (mesSelect) {
        const meses = MONTHS_PT;
        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        mesSelect.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${String(i + 1).padStart(2, '0')}">${m}</option>`).join('');

        // Initial filter value
        mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));

        enhanceSelectToCustomDropdown(mesSelect);
        mesSelect.addEventListener('change', handleInnovationsFilterChange);
    }

    // Load Multi-Selects using standard CityMultiSelect pattern
    setupCityMultiSelect(innovationsSupervisorFilterBtn, innovationsSupervisorFilterDropdown, innovationsSupervisorFilterDropdown, filterData.supervisors, innovationsSelectedSupervisors);
    setupCityMultiSelect(innovationsVendedorFilterBtn, innovationsVendedorFilterDropdown, innovationsVendedorFilterList, filterData.vendedores, innovationsSelectedVendedores, innovationsVendedorFilterSearch);
    setupCityMultiSelect(innovationsCidadeFilterBtn, innovationsCidadeFilterDropdown, innovationsCidadeFilterList, filterData.cidades, innovationsSelectedCidades, innovationsCidadeFilterSearch);
    setupCityMultiSelect(innovationsTipovendaFilterBtn, innovationsTipovendaFilterDropdown, innovationsTipovendaFilterDropdown, filterData.tipos_venda, innovationsSelectedTiposVenda);
    
    const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
    setupCityMultiSelect(innovationsRedeFilterBtn, innovationsRedeFilterDropdown, innovationsRedeFilterList, redes, innovationsSelectedRedes, innovationsRedeFilterSearch);
    
    setupCityMultiSelect(innovationsFilialFilterBtn, innovationsFilialFilterDropdown, innovationsFilialFilterDropdown, filterData.filiais, innovationsSelectedFiliais);

    // Load Inovações Categories
    try {
        const { data: inovacData } = await supabase.from('data_innovations').select('inovacoes').order('inovacoes', { ascending: true });
        if (inovacData) {
            const uniqueInovacoes = [...new Set(inovacData.map(i => i.inovacoes).filter(i => i))];
            setupCityMultiSelect(innovationsCategoriaFilterBtn, innovationsCategoriaFilterDropdown, innovationsCategoriaFilterDropdown, uniqueInovacoes, innovationsSelectedCategorias);
        }
    } catch (e) {
        AppLog.error("Error loading inovacoes categories", e);
    }
    
    window.hideDashboardLoading();

    
    const lpSupervisorBtn = document.getElementById("lp-supervisor-filter-btn");
    const lpSupervisorDropdown = document.getElementById("lp-supervisor-filter-dropdown");
    if (lpSupervisorBtn) setupCityMultiSelect(lpSupervisorBtn, lpSupervisorDropdown, lpSupervisorDropdown, filterData.supervisors, lpSelectedSupervisors);

    const lpVendedorBtn = document.getElementById("lp-vendedor-filter-btn");
    const lpVendedorDropdown = document.getElementById("lp-vendedor-filter-dropdown");
    const lpVendedorList = document.getElementById("lp-vendedor-filter-list");
    const lpVendedorSearch = document.getElementById("lp-vendedor-filter-search");
    if (lpVendedorBtn) setupCityMultiSelect(lpVendedorBtn, lpVendedorDropdown, lpVendedorList, filterData.vendedores, lpSelectedVendedores, lpVendedorSearch);

    const lpRedeBtn = document.getElementById("lp-rede-filter-btn");
    const lpRedeDropdown = document.getElementById("lp-rede-filter-dropdown");
    const lpRedeList = document.getElementById("lp-rede-filter-list");
    const lpRedeSearch = document.getElementById("lp-rede-filter-search");
    const lpRedesArray = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
    if (lpRedeBtn) setupCityMultiSelect(lpRedeBtn, lpRedeDropdown, lpRedeList, lpRedesArray, lpSelectedRedes, lpRedeSearch);

    const lpCidadeBtn = document.getElementById("lp-cidade-filter-btn");
    const lpCidadeDropdown = document.getElementById("lp-cidade-filter-dropdown");
    const lpCidadeList = document.getElementById("lp-cidade-filter-list");
    const lpCidadeSearch = document.getElementById("lp-cidade-filter-search");
    if (lpCidadeBtn) setupCityMultiSelect(lpCidadeBtn, lpCidadeDropdown, lpCidadeList, filterData.cidades, lpSelectedCidades, lpCidadeSearch);

    // Actually we need to call setupCityMultiSelect on wrappers if possible...
    // wait, for Supervisor/Vendedor/Rede the wrappers are handled differently inside updateLojaPerfeitaFilters ?
    // let's check how the others are initialized.
    

    isInnovationsInitialized = true;
};

// Listen for view load
document.addEventListener('DOMContentLoaded', () => {
    // Add setup on tab click or initially if those tabs are visible
});
// --- LOJA PERFEITA VIEW LOGIC ---
let lpSelectedClient = null; // To hold the specific selected client code

let lpFilterDebounce;

async function loadLojaPerfeitaFilters(forceClear = false) {

    const filters = {

        p_ano: null,

        p_mes: null,

        p_filial: forceClear ? [] : lpSelectedFiliais,

        p_cidade: forceClear ? [] : lpSelectedCidades,

        p_supervisor: forceClear ? [] : lpSelectedSupervisors,

        p_vendedor: forceClear ? [] : lpSelectedVendedores,

        p_fornecedor: [],

        p_tipovenda: [],

        p_rede: forceClear ? [] : lpSelectedRedes,

        p_categoria: []

    };



    try {

        const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);

        if (error) {

            AppLog.error('Error fetching Loja Perfeita filters:', error);

            return;

        }

        if (!filterData) return;



        const lpFilialBtn = document.getElementById("lp-filial-filter-btn");
        const lpFilialDropdown = document.getElementById("lp-filial-filter-dropdown");
        if (lpFilialBtn) setupCityMultiSelect(lpFilialBtn, lpFilialDropdown, lpFilialDropdown, filterData.filiais, lpSelectedFiliais);

        const lpSupervisorBtn = document.getElementById("lp-supervisor-filter-btn");

        const lpSupervisorDropdown = document.getElementById("lp-supervisor-filter-dropdown");

        if (lpSupervisorBtn) setupCityMultiSelect(lpSupervisorBtn, lpSupervisorDropdown, lpSupervisorDropdown, filterData.supervisors, lpSelectedSupervisors);



        const lpVendedorBtn = document.getElementById("lp-vendedor-filter-btn");

        const lpVendedorDropdown = document.getElementById("lp-vendedor-filter-dropdown");

        const lpVendedorList = document.getElementById("lp-vendedor-filter-list");

        const lpVendedorSearch = document.getElementById("lp-vendedor-filter-search");

        if (lpVendedorBtn) setupCityMultiSelect(lpVendedorBtn, lpVendedorDropdown, lpVendedorList, filterData.vendedores, lpSelectedVendedores, lpVendedorSearch);



        const lpRedeBtn = document.getElementById("lp-rede-filter-btn");

        const lpRedeDropdown = document.getElementById("lp-rede-filter-dropdown");

        const lpRedeList = document.getElementById("lp-rede-filter-list");

        const lpRedeSearch = document.getElementById("lp-rede-filter-search");

        const lpRedesArray = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];

        if (lpRedeBtn) setupCityMultiSelect(lpRedeBtn, lpRedeDropdown, lpRedeList, lpRedesArray, lpSelectedRedes, lpRedeSearch);



        const lpCidadeBtn = document.getElementById("lp-cidade-filter-btn");

        const lpCidadeDropdown = document.getElementById("lp-cidade-filter-dropdown");

        const lpCidadeList = document.getElementById("lp-cidade-filter-list");

        const lpCidadeSearch = document.getElementById("lp-cidade-filter-search");

        if (lpCidadeBtn) setupCityMultiSelect(lpCidadeBtn, lpCidadeDropdown, lpCidadeList, filterData.cidades, lpSelectedCidades, lpCidadeSearch);



    } catch (err) {

        AppLog.error('Exception fetching Loja Perfeita filters:', err);

    }

}


const handleLojaPerfeitaFilterChange = () => {
    clearTimeout(lpFilterDebounce);
    lpFilterDebounce = setTimeout(() => {
        loadLojaPerfeitaFilters();
    }, 300);

    updateLojaPerfeitaView();
};

document.addEventListener('click', (e) => {
    const dropdowns = [
        document.getElementById('lp-filial-filter-dropdown'),
        document.getElementById('lp-supervisor-filter-dropdown'),
        document.getElementById('lp-vendedor-filter-dropdown'),
        document.getElementById('lp-rede-filter-dropdown'),
        document.getElementById('lp-cidade-filter-dropdown')
    ];
    const btns = [
        document.getElementById('lp-filial-filter-btn'),
        document.getElementById('lp-supervisor-filter-btn'),
        document.getElementById('lp-vendedor-filter-btn'),
        document.getElementById('lp-rede-filter-btn'),
        document.getElementById('lp-cidade-filter-btn')
    ];
    let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);

    if (anyClosed) {
        handleLojaPerfeitaFilterChange();
    }
});


function setupLpClientSearchAutocomplete() {
    const input = document.getElementById('lp-cliente-search-input');
    const dropdown = document.getElementById('lp-cliente-search-dropdown');
    const clearBtn = document.getElementById('lp-cliente-search-clear');

    if (!input || !dropdown) return;

    let debounceTimer;

    input.addEventListener('input', (e) => {
        const val = e.target.value;
        if (val.length > 0) {
            clearBtn.classList.remove('hidden');
        } else {
            clearBtn.classList.add('hidden');
        }

        clearTimeout(debounceTimer);
        
        if (val.length < 3) {
            dropdown.innerHTML = '';
            dropdown.classList.add('hidden');
            return;
        }

        debounceTimer = setTimeout(async () => {
            try {
                // Use custom RPC to apply current filters to client search
                const searchParams = {
                    p_search: val,
                    p_filial: lpSelectedFiliais.length > 0 ? lpSelectedFiliais : null,
                    p_cidade: lpSelectedCidades.length > 0 ? lpSelectedCidades : null,
                    p_supervisor: lpSelectedSupervisors.length > 0 ? lpSelectedSupervisors : null,
                    p_vendedor: lpSelectedVendedores.length > 0 ? lpSelectedVendedores : null,
                    p_rede: lpSelectedRedes.length > 0 ? lpSelectedRedes : null
                };
                const { data, error } = await supabase.rpc('search_loja_perfeita_clients', searchParams);
                
                if (error) throw error;

                dropdown.innerHTML = '';
                
                if (!data || data.length === 0) {
                    dropdown.innerHTML = '<div class="p-3 text-sm text-slate-400 text-center">Nenhum cliente encontrado</div>';
                    dropdown.classList.remove('hidden');
                    return;
                }

                data.forEach(item => {
                    const div = document.createElement('div');
                    div.className = 'p-3 hover:bg-slate-700/50 cursor-pointer border-b border-slate-700/30 last:border-0 transition-colors';
                    
                    const flexContainer = document.createElement('div');
                    flexContainer.className = 'flex items-start justify-between';

                    const innerContainer = document.createElement('div');
                    innerContainer.className = 'flex-1 min-w-0';

                    const topRow = document.createElement('div');
                    topRow.className = 'flex items-center gap-2 mb-1';

                    const codSpan = document.createElement('span');
                    codSpan.className = 'text-xs font-bold text-slate-300 whitespace-nowrap';
                    codSpan.textContent = item.codigo_cliente;

                    const nameSpan = document.createElement('span');
                    nameSpan.className = 'text-sm font-bold text-white truncate';
                    nameSpan.textContent = item.razaosocial || item.nomecliente || 'S/ NOME';

                    topRow.appendChild(codSpan);
                    topRow.appendChild(nameSpan);

                    const bottomRow = document.createElement('div');
                    bottomRow.className = 'flex items-center gap-2 text-xs text-slate-400';

                    const citySpan = document.createElement('span');
                    citySpan.className = 'truncate uppercase';
                    citySpan.textContent = item.cidade || 'N/I';

                    const dotSpan = document.createElement('span');
                    dotSpan.className = 'text-slate-600';
                    dotSpan.textContent = '•';

                    const cnpjSpan = document.createElement('span');
                    cnpjSpan.className = 'whitespace-nowrap';
                    cnpjSpan.textContent = item.cnpj || 'N/I';

                    bottomRow.appendChild(citySpan);
                    bottomRow.appendChild(dotSpan);
                    bottomRow.appendChild(cnpjSpan);

                    innerContainer.appendChild(topRow);
                    innerContainer.appendChild(bottomRow);
                    flexContainer.appendChild(innerContainer);
                    div.appendChild(flexContainer);
                    
                    div.addEventListener('click', () => {
                        input.value = `${item.codigo_cliente} - ${item.razaosocial || item.nomecliente}`;
                        lpSelectedClient = item.codigo_cliente;
                        dropdown.classList.add('hidden');
                        clearBtn.classList.remove('hidden');
                        updateLojaPerfeitaView(); // Trigger update with the new client
                    });
                    
                    dropdown.appendChild(div);
                });
                dropdown.classList.remove('hidden');
            } catch (err) {
                AppLog.error("Error fetching client suggestions:", err);
            }
        }, 400); // 400ms debounce
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
        if (!input.contains(e.target) && !dropdown.contains(e.target)) {
            dropdown.classList.add('hidden');
        }
    });

    clearBtn.addEventListener('click', () => {
        input.value = '';
        lpSelectedClient = null;
        clearBtn.classList.add('hidden');
        dropdown.classList.add('hidden');
        updateLojaPerfeitaView();
    });
}


async function updateLojaPerfeitaView() {
    window.showDashboardLoading('loja-perfeita-view');

    const filters = {
        p_cidade: lpSelectedCidades,
        p_filial: lpSelectedFiliais,
        p_supervisor: lpSelectedSupervisors,
        p_vendedor: lpSelectedVendedores,
        p_rede: lpSelectedRedes
    };

    const rpcFilters = {
        p_filial: filters.p_filial.length ? filters.p_filial : null,
        p_codcli: lpSelectedClient ? lpSelectedClient : null,
        p_cidade: filters.p_cidade.length ? filters.p_cidade : null,
        p_supervisor: filters.p_supervisor.length ? filters.p_supervisor : null,
        p_vendedor: filters.p_vendedor.length ? filters.p_vendedor : null,
        p_rede: filters.p_rede.length ? filters.p_rede : null
    };

    try {
        const { data, error } = await supabase.rpc('get_loja_perfeita_data', rpcFilters);

        if (error) {
            AppLog.error('Error fetching Loja Perfeita data:', error);
            window.hideDashboardLoading();
            return;
        }

        renderLpKPIs(data.kpis);
        renderLpTable(data.clients);

    } catch (err) {
        AppLog.error('Exception fetching Loja Perfeita data:', err);
    } finally {
        window.hideDashboardLoading();
    }
}

function renderLpKPIs(kpis) {
    if (!kpis) return;

    const avgScoreEl = document.getElementById('lp-kpi-avg-score');
    const totalAuditsEl = document.getElementById('lp-kpi-total-audits');
    const perfStoresEl = document.getElementById('lp-kpi-perfect-stores');
    const avgScoreCircle = document.getElementById('lp-avg-score-circle'); // Pode precisar do chart

    if (avgScoreEl) avgScoreEl.textContent = formatNumber(kpis.avg_score, 1);
    if (totalAuditsEl) totalAuditsEl.textContent = formatNumber(kpis.total_audits, 0);

    if (perfStoresEl) {
        let pct = kpis.total_audits > 0 ? (kpis.perfect_stores / kpis.total_audits) * 100 : 0;
        perfStoresEl.textContent = pct.toFixed(1) + '%';
        const sub = document.getElementById('lp-kpi-perfect-stores-sub');
        if (sub) sub.textContent = formatNumber(kpis.perfect_stores, 0) + ' Auditorias';
    }
}

function renderLpTable(clients) {
    const tbody = document.getElementById('lp-table-body');
    if (!tbody || !clients) return;

    tbody.innerHTML = clients.map(c => {
        const colorClass = c.score >= 80 ? 'text-green-400' : c.score >= 50 ? 'text-yellow-400' : 'text-red-400';
        return `
            <tr class="hover:bg-slate-700/30 transition-colors">
                <td class="px-6 py-4 text-slate-400 text-xs">${escapeHtml(c.codcli)}</td>
                <td class="px-6 py-4 font-bold text-slate-200">${escapeHtml(c.client_name)}</td>
                <td class="px-6 py-4">
                    <span class="font-bold text-white block">${escapeHtml(c.researcher)}</span>
                </td>
                <td class="px-6 py-4 text-slate-400">${escapeHtml(c.city || '--')}</td>
                <td class="px-6 py-4 text-center font-bold ${colorClass} text-base">${escapeHtml(formatNumber(c.score, 1))}</td>
            </tr>
        `;
    }).join('');
}


async function renderInnovationsMonthView() {
    if (!isInnovationsInitialized) {
        await setupInnovationsFilters();
    }
    updateInnovationsMonthView();
}

async function renderLojaPerfeitaView() {
    window.showDashboardLoading('loja-perfeita-view');
    if (!isLojaPerfeitaInitialized) {
        await setupInnovationsFilters();
        await loadLojaPerfeitaFilters();
        setupLpClientSearchAutocomplete();
        isLojaPerfeitaInitialized = true;
    }
    updateLojaPerfeitaView();
}

window.clearAllFilters = async function(prefix) {
    if (prefix === 'innovations') {
        const anoSelect = document.getElementById('innovations-ano-filter');
        const mesSelect = document.getElementById('innovations-mes-filter');

        await fetchLastSalesDate();
        const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);

        if (anoSelect) {
            // Check if currentYear is in options, if not default to 'todos'
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        
        innovationsSelectedSupervisors.length = 0;
        innovationsSelectedVendedores.length = 0;
        innovationsSelectedCidades.length = 0;
        innovationsSelectedTiposVenda.length = 0;
        innovationsSelectedRedes.length = 0;
        innovationsSelectedFiliais.length = 0;
        innovationsSelectedCategorias.length = 0;
        
        // Uncheck all custom select items visually
        const wrappers = [
            'innovations-supervisor-filter-dropdown', 'innovations-vendedor-filter-dropdown',
            'innovations-cidade-filter-dropdown', 'innovations-tipovenda-filter-dropdown',
            'innovations-rede-filter-dropdown', 'innovations-filial-filter-dropdown',
            'innovations-categoria-filter-dropdown'
        ];
        lpSelectedCidades.length = 0;
        const lpCodcliBtn = document.getElementById("lp-codcli-filter-btn");
        if (lpCodcliBtn) {
            lpCodcliBtn.innerHTML = `<span class="truncate">Todos</span><svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>`;
            lpCodcliBtn.classList.remove("text-white", "font-medium", "bg-white/10");
            lpCodcliBtn.classList.add("text-slate-300");
        }
        const lpCodcliDropdown = document.getElementById("lp-codcli-filter-dropdown");
        if(lpCodcliDropdown) {
            uncheckAllCheckboxes(lpCodcliDropdown);
        }

        wrappers.forEach(id => {
            const dropdown = document.getElementById(id);
            if (dropdown) {
                uncheckAllCheckboxes(dropdown);
            }
        });

        // Clear visual tags if any (they are usually sibling or child elements of the dropdown container)
        const tagContainers = [
            'innovations-supervisor-filter-dropdown', 'innovations-vendedor-filter-dropdown',
            'innovations-cidade-filter-dropdown', 'innovations-tipovenda-filter-dropdown',
            'innovations-rede-filter-dropdown', 'innovations-filial-filter-dropdown',
            'innovations-categoria-filter-dropdown'
        ];
        tagContainers.forEach(id => {
            const dropdown = document.getElementById(id);
            if (dropdown && dropdown.parentElement) {
                const tagContainer = dropdown.parentElement.querySelector('.flex.flex-wrap.gap-1.items-center');
                if (tagContainer) tagContainer.innerHTML = '';
            }
        });


        // Reset Search Inputs
        const searchInputIds = [
            'innovations-supervisor-filter-search', 'innovations-vendedor-filter-search',
            'innovations-cidade-filter-search', 'innovations-rede-filter-search'
        ];
        searchInputIds.forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });

        // Reset button labels
        const btns = [
            'innovations-supervisor-filter-btn', 'innovations-vendedor-filter-btn',
            'innovations-cidade-filter-btn', 'innovations-tipovenda-filter-btn',
            'innovations-rede-filter-btn', 'innovations-filial-filter-btn',
            'innovations-categoria-filter-btn'
        ];
        btns.forEach(id => {
            const btn = document.getElementById(id);
            if (btn) {
                const span = btn.querySelector('span');
                if (span) {
                    if (id.includes('vendedor') || id.includes('fornecedor') || id.includes('supervisor') || id.includes('tipovenda')) {
                        span.textContent = 'Todos';
                    } else {
                        span.textContent = 'Todas';
                    }
                }
            }
        });

        // We must re-setup the filters to ensure options are refreshed correctly.
        // `isInnovationsInitialized` flag is true, so `setupInnovationsFilters` won't run its code.
        // We will directly call the RPC to get fresh filters without any active selection.
        const filters = {
            p_ano: null,
            p_mes: null,
            p_cidade: [], p_filial: [], p_supervisor: [], p_vendedor: [],
            p_rede: [], p_tipovenda: [], p_categoria: []
        };
        supabase.rpc('get_dashboard_filters', filters).then(({data, error}) => {
            if (data && !error) {
                // Re-bind the standard multi-selects to ensure the checkboxes are correctly refreshed from DB
                setupCityMultiSelect(document.getElementById('innovations-supervisor-filter-btn'), document.getElementById('innovations-supervisor-filter-dropdown'), document.getElementById('innovations-supervisor-filter-dropdown'), data.supervisors, innovationsSelectedSupervisors);
                setupCityMultiSelect(document.getElementById('innovations-vendedor-filter-btn'), document.getElementById('innovations-vendedor-filter-dropdown'), document.getElementById('innovations-vendedor-filter-list'), data.vendedores, innovationsSelectedVendedores, document.getElementById('innovations-vendedor-filter-search'));
                setupCityMultiSelect(document.getElementById('innovations-cidade-filter-btn'), document.getElementById('innovations-cidade-filter-dropdown'), document.getElementById('innovations-cidade-filter-list'), data.cidades, innovationsSelectedCidades, document.getElementById('innovations-cidade-filter-search'));
                setupCityMultiSelect(document.getElementById('innovations-tipovenda-filter-btn'), document.getElementById('innovations-tipovenda-filter-dropdown'), document.getElementById('innovations-tipovenda-filter-dropdown'), data.tipos_venda, innovationsSelectedTiposVenda);
                
                const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
                setupCityMultiSelect(document.getElementById('innovations-rede-filter-btn'), document.getElementById('innovations-rede-filter-dropdown'), document.getElementById('innovations-rede-filter-list'), redes, innovationsSelectedRedes, document.getElementById('innovations-rede-filter-search'));
                
                setupCityMultiSelect(document.getElementById('innovations-filial-filter-btn'), document.getElementById('innovations-filial-filter-dropdown'), document.getElementById('innovations-filial-filter-dropdown'), data.filiais, innovationsSelectedFiliais);
                
                supabase.from('data_innovations').select('inovacoes').order('inovacoes', { ascending: true }).then(({data: inovacData}) => {
                    if (inovacData) {
                        const uniqueInovacoes = [...new Set(inovacData.map(i => i.inovacoes).filter(i => i))];
                        setupCityMultiSelect(document.getElementById('innovations-categoria-filter-btn'), document.getElementById('innovations-categoria-filter-dropdown'), document.getElementById('innovations-categoria-filter-dropdown'), uniqueInovacoes, innovationsSelectedCategorias);
                    }
                    updateInnovationsMonthView();
                });
            } else {
                updateInnovationsMonthView();
            }
        });

    } else if (prefix === 'estrelas') {
        const anoSelect = document.getElementById('estrelas-ano-filter');
        const mesSelect = document.getElementById('estrelas-mes-filter');

        if(typeof fetchLastSalesDate === 'function') await fetchLastSalesDate();
        const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);

        if (anoSelect) {
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        estrelasSelectedSupervisors.length = 0;
        estrelasSelectedVendedores.length = 0;
        estrelasSelectedCidades.length = 0;
        estrelasSelectedTiposVenda.length = 0;
        estrelasSelectedRedes.length = 0;
        estrelasSelectedFiliais.length = 0;
        estrelasSelectedCategorias.length = 0;
        estrelasSelectedFornecedores.length = 0;

        const wrappers = [
            'estrelas-supervisor-filter-dropdown', 'estrelas-vendedor-filter-dropdown',
            'estrelas-cidade-filter-dropdown', 'estrelas-tipovenda-filter-dropdown',
            'estrelas-rede-filter-dropdown', 'estrelas-filial-filter-dropdown',
            'estrelas-categoria-filter-dropdown', 'estrelas-fornecedor-filter-dropdown'
        ];

        wrappers.forEach(id => {
            const dropdown = document.getElementById(id);
            if (dropdown) {
                uncheckAllCheckboxes(dropdown);
            }
        });

        const searchInputIds = [
            'estrelas-supervisor-filter-search', 'estrelas-vendedor-filter-search',
            'estrelas-cidade-filter-search', 'estrelas-rede-filter-search',
            'estrelas-categoria-filter-search', 'estrelas-fornecedor-filter-search'
        ];
        searchInputIds.forEach(id => {
            const el = document.getElementById(id);
            if (el) el.value = '';
        });

        const btns = [
            'estrelas-supervisor-filter-btn', 'estrelas-vendedor-filter-btn',
            'estrelas-cidade-filter-btn', 'estrelas-tipovenda-filter-btn',
            'estrelas-rede-filter-btn', 'estrelas-filial-filter-btn',
            'estrelas-categoria-filter-btn', 'estrelas-fornecedor-filter-btn'
        ];
        btns.forEach(id => {
            const btn = document.getElementById(id);
            if (btn) {
                const span = btn.querySelector('span');
                if (span) {
                    if (id.includes('vendedor') || id.includes('fornecedor') || id.includes('supervisor') || id.includes('tipovenda')) {
                        span.textContent = 'Todos';
                    } else {
                        span.textContent = 'Todas';
                    }
                }
            }
        });

        const filters = {
            p_ano: null, p_mes: null, p_cidade: [], p_filial: [], p_supervisor: [],
            p_vendedor: [], p_rede: [], p_tipovenda: [], p_categoria: [], p_fornecedor: []
        };
        supabase.rpc('get_dashboard_filters', filters).then(({data, error}) => {
            if (data && !error && typeof setupCityMultiSelect === 'function') {
                setupCityMultiSelect(document.getElementById('estrelas-supervisor-filter-btn'), document.getElementById('estrelas-supervisor-filter-dropdown'), document.getElementById('estrelas-supervisor-filter-dropdown'), data.supervisors, estrelasSelectedSupervisors);
                setupCityMultiSelect(document.getElementById('estrelas-vendedor-filter-btn'), document.getElementById('estrelas-vendedor-filter-dropdown'), document.getElementById('estrelas-vendedor-filter-list'), data.vendedores, estrelasSelectedVendedores, document.getElementById('estrelas-vendedor-filter-search'));
                setupCityMultiSelect(document.getElementById('estrelas-fornecedor-filter-btn'), document.getElementById('estrelas-fornecedor-filter-dropdown'), document.getElementById('estrelas-fornecedor-filter-list'), data.fornecedores, estrelasSelectedFornecedores, document.getElementById('estrelas-fornecedor-filter-search'), true);
                setupCityMultiSelect(document.getElementById('estrelas-cidade-filter-btn'), document.getElementById('estrelas-cidade-filter-dropdown'), document.getElementById('estrelas-cidade-filter-list'), data.cidades, estrelasSelectedCidades, document.getElementById('estrelas-cidade-filter-search'));
                setupCityMultiSelect(document.getElementById('estrelas-tipovenda-filter-btn'), document.getElementById('estrelas-tipovenda-filter-dropdown'), document.getElementById('estrelas-tipovenda-filter-dropdown'), data.tipos_venda, estrelasSelectedTiposVenda);

                const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
                setupCityMultiSelect(document.getElementById('estrelas-rede-filter-btn'), document.getElementById('estrelas-rede-filter-dropdown'), document.getElementById('estrelas-rede-filter-list'), redes, estrelasSelectedRedes, document.getElementById('estrelas-rede-filter-search'));

                setupCityMultiSelect(document.getElementById('estrelas-filial-filter-btn'), document.getElementById('estrelas-filial-filter-dropdown'), document.getElementById('estrelas-filial-filter-dropdown'), data.filiais, estrelasSelectedFiliais);
                setupCityMultiSelect(document.getElementById('estrelas-categoria-filter-btn'), document.getElementById('estrelas-categoria-filter-dropdown'), document.getElementById('estrelas-categoria-filter-list'), data.categorias || [], estrelasSelectedCategorias, document.getElementById('estrelas-categoria-filter-search'));

                updateEstrelasView();
            } else {
                updateEstrelasView();
            }
        });

    } else if (prefix === 'agenda') {
        const anoSelect = document.getElementById('agenda-ano-filter');
        const mesSelect = document.getElementById('agenda-mes-filter');

        const currentYear = new Date().getFullYear().toString();
        const currentMonth = (new Date().getMonth() + 1).toString();

        if (anoSelect) {
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        agendaSelectedSupervisors.length = 0;
        agendaSelectedRotas.length = 0;

        ['agenda-supervisor', 'agenda-rota'].forEach(pref => {
            const btn = document.getElementById(`${pref}-filter-btn`);
            if (btn) {
                const label = pref.includes('supervisor') ? 'Todos' : 'Todas';
                const span = btn.querySelector('span.truncate');
                if (span) {
                    span.textContent = label;
                } else {
                    btn.innerHTML = `<span class="truncate pr-2">${label}</span><svg aria-hidden="true" class="w-4 h-4 text-slate-400 flex-shrink-0 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>`;
                }
            }
            const dropdown = document.getElementById(`${pref}-filter-dropdown`);
            if (dropdown) {
                uncheckAllCheckboxes(dropdown);
            }
        });
        
        updateAgendaView();
    } else if (prefix === 'lp') {
        lpSelectedCidades.length = 0;
        lpSelectedFiliais.length = 0;
        lpSelectedSupervisors.length = 0;
        lpSelectedVendedores.length = 0;
        lpSelectedRedes.length = 0;
        
        ['lp-supervisor', 'lp-vendedor', 'lp-rede', 'lp-cidade'].forEach(prefix => {
            const btn = document.getElementById(`${prefix}-filter-btn`);
            if (btn) {
                btn.innerHTML = `<span class="truncate">Todos</span><svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>`;
                btn.classList.remove("text-white", "font-medium", "bg-white/10");
                btn.classList.add("text-slate-300");
            }
            const dropdown = document.getElementById(`${prefix}-filter-dropdown`);
            if (dropdown) {
                uncheckAllCheckboxes(dropdown);
            }

            // clear search inputs if they exist
            const searchInput = document.getElementById(`${prefix}-filter-search`);
            if (searchInput) searchInput.value = '';
        });
        
        // Clear Client Autocomplete
        lpSelectedClient = null;
        const lpClientInput = document.getElementById('lp-cliente-search-input');
        const lpClientClearBtn = document.getElementById('lp-cliente-search-clear');
        const lpClientDropdown = document.getElementById('lp-cliente-search-dropdown');
        if (lpClientInput) lpClientInput.value = '';
        if (lpClientClearBtn) lpClientClearBtn.classList.add('hidden');
        if (lpClientDropdown) lpClientDropdown.classList.add('hidden');
        loadLojaPerfeitaFilters(true);
        
        updateLojaPerfeitaView();
    }
};

// --- ESTRELAS VIEW LOGIC ---

// DOM Elements
const estrelasSupervisorFilterBtn = document.getElementById('estrelas-supervisor-filter-btn');
const estrelasSupervisorFilterDropdown = document.getElementById('estrelas-supervisor-filter-dropdown');
const estrelasVendedorFilterBtn = document.getElementById('estrelas-vendedor-filter-btn');
const estrelasVendedorFilterDropdown = document.getElementById('estrelas-vendedor-filter-dropdown');
const estrelasVendedorFilterList = document.getElementById('estrelas-vendedor-filter-list');
const estrelasVendedorFilterSearch = document.getElementById('estrelas-vendedor-filter-search');
const estrelasFornecedorFilterBtn = document.getElementById('estrelas-fornecedor-filter-btn');
const estrelasFornecedorFilterDropdown = document.getElementById('estrelas-fornecedor-filter-dropdown');
const estrelasFornecedorFilterList = document.getElementById('estrelas-fornecedor-filter-list');
const estrelasFornecedorFilterSearch = document.getElementById('estrelas-fornecedor-filter-search');
const estrelasCidadeFilterBtn = document.getElementById('estrelas-cidade-filter-btn');
const estrelasCidadeFilterDropdown = document.getElementById('estrelas-cidade-filter-dropdown');
const estrelasCidadeFilterList = document.getElementById('estrelas-cidade-filter-list');
const estrelasCidadeFilterSearch = document.getElementById('estrelas-cidade-filter-search');
const estrelasTipovendaFilterBtn = document.getElementById('estrelas-tipovenda-filter-btn');
const estrelasTipovendaFilterDropdown = document.getElementById('estrelas-tipovenda-filter-dropdown');
const estrelasRedeFilterBtn = document.getElementById('estrelas-rede-filter-btn');
const estrelasRedeFilterDropdown = document.getElementById('estrelas-rede-filter-dropdown');
const estrelasRedeFilterList = document.getElementById('estrelas-rede-filter-list');
const estrelasRedeFilterSearch = document.getElementById('estrelas-rede-filter-search');
const estrelasFilialFilterBtn = document.getElementById('estrelas-filial-filter-btn');
const estrelasFilialFilterDropdown = document.getElementById('estrelas-filial-filter-dropdown');
const estrelasCategoriaFilterBtn = document.getElementById('estrelas-categoria-filter-btn');
const estrelasCategoriaFilterDropdown = document.getElementById('estrelas-categoria-filter-dropdown');
const estrelasCategoriaFilterList = document.getElementById('estrelas-categoria-filter-list');
const estrelasCategoriaFilterSearch = document.getElementById('estrelas-categoria-filter-search');


const handleEstrelasFilterChange = () => {
    updateEstrelasView();
};

document.addEventListener('click', (e) => {
    const dropdowns = [
        estrelasSupervisorFilterDropdown, estrelasVendedorFilterDropdown,
        estrelasCidadeFilterDropdown, estrelasTipovendaFilterDropdown,
        estrelasRedeFilterDropdown, estrelasFilialFilterDropdown,
        estrelasCategoriaFilterDropdown, estrelasFornecedorFilterDropdown
    ];
    const btns = [
        estrelasSupervisorFilterBtn, estrelasVendedorFilterBtn,
        estrelasCidadeFilterBtn, estrelasTipovendaFilterBtn,
        estrelasRedeFilterBtn, estrelasFilialFilterBtn,
        estrelasCategoriaFilterBtn, estrelasFornecedorFilterBtn
    ];
    let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);

    const view = document.getElementById('estrelas-view');
    if (anyClosed && view && !view.classList.contains('hidden')) {
        handleEstrelasFilterChange();
    }
});


const setupEstrelasFilters = async () => {
    if (isEstrelasInitialized) return;


    const overlay = document.getElementById("dashboard-loading-overlay");

    const filters = {
        p_ano: null,
        p_mes: null,
        p_filial: [],
        p_cidade: [],
        p_supervisor: [],
        p_vendedor: [],
        p_fornecedor: [],
        p_tipovenda: [],
        p_rede: [],
        p_categoria: []
    };

    let filterData = null;
    try {
        const { data } = await supabase.rpc('get_dashboard_filters', filters);
        filterData = data;
    } catch (e) {
        AppLog.error(e);
    }

    if (!filterData) {
        if (overlay) overlay.classList.add('hidden');
        return;
    }

    // Load Ano and Mes
    const anoSelect = document.getElementById('estrelas-ano-filter');
    const mesSelect = document.getElementById('estrelas-mes-filter');

    // We assume fetchLastSalesDate logic is available globally (it is in app.js)
    if(typeof fetchLastSalesDate === 'function') await fetchLastSalesDate();
    const { currentYear, currentMonth } = getDefaultFilterDates(lastSalesDate);

    if (anoSelect && filterData.anos) {
        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        anoSelect.innerHTML = '<option value="todos">Todos</option>' + filterData.anos.map(ano => `<option value="${escapeHtml(ano)}">${escapeHtml(ano)}</option>`).join('');

        let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
        anoSelect.value = hasYear ? currentYear : 'todos';

        if(typeof window.enhanceSelectToCustomDropdown === 'function') window.enhanceSelectToCustomDropdown(anoSelect);
        anoSelect.addEventListener('change', handleEstrelasFilterChange);
    }

    if (mesSelect) {
        const meses = MONTHS_PT;
        // ⚡ Bolt Optimization: Use single innerHTML assignment instead of verbose document.createElement in loop
        mesSelect.innerHTML = '<option value="">Todos</option>' + meses.map((m, i) => `<option value="${String(i + 1).padStart(2, '0')}">${m}</option>`).join('');

        mesSelect.value = currentMonth;
        mesSelect.dispatchEvent(new Event('change', { bubbles: true }));

        if(typeof window.enhanceSelectToCustomDropdown === 'function') window.enhanceSelectToCustomDropdown(mesSelect);
        mesSelect.addEventListener('change', handleEstrelasFilterChange);
    }

    if(typeof setupCityMultiSelect === 'function') {
        setupCityMultiSelect(estrelasSupervisorFilterBtn, estrelasSupervisorFilterDropdown, estrelasSupervisorFilterDropdown, filterData.supervisors, estrelasSelectedSupervisors);
        setupCityMultiSelect(estrelasVendedorFilterBtn, estrelasVendedorFilterDropdown, estrelasVendedorFilterList, filterData.vendedores, estrelasSelectedVendedores, estrelasVendedorFilterSearch);
        setupCityMultiSelect(estrelasFornecedorFilterBtn, estrelasFornecedorFilterDropdown, estrelasFornecedorFilterList, filterData.fornecedores, estrelasSelectedFornecedores, estrelasFornecedorFilterSearch, true);
        setupCityMultiSelect(estrelasCidadeFilterBtn, estrelasCidadeFilterDropdown, estrelasCidadeFilterList, filterData.cidades, estrelasSelectedCidades, estrelasCidadeFilterSearch);
        setupCityMultiSelect(estrelasTipovendaFilterBtn, estrelasTipovendaFilterDropdown, estrelasTipovendaFilterDropdown, filterData.tipos_venda, estrelasSelectedTiposVenda);

        const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
        setupCityMultiSelect(estrelasRedeFilterBtn, estrelasRedeFilterDropdown, estrelasRedeFilterList, redes, estrelasSelectedRedes, estrelasRedeFilterSearch);

        setupCityMultiSelect(estrelasFilialFilterBtn, estrelasFilialFilterDropdown, estrelasFilialFilterDropdown, filterData.filiais, estrelasSelectedFiliais);
        setupCityMultiSelect(estrelasCategoriaFilterBtn, estrelasCategoriaFilterDropdown, estrelasCategoriaFilterList, filterData.categorias || [], estrelasSelectedCategorias, estrelasCategoriaFilterSearch);
    }

    if (overlay) overlay.classList.add('hidden');
    isEstrelasInitialized = true;
};

async function renderEstrelasView() {
    window.showDashboardLoading('estrelas-view');
    if (!isEstrelasInitialized) {
        await setupEstrelasFilters();
    }
    updateEstrelasView();
}

async function updateEstrelasView() {
    AppLog.log("Estrelas view updating...");
    
    // Show overlay handled by showDashboardLoading
    window.showDashboardLoading('estrelas-view');

    try {
        const filters = {
            p_ano: document.getElementById('estrelas-ano-filter')?.value === 'todos' ? null : document.getElementById('estrelas-ano-filter')?.value,
            p_mes: document.getElementById('estrelas-mes-filter')?.value === '' ? null : document.getElementById('estrelas-mes-filter')?.value,
            p_filial: (estrelasSelectedFiliais && estrelasSelectedFiliais.length) ? estrelasSelectedFiliais : null,
            p_cidade: (estrelasSelectedCidades && estrelasSelectedCidades.length) ? estrelasSelectedCidades : null,
            p_supervisor: (estrelasSelectedSupervisors && estrelasSelectedSupervisors.length) ? estrelasSelectedSupervisors : null,
            p_vendedor: (estrelasSelectedVendedores && estrelasSelectedVendedores.length) ? estrelasSelectedVendedores : null,
            p_fornecedor: (estrelasSelectedFornecedores && estrelasSelectedFornecedores.length) ? estrelasSelectedFornecedores : null,
            p_tipovenda: (estrelasSelectedTiposVenda && estrelasSelectedTiposVenda.length) ? estrelasSelectedTiposVenda : null,
            p_rede: (estrelasSelectedRedes && estrelasSelectedRedes.length) ? estrelasSelectedRedes : null,
            p_categoria: (estrelasSelectedCategorias && estrelasSelectedCategorias.length) ? estrelasSelectedCategorias : null
        };

        const { data, error } = await supabase.rpc('get_estrelas_kpis_data', filters);

        if (error) throw error;

        // --- Dynamic Metas ---
        const metaSelloutSalty = data.sellout_salty_meta || 0;
        const metaSelloutFoods = data.sellout_foods_meta || 0;
        const metaSellout = metaSelloutSalty + metaSelloutFoods;
        
        const metaPos = data.positivacao_meta || 0;
        const metaAcel = data.aceleradores_meta || 0;

        // Helper function to safely update DOM
        const updateEl = (id, val, isStyle = false) => {
            const el = document.getElementById(id);
            if (el) {
                if (isStyle) el.style.width = val;
                else el.textContent = val;
            }
        };

        // Update UI
        updateEl('sellout-meta-val', `${metaSellout.toFixed(2)} tons`);
        updateEl('sellout-meta-salty-val', `${metaSelloutSalty.toFixed(2)} tons`);
        updateEl('sellout-meta-foods-val', `${metaSelloutFoods.toFixed(2)} tons`);
        updateEl('sellout-realizado-val', `${data.sellout_salty + data.sellout_foods < 0.01 ? '0.00' : (data.sellout_salty + data.sellout_foods).toFixed(2)} tons`);
        updateEl('sellout-salty-val', `${data.sellout_salty < 0.01 ? '0.00' : data.sellout_salty.toFixed(2)} tons`);
        updateEl('sellout-foods-val', `${data.sellout_foods < 0.01 ? '0.00' : data.sellout_foods.toFixed(2)} tons`);
        
        // Remove old unused nodes safely if they exist in DOM (just in case they weren't removed from HTML)
        updateEl('pontos-possiveis-sellout', data.base_clientes);
        updateEl('pontos-parciais-sellout', 0);

        // Store the details globally for the modal
        estrelasDetailedData = data.detalhes || [];
        estrelasQtdMarcas = data.aceleradores_qtd_marcas || 0;

        updateEl('pos-meta-val', `${metaPos} PDV(s)`);
        updateEl('pos-realizado-salty-val', `${data.positivacao_salty} PDV(s)`);
        updateEl('pos-realizado-foods-val', `${data.positivacao_foods} PDV(s)`);
        updateEl('pontos-possiveis-pos', data.base_clientes);

        updateEl('acel-meta-val', metaAcel);
        updateEl('aceleradores-realizado-val', data.aceleradores_realizado);
        updateEl('aceleradores-parcial-val', data.aceleradores_parcial);
        updateEl('pontos-possiveis-acel', data.base_clientes);

        // Progress Bars
        let pctPos = data.base_clientes > 0 ? (data.positivacao_salty / data.base_clientes) * 100 : 0;
        let pctAcel = data.base_clientes > 0 ? (data.aceleradores_realizado / data.base_clientes) * 100 : 0;
        
        let realizedSellout = data.sellout_salty + data.sellout_foods;
        let pctSellout = metaSellout > 0 ? (realizedSellout / metaSellout) * 100 : (realizedSellout > 0 ? 100 : 0);

        updateEl('sellout-pdb-bar', `${Math.min(pctSellout, 100).toFixed(0)}%`, true);
        updateEl('sellout-pdb-pct', `${pctSellout.toFixed(0)}%`);

        updateEl('pos-salty-bar', `${Math.min(pctPos, 100).toFixed(0)}%`, true);
        updateEl('pos-salty-pct', `${pctPos.toFixed(0)}%`);

        updateEl('acel-batatas-bar', `${Math.min(pctAcel, 100).toFixed(0)}%`, true);
        updateEl('acel-batatas-pct', `${pctAcel.toFixed(0)}%`);

    } catch (err) {
        AppLog.error("Erro ao carregar dados de KPIs Estrelas:", err);
        // Optionally show a toast error
    } finally {
        window.hideDashboardLoading();
    }
}

});
async function loadFrequencyTable(filters) {
    const tableBody = document.getElementById('frequency-table-body');
    const tableFooter = document.getElementById('frequency-table-footer');
    if (!tableBody || !tableFooter) return;

    tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-slate-400 text-xs">Carregando Frequência...</td></tr>';

    const reqFilters = {
        p_filial: (filters.p_filial && filters.p_filial.length) ? filters.p_filial : null,
        p_cidade: (filters.p_cidade && filters.p_cidade.length) ? filters.p_cidade : null,
        p_supervisor: (filters.p_supervisor && filters.p_supervisor.length) ? filters.p_supervisor : null,
        p_vendedor: (filters.p_vendedor && filters.p_vendedor.length) ? filters.p_vendedor : null,
        p_fornecedor: (filters.p_fornecedor && filters.p_fornecedor.length) ? filters.p_fornecedor : null,
        p_ano: filters.p_ano || null,
        p_mes: filters.p_mes || null,
        p_tipovenda: (filters.p_tipovenda && filters.p_tipovenda.length) ? filters.p_tipovenda : null,
        p_rede: (filters.p_rede && filters.p_rede.length) ? filters.p_rede : null,
        p_produto: (filters.p_produto && filters.p_produto.length) ? filters.p_produto : null,
        p_categoria: (filters.p_categoria && filters.p_categoria.length) ? filters.p_categoria : null
    };

    try {
        const [freqResponse, mixResponse] = await Promise.all([
            supabase.rpc("get_frequency_table_data", reqFilters),
            supabase.rpc("get_mix_salty_foods_data", reqFilters)
        ]);

        if (freqResponse.error) throw freqResponse.error;
        if (mixResponse.error) throw mixResponse.error;

        renderFrequencyTable(freqResponse.data, tableBody, tableFooter);
        renderFrequencyChart(freqResponse.data);
        renderMixSaltyFoodsChart(mixResponse.data);

    } catch (err) {
        AppLog.error("Erro ao carregar tabela de frequência ou mix:", err);
        tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-red-500 text-xs">Erro ao carregar dados.</td></tr>';
    }
}

function renderFrequencyTable(data, tableBody, tableFooter) {
    tableBody.innerHTML = '';
    tableFooter.innerHTML = '';

    const treeData = data.tree_data || [];

    if (treeData.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-slate-400 text-xs">Nenhum dado encontrado</td></tr>';
        return;
    }

    // Build hierarchy using explicit ROLLUP grp_ flags from backend
    const hierarchy = {
        name: 'PRIME',
        children: {},
        totals: { tons: 0, faturamento: 0, faturamento_prev: 0, positivacao: 0, sum_skus: 0, total_pedidos: 0, avg_monthly_freq: 0, base_total: 0, clientsWithSales: 0 }
    };

    treeData.forEach(row => {
        const filial = row.filial || 'SEM FILIAL';
        const cidade = row.cidade || 'SEM CIDADE';
        const vendedor = row.vendedor || 'SEM VENDEDOR';

        const tons = row.tons || 0;
        const faturamento = row.faturamento || 0;
        const faturamento_prev = row.faturamento_prev || 0;
        const positivacao = row.positivacao || 0;
        const sum_skus = row.sum_skus || 0;
        const total_pedidos = row.total_pedidos || 0;
        const base_total = row.base_total || 0;
        const avg_monthly_freq = row.avg_monthly_freq || 0;
        const clientsWithSales = (faturamento > 0) ? positivacao : 0;

        const rowData = { tons, faturamento, faturamento_prev, positivacao, sum_skus, total_pedidos, avg_monthly_freq, base_total, clientsWithSales };

        // Rely strictly on ROLLUP flags
        if (row.grp_filial === 1) {
            hierarchy.totals = { ...rowData, base_total: rowData.base_total || 0, avg_monthly_freq: rowData.avg_monthly_freq || 0 };
            return;
        }
        if (row.grp_cidade === 1) {
            if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: rowData };
            else hierarchy.children[filial].totals = rowData;
            return;
        }
        if (row.grp_vendedor === 1) {
            if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
            if (!hierarchy.children[filial].children[cidade]) hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: rowData };
            else hierarchy.children[filial].children[cidade].totals = rowData;
            return;
        }

        // Leaf Node (grp_vendedor === 0)
        if (!hierarchy.children[filial]) hierarchy.children[filial] = { name: filial, children: {}, totals: {} };
        if (!hierarchy.children[filial].children[cidade]) hierarchy.children[filial].children[cidade] = { name: cidade, children: {}, totals: {} };
        
        hierarchy.children[filial].children[cidade].children[vendedor] = {
            name: vendedor,
            ...rowData
        };
    });

    let allRowsHtml = '';
    let rowCounter = 0;

    const createRow = (node, level, parentId = null) => {
        rowCounter++;
        const id = `node-${rowCounter}`;
        const hasChildren = node.children && Object.keys(node.children).length > 0;

        const isRoot = level === 0;
        const indentClass = level === 0 ? '' : (level === 1 ? 'pl-6' : (level === 2 ? 'pl-10' : 'pl-14'));

        const dataNode = isRoot ? node.totals : (hasChildren ? node.totals : node);

        const tons = (dataNode.tons || 0) / 1000;

        let varYago = 0;
        if (dataNode.faturamento_prev > 0) {
            varYago = ((dataNode.faturamento / dataNode.faturamento_prev) - 1) * 100;
        }

        const varYagoStr = (varYago > 0 ? '+' : '') + varYago.toFixed(1) + '%';
        const varYagoColor = varYago > 0 ? 'text-green-500' : (varYago < 0 ? 'text-red-500' : 'text-slate-400');
        const varYagoIcon = varYago > 0 ? '<svg class="w-4 h-4 text-green-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.707l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clip-rule="evenodd"></path></svg>' : (varYago < 0 ? '<svg class="w-4 h-4 text-red-500 inline mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.707 10.293a1 1 0 00-1.414 0l-3-3a1 1 0 101.414-1.414L9 14.586V11a1 1 0 10-2 0v3.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3z" clip-rule="evenodd"></path></svg>' : '');

        // SKU / PDV
        const skuPdv = dataNode.positivacao > 0 ? ((dataNode.sum_skus || 0) / dataNode.positivacao) : 0;

        // Frequencia
        const freq = dataNode.avg_monthly_freq || 0;

        // % Posit
        let percPosit = 0;
        if (dataNode.base_total > 0) {
            percPosit = ((dataNode.positivacao || 0) / dataNode.base_total) * 100;
        }
        if (percPosit > 100) percPosit = 100;

        const positStr = dataNode.positivacao || 0;
        const percPositStr = percPosit.toFixed(1) + '%';
        
        const rowHtml = `
            <tr class="hover:bg-white/5 transition-colors ${level > 0 ? 'hidden freq-child-row' : ''}" id="${id}" data-parent="${parentId}" data-level="${level}">
                <td class="px-2 py-2 border-b border-white/5 w-8 text-center cursor-pointer" onclick="toggleFreqNode('${id}')">
                    ${hasChildren ? '<svg id="icon-' + id + '" class="w-4 h-4 text-slate-400 inline transform transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>' : ''}
                </td>
                <td class="px-2 py-2 border-b border-white/5 font-medium ${indentClass}">${escapeHtml(node.name)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${tons.toFixed(1)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold ${varYagoColor}">${varYagoIcon} ${escapeHtml(varYagoStr)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${skuPdv.toFixed(2)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${freq.toFixed(2)}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${positStr}</td>
                <td class="px-2 py-2 border-b border-white/5 text-right font-bold">${percPositStr}</td>
            </tr>
        `;
        // ⚡ Bolt Optimization: Concatenate string to prevent layout thrashing and batch DOM updates
        allRowsHtml += rowHtml;

        if (hasChildren) {
            Object.values(node.children).forEach(child => createRow(child, level + 1, id));
        }

        return { tons, varYagoStr, varYagoColor, varYagoIcon, skuPdv, freq, positivacao: dataNode.positivacao || 0, percPosit };
    };

    const rootData = createRow(hierarchy, 0);

    // Render all rows at once
    tableBody.innerHTML = allRowsHtml;

    // Render footer (Totals - same as Root)
    tableFooter.innerHTML = `
        <tr>
            <td class="px-2 py-3 border-t border-white/20 w-8"></td>
            <td class="px-2 py-3 border-t border-white/20">Total</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${escapeHtml(rootData.tons.toFixed(1))}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right ${rootData.varYagoColor}">${rootData.varYagoIcon} ${escapeHtml(rootData.varYagoStr)}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${escapeHtml(rootData.skuPdv.toFixed(2))}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${escapeHtml(rootData.freq.toFixed(2))}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${escapeHtml(rootData.positivacao)}</td>
            <td class="px-2 py-3 border-t border-white/20 text-right">${escapeHtml(rootData.percPosit.toFixed(1))}%</td>
        </tr>
    `;
}

// Attach toggle function to window so onclick works
window.toggleFreqNode = function(id) {
    const icon = document.getElementById(`icon-${id}`);
    if (!icon) return;
    const path = icon.querySelector('path');
    const isExpanded = path && path.getAttribute('d') === 'M20 12H4'; // minus icon

    // Toggle icon
    if (isExpanded) {
        updateSvgPaths(icon, ['M12 6v6m0 0v6m0-6h6m-6 0H6']);
        hideChildren(id);
    } else {
        updateSvgPaths(icon, ['M20 12H4']);
        showDirectChildren(id);
    }
};

function showDirectChildren(parentId) {
    const rows = document.querySelectorAll(`tr[data-parent="${parentId}"]`);
    rows.forEach(row => {
        row.classList.remove('hidden');
    });
}

function hideChildren(parentId) {
    const rows = document.querySelectorAll(`tr[data-parent="${parentId}"]`);
    rows.forEach(row => {
        row.classList.add('hidden');
        const childIcon = document.getElementById(`icon-${row.id}`);
        if (childIcon) {
            const path = childIcon.querySelector('path');
            if (path && path.getAttribute('d') === 'M20 12H4') {
                // Collapse recursive
                updateSvgPaths(childIcon, ['M12 6v6m0 0v6m0-6h6m-6 0H6']);
            }
        }
        hideChildren(row.id);
    });
}

let frequencyChartInstance = null;
function renderFrequencyChart(data) {
    const ctx = document.getElementById('frequencyChartContainer');
    if (!ctx) return;

    // Clear existing
    ctx.innerHTML = '<canvas id="freqCanvas"></canvas>';
    const canvas = document.getElementById('freqCanvas');

    if (frequencyChartInstance) {
        frequencyChartInstance.destroy();
    }

    const chartData = data.chart_data || [];
    const currentYear = data.current_year;
    const previousYear = data.previous_year;

    document.getElementById('freq-chart-legend-curr').textContent = currentYear;
    document.getElementById('freq-chart-legend-prev').textContent = previousYear;

    const monthInitials = MONTHS_PT_INITIALS;

    const currDataArray = new Array(12).fill(null);
    const prevDataArray = new Array(12).fill(null);

    chartData.forEach(row => {
        const freq = row.total_clientes > 0 ? (row.total_pedidos / row.total_clientes) : null;
        if (row.ano == currentYear) {
            currDataArray[row.mes - 1] = freq ? parseFloat(freq.toFixed(2)) : null;
        } else if (row.ano == previousYear) {
            prevDataArray[row.mes - 1] = freq ? parseFloat(freq.toFixed(2)) : null;
        }
    });

    frequencyChartInstance = new Chart(canvas, {
        type: 'line',
        data: {
            labels: monthInitials,
            datasets: [
                {
                    label: previousYear.toString(),
                    data: prevDataArray,
                    borderColor: '#CBD5E1', // slate-300
                    backgroundColor: '#CBD5E1',
                    borderDash: [5, 5],
                    tension: 0.4,
                    borderWidth: 1.5,
                    pointRadius: 2.5,
                    pointBackgroundColor: '#CBD5E1',
                    spanGaps: true
                },
                {
                    label: currentYear.toString(),
                    data: currDataArray,
                    borderColor: '#1A73E8', // Blue
                    backgroundColor: '#1A73E8',
                    tension: 0.4,
                    borderWidth: 1.5,
                    pointRadius: 2.5,
                    pointBackgroundColor: '#1A73E8',
                    spanGaps: true
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    display: false // Use custom HTML legend
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    callbacks: {
                        label: function(context) {
                            let val = context.raw;
                            if (val !== null) {
                                return context.dataset.label + ': ' + val.toFixed(2);
                            }
                            return context.dataset.label + ': -';
                        }
                    }
                },
                datalabels: {
                    display: false
                }
            },
            scales: {
                x: {
                    grid: { display: false, drawBorder: false },
                    ticks: { color: '#94a3b8', font: { size: 10 } }
                },
                y: {
                    display: false, // hide Y axis
                    min: 0,
                    grace: '10%'
                }
            }
        }
    });
}

let mixSaltyFoodsChartInstance = null;

function renderMixSaltyFoodsChart(data) {
    const container = document.getElementById('mixSaltyFoodsChartContainer');
    if (!container) {
        AppLog.warn('Container mixSaltyFoodsChartContainer não encontrado.');
        return;
    }

    // Always clear the container first
    container.innerHTML = '<canvas id="mixSaltyFoodsCanvas"></canvas>';
    const canvas = document.getElementById('mixSaltyFoodsCanvas');
    if (!canvas) {
        AppLog.warn('Canvas mixSaltyFoodsCanvas não criado.');
        return;
    }

    if (mixSaltyFoodsChartInstance) {
        mixSaltyFoodsChartInstance.destroy();
    }

    const chartData = (data && data.chart_data) ? data.chart_data : [];
    AppLog.log("Renderizando Mix Salty & Foods Chart com dados:", chartData);

    const monthInitials = MONTHS_PT_INITIALS;
    const saltyData = new Array(12).fill(0);
    const foodsData = new Array(12).fill(0);
    const ambasData = new Array(12).fill(0);

    chartData.forEach(row => {
        const monthIndex = row.mes - 1;
        if (monthIndex >= 0 && monthIndex < 12) {
            saltyData[monthIndex] = (row.total_salty !== undefined && row.total_salty !== null) ? row.total_salty : 0;
            foodsData[monthIndex] = (row.total_foods !== undefined && row.total_foods !== null) ? row.total_foods : 0;
            ambasData[monthIndex] = (row.total_ambas !== undefined && row.total_ambas !== null) ? row.total_ambas : 0;
        }
    });

    const saltySum = saltyData.reduce((a, b) => a + b, 0);
    const foodsSum = foodsData.reduce((a, b) => a + b, 0);
    const ambasSum = ambasData.reduce((a, b) => a + b, 0);

    const datasets = [
        {
            label: 'Salty',
            data: saltyData,
            borderColor: '#F97316', // orange
            backgroundColor: 'rgba(249, 115, 22, 0.2)',
            tension: 0.4,
            borderWidth: 1.5,
            pointRadius: 2.5,
            pointBackgroundColor: '#F97316',
            fill: true,
            _sum: saltySum
        },
        {
            label: 'Foods',
            data: foodsData,
            borderColor: '#3B82F6', // blue
            backgroundColor: 'rgba(59, 130, 246, 0.2)',
            tension: 0.4,
            borderWidth: 1.5,
            pointRadius: 2.5,
            pointBackgroundColor: '#3B82F6',
            fill: true,
            _sum: foodsSum
        },
        {
            label: 'Ambas',
            data: ambasData,
            borderColor: '#A855F7', // purple
            backgroundColor: 'rgba(168, 85, 247, 0.2)',
            tension: 0.4,
            borderWidth: 1.5,
            pointRadius: 2.5,
            pointBackgroundColor: '#A855F7',
            fill: true,
            _sum: ambasSum
        }
    ];

    // Ordenar para desenhar primeiro os maiores volumes (atrás), depois os menores (na frente)
    datasets.sort((a, b) => b._sum - a._sum);

    mixSaltyFoodsChartInstance = new Chart(canvas, {
        type: 'line',
        data: {
            labels: monthInitials,
            datasets: datasets
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#cbd5e1',
                    borderColor: 'rgba(255,255,255,0.1)',
                    borderWidth: 1,
                    padding: 10,
                    displayColors: true
                },
                datalabels: {
                    display: false
                }
            },
            scales: {
                x: {
                    grid: { display: false, drawBorder: false },
                    ticks: { color: '#94a3b8', font: { size: 10 } }
                },
                y: {
                    display: false,
                    min: 0,
                    grace: '10%'
                }
            }
        }
    });
}

// ==========================================
// AGENDA VIEW LOGIC
// ==========================================
let isAgendaInitialized = false;
let agendaSelectedSupervisors = [];
let agendaSelectedRotas = [];

const handleAgendaFilterChange = () => {
    updateAgendaView();
};

const loadAgendaFilters = async () => {
    try {
        const { data: routeData, error } = await supabase
            .from('supervisors_routes')
            .select('supervisor, rota_dia, data_rota');
            
        if (error) throw error;
        
        // Populate Year
        const years = [...new Set(routeData.map(r => r.data_rota ? r.data_rota.substring(0,4) : null).filter(Boolean))].sort().reverse();
        const anoSelect = document.getElementById('agenda-ano-filter');
        if (anoSelect) {
            anoSelect.innerHTML = '<option value="todos" class="bg-slate-800 text-slate-200">Todos</option>';
            years.forEach(y => {
                const opt = document.createElement('option');
                opt.value = y;
                opt.textContent = y;
                opt.className = 'bg-slate-800 text-slate-200';
                // Set default to current year if exists
                if (y === new Date().getFullYear().toString()) {
                    opt.selected = true;
                }
                anoSelect.appendChild(opt);
            });
            if(typeof window.enhanceSelectToCustomDropdown === 'function') window.enhanceSelectToCustomDropdown(anoSelect);
            anoSelect.addEventListener('change', handleAgendaFilterChange);
        }
        
        // Select current month by default
        const mesSelect = document.getElementById('agenda-mes-filter');
        if (mesSelect) {
            mesSelect.value = (new Date().getMonth() + 1).toString();
            if(typeof window.enhanceSelectToCustomDropdown === 'function') window.enhanceSelectToCustomDropdown(mesSelect);
            mesSelect.addEventListener('change', handleAgendaFilterChange);
        }

        const supervisors = [...new Set(routeData.map(r => r.supervisor).filter(Boolean))].sort();
        const supBtn = document.getElementById('agenda-supervisor-filter-btn');
        const supDd = document.getElementById('agenda-supervisor-filter-dropdown');
        window.setupMultiSelect(supBtn, supDd, supDd, supervisors, agendaSelectedSupervisors, handleAgendaFilterChange);
        
        const rotas = [...new Set(routeData.map(r => r.rota_dia).filter(Boolean))].sort();
        const rotasBtn = document.getElementById('agenda-rota-filter-btn');
        const rotasDd = document.getElementById('agenda-rota-filter-dropdown');
        window.setupMultiSelect(rotasBtn, rotasDd, rotasDd, rotas, agendaSelectedRotas, handleAgendaFilterChange);

    } catch (err) {
        AppLog.error("Erro ao carregar filtros da Agenda:", err);
    }
};

const setupAgendaFilters = async () => {
    if (isAgendaInitialized) return;
    
    await loadAgendaFilters();

    // Clickaway setup - attach to document to capture outside clicks
    document.addEventListener('click', (e) => {
        const view = document.getElementById('agenda-view');
        if (!view || view.classList.contains('hidden')) return;

        const dropdowns = [
            document.getElementById('agenda-supervisor-filter-dropdown'),
            document.getElementById('agenda-rota-filter-dropdown')
        ];
        const btns = [
            document.getElementById('agenda-supervisor-filter-btn'),
            document.getElementById('agenda-rota-filter-btn')
        ];
        
        let anyClosed = handleDropdownsClickaway(e, dropdowns, btns);
        // Only update if something actually changed. But checkboxes fire their own change logic,
        // or rather the 'click' on the checkbox already mutates the selection array.
        // If we want to wait until the dropdown closes to apply filters, we'd need to compare
        // previous vs current state. But currently it causes flashes when clicking other inputs.
        // We will remove this automatic unconditional trigger. The filters should be applied
        // when actual selections change, or we can just let it be. Wait, the setupMultiSelect
        // already calls the callback (handleAgendaFilterChange) when a checkbox is clicked!
        // No need to trigger it on close.
    });

    isAgendaInitialized = true;
};

async function renderAgendaView() {
    window.showDashboardLoading('agenda-view');
    if (!isAgendaInitialized) {
        await setupAgendaFilters();
    }
    updateAgendaView();
}

async function updateAgendaView() {
    window.showDashboardLoading('agenda-view');
    
    try {
        let query = supabase.from('supervisors_routes').select('*').order('data_rota', { ascending: false });
        
        const ano = document.getElementById('agenda-ano-filter')?.value;
        if (ano && ano !== 'todos') {
            query = query.gte('data_rota', `${ano}-01-01`).lte('data_rota', `${ano}-12-31`);
        }
        
        const mesStr = document.getElementById('agenda-mes-filter')?.value;
        if (mesStr && mesStr !== 'todos') {
            const mesNum = parseInt(mesStr, 10);
            if (ano && ano !== 'todos') {
                const startDate = `${ano}-${mesNum.toString().padStart(2, '0')}-01`;
                const endDate = new Date(parseInt(ano), mesNum, 0).toISOString().split('T')[0];
                query = query.gte('data_rota', startDate).lte('data_rota', endDate);
            }
        }
        
        if (agendaSelectedSupervisors.length > 0) {
            query = query.in('supervisor', agendaSelectedSupervisors);
        }
        if (agendaSelectedRotas.length > 0) {
            query = query.in('rota_dia', agendaSelectedRotas);
        }
        
        const { data, error } = await query;
        if (error) throw error;
        
        // Calculate KPIs
        const totalDias = data.length;
        let preenchidos = 0;
        let foco = 0;
        
        data.forEach(r => {
            // Considerado preenchido se tiver rota_dia ou foco_dia preenchidos
            if ((r.rota_dia && r.rota_dia.trim() !== '') || (r.foco_dia && r.foco_dia.trim() !== '')) {
                preenchidos++;
            }
            if (r.foco_dia && r.foco_dia.trim() !== '') {
                foco++;
            }
        });
        
        const pendentes = totalDias - preenchidos;
        
        const calcPct = (val, total) => total > 0 ? Math.round((val / total) * 100) : 0;
        
        document.getElementById('agenda-kpi-total-dias').textContent = formatInteger(totalDias);
        document.getElementById('agenda-kpi-preenchidos').textContent = formatInteger(preenchidos);
        document.getElementById('agenda-kpi-preenchidos-pct').textContent = `${calcPct(preenchidos, totalDias)}%`;
        
        document.getElementById('agenda-kpi-pendentes').textContent = formatInteger(pendentes);
        document.getElementById('agenda-kpi-pendentes-pct').textContent = `${calcPct(pendentes, totalDias)}%`;
        
        document.getElementById('agenda-kpi-foco').textContent = formatInteger(foco);
        document.getElementById('agenda-kpi-foco-pct').textContent = `${calcPct(foco, totalDias)}%`;
        
        // Render Table
        const tbody = document.getElementById('agenda-table-body');
        if (!tbody) return;
        
        if (data.length === 0) {
            tbody.innerHTML = `<tr><td colspan="8" class="p-8 text-center text-slate-500">Nenhum dado encontrado para os filtros selecionados.</td></tr>`;
        } else {
            const getIconStatus = (isPreenchido) => {
                if (isPreenchido) {
                    return `<div class="flex items-center gap-1.5"><svg aria-hidden="true" class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg><span class="text-emerald-400 text-xs font-medium">OK</span></div>`;
                } else {
                    return `<div class="flex items-center gap-1.5"><svg aria-hidden="true" class="w-4 h-4 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg><span class="text-red-400 text-xs font-medium">Pendente</span></div>`;
                }
            };

            const formatDate = (dateStr) => {
                if (!dateStr) return '-';
                const parts = dateStr.split('-');
                if (parts.length === 3) {
                    return `${parts[2]}/${parts[1]}/${parts[0]}`;
                }
                return dateStr;
            };

            tbody.innerHTML = data.map(r => {
                const isPreenchido = (r.rota_dia && r.rota_dia.trim() !== '') || (r.foco_dia && r.foco_dia.trim() !== '');
                const eficiencias = [
                    r.eficiencia_visita ? `Visita: ${r.eficiencia_visita}` : null,
                    r.eficiencia_rota ? `Rota: ${r.eficiencia_rota}` : null,
                    r.eficiencia_saida ? `Saída: ${r.eficiencia_saida}` : null
                ].filter(Boolean).join(' | ');

                return `
                    <tr class="border-b border-white/5 hover:bg-white/5 transition-colors">
                        <td class="p-3 align-middle text-sm text-slate-300 whitespace-nowrap">${escapeHtml(formatDate(r.data_rota))}</td>
                        <td class="p-3 align-middle text-sm text-slate-400 capitalize">${escapeHtml(r.dia_semana || '-')}</td>
                        <td class="p-3 align-middle">${getIconStatus(isPreenchido)}</td>
                        <td class="p-3 align-middle text-sm font-medium text-white">${escapeHtml(r.supervisor || '-')}</td>
                        <td class="p-3 align-middle text-sm text-slate-300">
                            ${escapeHtml(r.acompanhado_dia_nome || '-')}
                            ${r.acompanhado_dia_codigo ? `<span class="text-xs text-slate-500 block">Cod: ${escapeHtml(r.acompanhado_dia_codigo)}</span>` : ''}
                        </td>
                        <td class="p-3 align-middle text-sm text-blue-400 font-medium">${escapeHtml(r.rota_dia || '-')}</td>
                        <td class="p-3 align-middle text-sm text-purple-400 max-w-xs" title="${escapeHtml(r.foco_dia || '')}">
                            <div class="line-clamp-2">${escapeHtml(r.foco_dia || '-')}</div>
                        </td>
                        <td class="p-3 align-middle text-xs text-slate-400 text-right max-w-[200px]" title="${escapeHtml(eficiencias)}">
                            <div class="truncate">${escapeHtml(eficiencias || '-')}</div>
                        </td>
                    </tr>
                `;
            }).join('');
        }

    } catch (err) {
        AppLog.error("Erro ao carregar dados da Agenda:", err);
    } finally {
        const overlay = document.getElementById('dashboard-loading-overlay');
        if (overlay) overlay.classList.add('hidden');
    }
}
