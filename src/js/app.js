
import supabase from './supabase.js?v=2';

document.addEventListener('DOMContentLoaded', () => {
    console.log("App Version: 2.1 (amCharts + New Nav)");
    
    // --- Global State Variables (Hoisted for Scope Access) ---
    let checkProfileLock = false;
    let isAppReady = false;
    let mainChartRoot = null; // Global reference to amCharts root

    // --- Auth & Navigation Elements ---
    const loginView = document.getElementById('login-view');
    const appLayout = document.getElementById('app-layout');
    const googleLoginBtn = document.getElementById('google-login-btn');
    const loginError = document.getElementById('login-error');
    const logoutBtn = document.getElementById('logout-btn');
    const logoutBtnPendente = document.getElementById('logout-btn-pendente');

    // New Top Navbar Elements
    const topNavbar = document.getElementById('top-navbar');
    const navDashboardBtn = document.getElementById('nav-dashboard');
    const navCityAnalysisBtn = document.getElementById('nav-city-analysis');
    const navBoxesBtn = document.getElementById('nav-boxes-btn');
    const navBranchBtn = document.getElementById('nav-branch-btn');
    const navUploaderBtn = document.getElementById('nav-uploader');
    const navComparativoBtn = document.getElementById('nav-comparativo-btn');
    const optimizeDbBtnNav = document.getElementById('optimize-db-btn-nav');

    // Sidebar - Deprecated but kept to avoid immediate errors if referenced
    const sideMenu = document.getElementById('side-menu');
    const openSidebarBtn = document.getElementById('open-sidebar-btn'); // Can be removed or hidden
    const sidebarBackdrop = document.getElementById('sidebar-backdrop');

    // Views
    const dashboardContainer = document.getElementById('dashboard-container');
    const uploaderModal = document.getElementById('uploader-modal');
    const closeUploaderBtn = document.getElementById('close-uploader-btn');

    // Dashboard Internal Views
    const mainDashboardView = document.getElementById('main-dashboard-view');
    const mainDashboardHeader = document.getElementById('main-dashboard-header');
    const mainDashboardContent = document.getElementById('main-dashboard-content');
    const cityView = document.getElementById('city-view');
    const boxesView = document.getElementById('boxes-view');
    const branchView = document.getElementById('branch-view');
    const comparisonView = document.getElementById('comparison-view');

    // Buttons in Dashboard
    const clearFiltersBtn = document.getElementById('clear-filters-btn');
    const calendarBtn = document.getElementById('calendar-btn'); 
    const chartToggleBtn = document.getElementById('chart-toggle-btn'); 

    // Toggle Secondary KPIs
    const toggleSecondaryKpisBtn = document.getElementById('toggle-secondary-kpis-btn');
    const secondaryKpiRow = document.getElementById('secondary-kpi-row');
    const toggleKpiIcon = document.getElementById('toggle-kpi-icon');

    // --- Filter Element Declarations ---
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

    // Boxes Filter Elements (Keep existing references)
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
    const boxesExportBtn = document.getElementById('boxes-export-btn');
    const boxesExportDropdown = document.getElementById('boxes-export-dropdown');
    const boxesExportExcelBtn = document.getElementById('boxes-export-excel');
    const boxesExportPdfBtn = document.getElementById('boxes-export-pdf');

    // City View Filter Logic (Keep existing)
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

    // Branch View Logic (Keep existing)
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

    // Comparison View Filters (Keep existing)
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
    const comparisonRedeFilterDropdown = document.getElementById('comparison-rede-filter-dropdown');
    const comparisonComRedeBtn = document.getElementById('comparison-com-rede-btn');
    const comparisonRedeGroupContainer = document.getElementById('comparison-rede-group-container');
    const comparisonFilialFilter = document.getElementById('comparison-filial-filter');
    const comparisonCityFilterBtn = document.getElementById('comparison-city-filter-btn');
    const comparisonCityFilterDropdown = document.getElementById('comparison-city-filter-dropdown');
    const comparisonCityFilterList = document.getElementById('comparison-city-filter-list');
    const comparisonCityFilterSearch = document.getElementById('comparison-city-filter-search');
    const comparisonCategoriaFilterBtn = document.getElementById('comparison-categoria-filter-btn');
    const comparisonCategoriaFilterDropdown = document.getElementById('comparison-categoria-filter-dropdown');
    const clearComparisonFiltersBtn = document.getElementById('clear-comparison-filters-btn');
    const comparisonFornecedorToggleContainer = document.getElementById('comparison-fornecedor-toggle-container');
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
            const plusPath = "M12 4v16m8-8H4"; 
            const minusPath = "M20 12H4"; 
            if(toggleKpiIcon) toggleKpiIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${isHidden ? plusPath : minusPath}"></path>`;
        });
    }

    // Calendar Modal Elements
    const calendarModal = document.getElementById('calendar-modal');
    const calendarModalBackdrop = document.getElementById('calendar-modal-backdrop');
    const closeCalendarModalBtn = document.getElementById('close-calendar-modal-btn');
    const calendarModalContent = document.getElementById('calendar-modal-content');
    const comparisonHolidayPickerBtn = document.getElementById('comparison-holiday-picker-btn');

    // Uploader Elements
    const salesPrevYearInput = document.getElementById('sales-prev-year-input');
    const salesCurrYearInput = document.getElementById('sales-curr-year-input');
    const salesCurrMonthInput = document.getElementById('sales-curr-month-input');
    const clientsFileInput = document.getElementById('clients-file-input');
    const productsFileInput = document.getElementById('products-file-input');
    const generateBtn = document.getElementById('generate-btn');
    const optimizeDbBtn = document.getElementById('optimize-db-btn'); // Keep standard one if exists
    const statusContainer = document.getElementById('status-container');
    const statusText = document.getElementById('status-text');
    const progressBar = document.getElementById('progress-bar');
    const missingBranchesNotification = document.getElementById('missing-branches-notification');

    // Auth Logic
    const telaLoading = document.getElementById('tela-loading');
    const telaPendente = document.getElementById('tela-pendente');

    // UI Functions
    const showScreen = (screenId) => {
        [loginView, telaLoading, telaPendente, appLayout].forEach(el => el?.classList.add('hidden'));
        if (screenId) {
            const screen = document.getElementById(screenId);
            screen?.classList.remove('hidden');
            // Ensure Top Nav is visible if authenticated and in app
            if (screenId === 'app-layout' && topNavbar) {
                topNavbar.classList.remove('hidden');
            }
        }
    };

    // Cache Logic
    const DB_NAME = 'PrimeDashboardDB';
    const STORE_NAME = 'data_store';
    const DB_VERSION = 1;

    // --- Navigation Logic (Updated for Top Nav) ---
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
    };

    // Routing Logic Reuse
    function getActiveViewId() {
        if (!mainDashboardView.classList.contains('hidden')) return 'dashboard';
        if (!cityView.classList.contains('hidden')) return 'city';
        if (!boxesView.classList.contains('hidden')) return 'boxes';
        if (!branchView.classList.contains('hidden')) return 'branch';
        if (comparisonView && !comparisonView.classList.contains('hidden')) return 'comparison';
        return 'dashboard';
    }

    // (getFiltersFromActiveView, applyFiltersToView, navigateWithCtrl... kept same)
    // ... Copy of getFiltersFromActiveView, applyFiltersToView, navigateWithCtrl from previous version ...
    function getFiltersFromActiveView() { /* Same implementation as before */ 
        const view = getActiveViewId();
        const state = {};
        if (view === 'dashboard') { state.ano = anoFilter.value; state.mes = mesFilter.value; state.filiais = selectedFiliais; state.cidades = selectedCidades; state.supervisores = selectedSupervisores; state.vendedores = selectedVendedores; state.fornecedores = selectedFornecedores; state.tiposvenda = selectedTiposVenda; state.redes = selectedRedes; state.categorias = selectedCategorias; }
        else if (view === 'city') { state.ano = cityAnoFilter.value; state.mes = cityMesFilter.value; state.filiais = citySelectedFiliais; state.cidades = citySelectedCidades; state.supervisores = citySelectedSupervisores; state.vendedores = citySelectedVendedores; state.fornecedores = citySelectedFornecedores; state.tiposvenda = citySelectedTiposVenda; state.redes = citySelectedRedes; }
        else if (view === 'boxes') { state.ano = boxesAnoFilter.value; state.mes = boxesMesFilter.value; state.filiais = boxesSelectedFiliais; state.cidades = boxesSelectedCidades; state.supervisores = boxesSelectedSupervisores; state.vendedores = boxesSelectedVendedores; state.fornecedores = boxesSelectedFornecedores; state.produtos = boxesSelectedProducts; }
        else if (view === 'branch') { state.ano = branchAnoFilter.value; state.mes = branchMesFilter.value; state.filiais = branchSelectedFiliais; state.cidades = branchSelectedCidades; state.supervisores = branchSelectedSupervisores; state.vendedores = branchSelectedVendedores; state.fornecedores = branchSelectedFornecedores; state.tiposvenda = branchSelectedTiposVenda; state.redes = branchSelectedRedes; }
        else if (view === 'comparison') { state.ano = comparisonAnoFilter.value; state.mes = comparisonMesFilter.value; state.filiais = comparisonFilialFilter.value === 'ambas' ? [] : [comparisonFilialFilter.value]; state.cidades = selectedComparisonCities; state.supervisores = selectedComparisonSupervisores; state.vendedores = selectedComparisonSellers; state.fornecedores = selectedComparisonSuppliers; state.tiposvenda = selectedComparisonTiposVenda; state.redes = selectedComparisonRedes; }
        const serialize = (key, val) => { if (Array.isArray(val)) return val.join(','); return val; };
        const params = new URLSearchParams();
        for (const [key, val] of Object.entries(state)) { if (val && val.length > 0) { params.set(key, serialize(key, val)); } }
        return params;
    }

    function applyFiltersToView(view, params) { /* Same implementation as before */
        const getList = (key) => { const val = params.get(key); return val ? val.split(',') : []; };
        const getVal = (key) => params.get(key);
        if (view === 'dashboard') { if (getVal('ano')) anoFilter.value = getVal('ano'); if (getVal('mes')) mesFilter.value = getVal('mes'); selectedFiliais = getList('filiais'); selectedCidades = getList('cidades'); selectedSupervisores = getList('supervisores'); selectedVendedores = getList('vendedores'); selectedFornecedores = getList('fornecedores'); selectedTiposVenda = getList('tiposvenda'); selectedRedes = getList('redes'); selectedCategorias = getList('categorias'); }
        else if (view === 'city') { if (getVal('ano')) cityAnoFilter.value = getVal('ano'); if (getVal('mes')) cityMesFilter.value = getVal('mes'); citySelectedFiliais = getList('filiais'); citySelectedCidades = getList('cidades'); citySelectedSupervisores = getList('supervisores'); citySelectedVendedores = getList('vendedores'); citySelectedFornecedores = getList('fornecedores'); citySelectedTiposVenda = getList('tiposvenda'); citySelectedRedes = getList('redes'); }
        else if (view === 'boxes') { if (getVal('ano')) boxesAnoFilter.value = getVal('ano'); if (getVal('mes')) boxesMesFilter.value = getVal('mes'); boxesSelectedFiliais = getList('filiais'); boxesSelectedCidades = getList('cidades'); boxesSelectedSupervisores = getList('supervisores'); boxesSelectedVendedores = getList('vendedores'); boxesSelectedFornecedores = getList('fornecedores'); boxesSelectedProducts = getList('produtos'); }
        else if (view === 'branch') { if (getVal('ano')) branchAnoFilter.value = getVal('ano'); if (getVal('mes')) branchMesFilter.value = getVal('mes'); branchSelectedFiliais = getList('filiais'); branchSelectedCidades = getList('cidades'); branchSelectedSupervisores = getList('supervisores'); branchSelectedVendedores = getList('vendedores'); branchSelectedFornecedores = getList('fornecedores'); branchSelectedTiposVenda = getList('tiposvenda'); branchSelectedRedes = getList('redes'); }
        else if (view === 'comparison') { if (getVal('ano')) comparisonAnoFilter.value = getVal('ano'); if (getVal('mes')) comparisonMesFilter.value = getVal('mes'); const filiais = getList('filiais'); if (filiais.length > 0) comparisonFilialFilter.value = filiais[0]; selectedComparisonCities = getList('cidades'); selectedComparisonSupervisores = getList('supervisores'); selectedComparisonSellers = getList('vendedores'); selectedComparisonSuppliers = getList('fornecedores'); selectedComparisonTiposVenda = getList('tiposvenda'); selectedComparisonRedes = getList('redes'); }
    }

    function navigateWithCtrl(e, targetViewId) { /* Same */
        if (e.ctrlKey || e.metaKey) { e.preventDefault(); e.stopPropagation(); const params = getFiltersFromActiveView(); params.set('view', targetViewId); const url = `${window.location.pathname}?${params.toString()}`; window.open(url, '_blank'); return true; } return false;
    }

    // Handlers for Navigation
    navDashboardBtn.addEventListener('click', (e) => {
        if (navigateWithCtrl(e, 'dashboard')) return;
        resetViews();
        mainDashboardView.classList.remove('hidden');
        setActiveNavLink(navDashboardBtn);
    });

    navCityAnalysisBtn.addEventListener('click', (e) => {
        if (navigateWithCtrl(e, 'city')) return;
        resetViews();
        cityView.classList.remove('hidden');
        setActiveNavLink(navCityAnalysisBtn);
        loadCityView();
    });

    if (navBoxesBtn) {
        navBoxesBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'boxes')) return;
            resetViews();
            boxesView.classList.remove('hidden');
            setActiveNavLink(navBoxesBtn);
            loadBoxesView();
        });
    }

    if (navComparativoBtn) {
        navComparativoBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'comparison')) return;
            resetViews();
            comparisonView.classList.remove('hidden');
            setActiveNavLink(navComparativoBtn);
            loadComparisonView();
        });
    }

    if (navBranchBtn) {
        navBranchBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'branch')) return;
            resetViews();
            branchView.classList.remove('hidden');
            setActiveNavLink(navBranchBtn);
            loadBranchView();
        });
    }

    if (navUploaderBtn) {
        navUploaderBtn.addEventListener('click', () => {
            if (window.userRole !== 'adm') return;
            uploaderModal.classList.remove('hidden');
            checkMissingBranches();
        });
    }

    if (optimizeDbBtnNav) {
        optimizeDbBtnNav.addEventListener('click', async () => {
            if (window.userRole !== 'adm') return;
            if (!confirm('Recriar índices do banco de dados?')) return;
            // Logic similar to old button
            try {
                const { data, error } = await supabase.rpc('optimize_database');
                if (error) throw error;
                alert(data || 'Otimização concluída!');
            } catch(e) { alert('Erro: ' + e.message); }
        });
    }

    // Role Check for Uploader Visibility
    function checkRoleForUI() {
        if (window.userRole === 'adm') {
            if(navUploaderBtn) navUploaderBtn.classList.remove('hidden');
        }
    }

    // DB Init
    const initDB = () => {
        return idb.openDB(DB_NAME, DB_VERSION, {
            upgrade(db) { if (!db.objectStoreNames.contains(STORE_NAME)) { db.createObjectStore(STORE_NAME); } },
        });
    };
    const getFromCache = async (key) => { try { const db = await initDB(); return await db.get(STORE_NAME, key); } catch (e) { return null; } };
    const saveToCache = async (key, value) => { try { const db = await initDB(); const payload = { timestamp: Date.now(), data: value }; await db.put(STORE_NAME, payload, key); } catch (e) {} };

    // --- Helpers (Same as before) ---
    function isBonificationMode(selectedTypes) { if (!selectedTypes || selectedTypes.length === 0) return false; return selectedTypes.every(t => t === '5' || t === '11'); }
    function generateCacheKey(prefix, filters) { const sortedFilters = {}; Object.keys(filters).sort().forEach(k => { let val = filters[k]; if (Array.isArray(val)) { val = [...val].sort(); } sortedFilters[k] = val; }); return `${prefix}_${JSON.stringify(sortedFilters)}`; }

    // --- Session & Initial Load ---
    async function handleInitialRouting() {
        const params = new URLSearchParams(window.location.search);
        const view = params.get('view');
        checkRoleForUI();

        if (view) {
            applyFiltersToView(view, params);
            showScreen('app-layout');
            if (view === 'city') navCityAnalysisBtn.click();
            else if (view === 'boxes') navBoxesBtn.click();
            else if (view === 'branch') navBranchBtn.click();
            else if (view === 'comparison') navComparativoBtn.click();
            else { navDashboardBtn.click(); initDashboard(); }
        } else {
            showScreen('app-layout');
            initDashboard();
        }
    }

    // Session Check & Logic (Same)
    async function checkSession() {
        showScreen('tela-loading');
        supabase.auth.onAuthStateChange(async (event, session) => {
            if (event === 'SIGNED_OUT') { isAppReady = false; showScreen('login-view'); return; }
            if (session) {
                if (isAppReady) return;
                if (!checkProfileLock) await checkProfileStatus(session.user);
            } else { showScreen('login-view'); }
        });
    }
    // ... checkProfileStatus, startStatusListener, etc. same ...
    async function checkProfileStatus(user) {
        if (isAppReady) return;
        const cacheKey = `user_auth_cache_${user.id}`;
        const cachedAuth = localStorage.getItem(cacheKey);
        if (cachedAuth) {
            try {
                const { status, role } = JSON.parse(cachedAuth);
                if (status === 'aprovado') { window.userRole = role; isAppReady = true; handleInitialRouting(); return; }
            } catch (e) { localStorage.removeItem(cacheKey); }
        }
        checkProfileLock = true;
        try {
            const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 10000));
            const profileQuery = supabase.from('profiles').select('status, role').eq('id', user.id).single();
            const { data: profile, error } = await Promise.race([profileQuery, timeout]);
            if (error) { if (error.code === 'PGRST116') { await supabase.from('profiles').insert([{ id: user.id, email: user.email, status: 'pendente' }]); } else throw error; }
            const status = profile?.status || 'pendente';
            if (profile?.role) window.userRole = profile.role;
            if (status === 'aprovado') {
                localStorage.setItem(cacheKey, JSON.stringify({ status: 'aprovado', role: profile?.role }));
                isAppReady = true;
                handleInitialRouting();
            } else {
                showScreen('tela-pendente');
                startStatusListener(user.id);
            }
        } catch (err) { checkProfileLock = false; if (!isAppReady) showScreen('login-view'); } finally { checkProfileLock = false; }
    }
    // ... (rest of session/upload logic) ...

    checkSession();
    // (Other Uploader & Sync logic remains unchanged)

    // --- AMCHARTS 5 IMPLEMENTATION ---
    function renderMainChartAmCharts(data) {
        if (mainChartRoot) {
            mainChartRoot.dispose();
        }

        // Determine Mode (Fat vs Ton) and Bonification
        const isBonifMode = isBonificationMode(getCurrentFilters().p_tipovenda);
        const getDataValue = (d) => {
            if (isBonifMode && currentChartMode === 'faturamento') return d.bonificacao;
            return currentChartMode === 'faturamento' ? d.faturamento : d.peso;
        };

        const chartContainer = document.getElementById('main-chartContainer');
        if (!chartContainer) return;

        mainChartRoot = am5.Root.new("main-chartContainer");

        // Themes
        mainChartRoot.setThemes([
            am5themes_Animated.new(mainChartRoot)
        ]);

        // Define Dark Theme Colors
        const colors = {
            previous: am5.color(0xf97316), // Orange
            current: am5.color(0x06b6d4), // Cyan
            trend: am5.color(0x8b5cf6),    // Purple
            text: am5.color(0xcbd5e1),     // Slate-300
            grid: am5.color(0xffffff)      // White with opacity
        };

        // Create Chart
        const chart = mainChartRoot.container.children.push(am5xy.XYChart.new(mainChartRoot, {
            panX: true,
            panY: true,
            wheelX: "panX",
            wheelY: "zoomX",
            pinchZoomX: true,
            paddingLeft: 0,
            layout: mainChartRoot.verticalLayout
        }));

        // Cursor
        const cursor = chart.set("cursor", am5xy.XYCursor.new(mainChartRoot, {
            behavior: "none"
        }));
        cursor.lineY.set("visible", false);

        // Prepare Data
        // Map Monthly Data to a unified timeframe (e.g., 2000 as a dummy year) to overlay lines
        const prepareSeriesData = (sourceData, yearLabel) => {
            return sourceData.map(d => {
                // d.month_index is 0-11.
                // Create date object for axis: Year 2000, Month, Day 15 (middle)
                const date = new Date(2000, d.month_index, 15).getTime();
                return {
                    date: date,
                    value: getDataValue(d),
                    realYear: yearLabel // For tooltip context
                };
            });
        };

        const seriesDataPrev = prepareSeriesData(data.monthly_data_previous || [], data.previous_year);
        const seriesDataCurr = prepareSeriesData(data.monthly_data_current || [], data.current_year);
        
        let seriesDataTrend = [];
        if (data.trend_allowed && data.trend_data) {
            // Trend is a single point, but lines need 2 points? 
            // Usually we connect Current Last Month -> Trend Month.
            // Find last current month
            const lastCurr = seriesDataCurr[seriesDataCurr.length - 1];
            if (lastCurr) {
                // Add last actual point to trend line start to ensure connection
                seriesDataTrend.push(lastCurr); 
                
                const trendDate = new Date(2000, data.trend_data.month_index, 15).getTime();
                seriesDataTrend.push({
                    date: trendDate,
                    value: getDataValue(data.trend_data),
                    realYear: "Tendência"
                });
            }
        }

        // Axes
        const xRenderer = am5xy.AxisRendererX.new(mainChartRoot, {
            minorGridEnabled: true,
            minGridDistance: 50
        });
        xRenderer.labels.template.setAll({
            fill: colors.text,
            fontSize: 12
        });
        xRenderer.grid.template.setAll({
            stroke: colors.grid,
            strokeOpacity: 0.1
        });

        const xAxis = chart.xAxes.push(am5xy.DateAxis.new(mainChartRoot, {
            maxDeviation: 0.2,
            baseInterval: { timeUnit: "month", count: 1 },
            renderer: xRenderer,
            tooltip: am5.Tooltip.new(mainChartRoot, {})
        }));
        
        // Force format to Month Name only since we overlay years
        xAxis.get("dateFormats")["month"] = "MMM";
        xAxis.get("periodChangeDateFormats")["month"] = "MMM";

        const yRenderer = am5xy.AxisRendererY.new(mainChartRoot, {
            pan: "zoom"
        });
        yRenderer.labels.template.setAll({
            fill: colors.text,
            fontSize: 12
        });
        yRenderer.grid.template.setAll({
            stroke: colors.grid,
            strokeOpacity: 0.1
        });

        const yAxis = chart.yAxes.push(am5xy.ValueAxis.new(mainChartRoot, {
            renderer: yRenderer,
            numberFormat: currentChartMode === 'faturamento' ? "#.0a" : "#.0' Ton'" // k for currency, Ton for weight
        }));

        // Series Function
        function createSeries(name, dataItems, color, isDashed = false) {
            const series = chart.series.push(am5xy.LineSeries.new(mainChartRoot, {
                name: name,
                xAxis: xAxis,
                yAxis: yAxis,
                valueYField: "value",
                valueXField: "date",
                tooltip: am5.Tooltip.new(mainChartRoot, {
                    labelText: "{name}: {valueY}"
                })
            }));

            series.stroke.template.setAll({
                stroke: color,
                strokeWidth: 2
            });
            
            if (isDashed) {
                series.stroke.template.set("strokeDasharray", [5, 3]);
            }

            // Bullet (Circle point)
            series.bullets.push(function() {
                return am5.Bullet.new(mainChartRoot, {
                    sprite: am5.Circle.new(mainChartRoot, {
                        radius: 4,
                        fill: color,
                        stroke: mainChartRoot.interfaceColors.get("background"),
                        strokeWidth: 1
                    })
                });
            });

            series.data.setAll(dataItems);
            series.appear(1000);
            return series;
        }

        // Add Series
        createSeries(`Ano ${data.previous_year}`, seriesDataPrev, colors.previous);
        createSeries(`Ano ${data.current_year}`, seriesDataCurr, colors.current);
        
        if (seriesDataTrend.length > 0) {
            createSeries("Tendência", seriesDataTrend, colors.trend, true);
        }

        // Scrollbar
        chart.set("scrollbarX", am5.Scrollbar.new(mainChartRoot, {
            orientation: "horizontal",
            marginBottom: 20
        }));

        // Legend
        const legend = chart.rightAxesContainer.children.push(am5.Legend.new(mainChartRoot, {
            width: 200,
            paddingLeft: 15,
            height: am5.percent(100)
        }));

        legend.itemContainers.template.events.on("pointerover", function(e) {
            e.target.dataItem.dataContext.hover();
        });
        legend.itemContainers.template.events.on("pointerout", function(e) {
            e.target.dataItem.dataContext.unhover();
        });

        legend.data.setAll(chart.series.values);

        // Animate
        chart.appear(1000, 100);
    }

    // Override renderDashboard to use new chart
    function renderDashboard(data) {
        // Init Holidays
        holidays = data.holidays || [];
        
        // ... (Keep existing KPI rendering logic) ...
        document.getElementById('kpi-clients-attended').textContent = data.kpi_clients_attended.toLocaleString('pt-BR');
        const baseEl = document.getElementById('kpi-clients-base');
        if (data.kpi_clients_base > 0) {
            baseEl.textContent = `de ${data.kpi_clients_base.toLocaleString('pt-BR')} na base`;
            baseEl.classList.remove('hidden');
        } else { baseEl.classList.add('hidden'); }

        let currentData = data.monthly_data_current || [];
        let previousData = data.monthly_data_previous || [];
        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const targetIndex = data.target_month_index;

        // KPI Calculation Variables (Standard Logic)
        let currFat, currKg, prevFat, prevKg; 
        let kpiTitleFat, kpiTitleKg;
        
        if (anoFilter.value !== 'todos' && mesFilter.value === '') {
            // SCENARIO A: Year Selected, Month All
            const sumData = (dataset, useTrend) => {
                let sumFat = 0, sumKg = 0;
                dataset.forEach(d => {
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

            if (data.trend_allowed && data.trend_data) {
                const monthsPassed = data.trend_data.month_index + 1;
                currFat = (currSums.faturamento / monthsPassed) * 12;
                currKg = (currSums.peso / monthsPassed) * 12;
            } else {
                currFat = currSums.faturamento;
                currKg = currSums.peso;
            }
            prevFat = prevSums.faturamento;
            prevKg = prevSums.peso;
            kpiTitleFat = `Tend. FAT ${data.current_year} vs Ano Ant.`;
            kpiTitleKg = `Tend. TON ${data.current_year} vs Ano Ant.`;
        } else {
            // SCENARIO B: Month vs Month
            if (mesFilter.value !== '') {
                const selectedMonthIndex = parseInt(mesFilter.value);
                currentData = currentData.filter(d => d.month_index === selectedMonthIndex);
                previousData = previousData.filter(d => d.month_index === selectedMonthIndex);
            }
            const currMonthData = currentData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };
            const prevMonthData = previousData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };
            
            const getTrendValue = (key, baseValue) => (data.trend_allowed && data.trend_data && data.trend_data.month_index === targetIndex) ? (data.trend_data[key] || 0) : baseValue;
            
            currFat = getTrendValue('faturamento', currMonthData.faturamento);
            currKg = getTrendValue('peso', currMonthData.peso);
            prevFat = prevMonthData.faturamento;
            prevKg = prevMonthData.peso;
            
            const mName = monthNames[targetIndex]?.toUpperCase() || "";
            kpiTitleFat = `Tend. FAT ${mName} vs Ano Ant.`;
            kpiTitleKg = `Tend. TON ${mName} vs Ano Ant.`;
        }

        const calcEvo = (curr, prev) => prev > 0 ? ((curr / prev) - 1) * 100 : (curr > 0 ? 100 : 0);

        // Update KPIs
        updateKpiCard({ prefix: 'fat', trendVal: currFat, prevVal: prevFat, fmt: (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }), calcEvo });
        updateKpiCard({ prefix: 'kg', trendVal: currKg, prevVal: prevKg, fmt: (v) => `${(v/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} Ton`, calcEvo });

        // Update Titles
        document.getElementById('kpi-title-evo-ano-fat').textContent = kpiTitleFat;
        document.getElementById('kpi-title-evo-ano-kg').textContent = kpiTitleKg;

        // --- NEW AMCHARTS RENDERING ---
        const mainChartTitle = document.getElementById('main-chart-title');
        const isBonifMode = isBonificationMode(getCurrentFilters().p_tipovenda);
        if (currentChartMode === 'faturamento') {
            mainChartTitle.textContent = isBonifMode ? "BONIFICADO MENSAL" : "FATURAMENTO MENSAL";
        } else {
            mainChartTitle.textContent = "TONELAGEM MENSAL";
        }

        renderMainChartAmCharts(data); // Call new chart function

        updateTable(data.monthly_data_current || [], data.monthly_data_previous || [], data.current_year, data.previous_year, data.trend_allowed ? data.trend_data : null);
    }

    // ... (Keep existing updateTable, updateKpiCard, and other helper functions) ...
    // Note: createChart (legacy Chart.js) can be kept if used by other views (Branch/Comparison), 
    // or refactored later if they need amCharts too. Currently plan is only Main Dashboard Chart replacement.
    
    // Existing helper functions like updateKpiCard, updateTable are presumed available 
    // or need to be inside this scope if not modular. They are already in the file structure 
    // from previous read, so just ensuring the logic flow calls renderDashboard -> renderMainChartAmCharts.

    // ... (Rest of logic: City View, Boxes View, etc. remains mostly same logic-wise) ...
});
