
import supabase from './supabase.js?v=2';

document.addEventListener('DOMContentLoaded', () => {
    console.log("App Version: 2.0 (Cache Refresh Split)");
    // --- Auth & Navigation Elements ---
    const loginView = document.getElementById('login-view');
    const appLayout = document.getElementById('app-layout');
    const googleLoginBtn = document.getElementById('google-login-btn');
    const loginError = document.getElementById('login-error');
    const logoutBtn = document.getElementById('logout-btn');
    const logoutBtnPendente = document.getElementById('logout-btn-pendente');

    // Sidebar
    const sideMenu = document.getElementById('side-menu');
    const openSidebarBtn = document.getElementById('open-sidebar-btn'); // Main Header Hamburger
    const openSidebarBoxesBtn = document.getElementById('open-sidebar-boxes-btn'); // Boxes Header Hamburger
    const openSidebarBranchBtn = document.getElementById('open-sidebar-branch-btn'); // Branch Header Hamburger
    const openSidebarCityBtn = document.getElementById('open-sidebar-city-btn'); // City Header Hamburger
    // No close button explicit in new design, clicking outside handles it
    const sidebarBackdrop = document.getElementById('sidebar-backdrop');
    
    const navDashboardBtn = document.getElementById('nav-dashboard');
    const navCityAnalysisBtn = document.getElementById('nav-city-analysis');
    const navBoxesBtn = document.getElementById('nav-boxes-btn'); // New Boxes Nav
    const navBranchBtn = document.getElementById('nav-branch-btn');
    const navUploaderBtn = document.getElementById('nav-uploader');
    const navComparativoBtn = document.getElementById('nav-comparativo-btn'); // New

    // Views
    const dashboardContainer = document.getElementById('dashboard-container');
    const uploaderModal = document.getElementById('uploader-modal');
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

    // Boxes Filter Elements
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
    const boxesClearFiltersBtn = document.getElementById('boxes-clear-filters-btn');

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
    const comparisonRedeFilterDropdown = document.getElementById('comparison-rede-filter-dropdown');
    const comparisonComRedeBtn = document.getElementById('comparison-com-rede-btn');
    const comparisonRedeGroupContainer = document.getElementById('comparison-rede-group-container');
    const comparisonFilialFilter = document.getElementById('comparison-filial-filter');
    const comparisonCityFilter = document.getElementById('comparison-city-filter');
    const comparisonCitySuggestions = document.getElementById('comparison-city-suggestions');
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

            // Icon Paths
            const plusPath = "M12 4v16m8-8H4"; // Heroicons Plus
            const minusPath = "M20 12H4"; // Heroicons Minus

            // Update Icon
            if(toggleKpiIcon) {
                toggleKpiIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${isHidden ? plusPath : minusPath}"></path>`;
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
        if (screenId) {
            const screen = document.getElementById(screenId);
            screen?.classList.remove('hidden');
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
            state.filiais = comparisonFilialFilter.value === 'ambas' ? [] : [comparisonFilialFilter.value];
            state.cidades = comparisonCityFilter.value ? [comparisonCityFilter.value] : [];
            state.supervisores = selectedComparisonSupervisores;
            state.vendedores = selectedComparisonSellers;
            state.fornecedores = selectedComparisonSuppliers;
            state.tiposvenda = selectedComparisonTiposVenda;
            state.redes = selectedComparisonRedes;
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
             if (filiais.length > 0) comparisonFilialFilter.value = filiais[0];

             const cidades = getList('cidades');
             if (cidades.length > 0) comparisonCityFilter.value = cidades[0];

             selectedComparisonSupervisores = getList('supervisores');
             selectedComparisonSellers = getList('vendedores');
             selectedComparisonSuppliers = getList('fornecedores');
             selectedComparisonTiposVenda = getList('tiposvenda');
             selectedComparisonRedes = getList('redes');
        }
    }

    async function handleInitialRouting() {
        const params = new URLSearchParams(window.location.search);
        const view = params.get('view');

        if (view) {
            applyFiltersToView(view, params);
            showScreen('app-layout');

            if (view === 'city') {
                navCityAnalysisBtn.click();
            } else if (view === 'boxes') {
                navBoxesBtn.click();
            } else if (view === 'branch') {
                navBranchBtn.click();
            } else if (view === 'comparison') {
                navComparativoBtn.click();
            } else {
                navDashboardBtn.click();
                initDashboard();
            }
        } else {
            showScreen('app-layout');
            initDashboard();
        }
    }

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
            console.warn('Erro ao ler cache:', e);
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
            console.warn('Erro ao salvar cache:', e);
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

    async function checkProfileStatus(user) {
        if (isAppReady) return;

        const cacheKey = `user_auth_cache_${user.id}`;
        const cachedAuth = localStorage.getItem(cacheKey);

        if (cachedAuth) {
            try {
                const { status, role } = JSON.parse(cachedAuth);
                if (status === 'aprovado') {
                    window.userRole = role;
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
            const profileQuery = supabase.from('profiles').select('status, role').eq('id', user.id).single();

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

            if (status === 'aprovado') {
                localStorage.setItem(cacheKey, JSON.stringify({ status: 'aprovado', role: profile?.role }));
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
                    alert("Erro de conexão: " + (err.message || 'Erro desconhecido'));
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

    // --- Navigation & Sidebar Logic ---

    function openSidebar() {
        sideMenu.classList.remove('-translate-x-full');
        sidebarBackdrop.classList.remove('hidden');
    }

    function closeSidebar() {
        sideMenu.classList.add('-translate-x-full');
        sidebarBackdrop.classList.add('hidden');
    }

    openSidebarBtn.addEventListener('click', openSidebar);
    if (openSidebarBranchBtn) openSidebarBranchBtn.addEventListener('click', openSidebar);
    if (openSidebarCityBtn) openSidebarCityBtn.addEventListener('click', openSidebar);
    const openSidebarComparisonBtn = document.getElementById('open-sidebar-comparison-btn');
    if (openSidebarComparisonBtn) openSidebarComparisonBtn.addEventListener('click', openSidebar);

    sidebarBackdrop.addEventListener('click', closeSidebar);

    // Nav Links (Close sidebar on click)
    const resetViews = () => {
        dashboardContainer.classList.remove('hidden');
        uploaderModal.classList.add('hidden');
        mainDashboardView.classList.add('hidden');
        cityView.classList.add('hidden');
        boxesView.classList.add('hidden');
        branchView.classList.add('hidden');
        comparisonView.classList.add('hidden');
        // Reset active state styles (simple)
        [navDashboardBtn, navCityAnalysisBtn, navBoxesBtn, navBranchBtn, navUploaderBtn, navComparativoBtn].forEach(btn => btn?.classList.remove('bg-slate-700', 'text-white'));
    };

    navDashboardBtn.addEventListener('click', (e) => {
        if (navigateWithCtrl(e, 'dashboard')) return;
        resetViews();
        mainDashboardView.classList.remove('hidden');
        navDashboardBtn.classList.add('bg-slate-700', 'text-white');
        closeSidebar();
    });

    navCityAnalysisBtn.addEventListener('click', (e) => {
        if (navigateWithCtrl(e, 'city')) return;
        resetViews();
        cityView.classList.remove('hidden');
        navCityAnalysisBtn.classList.add('bg-slate-700', 'text-white');
        loadCityView();
        closeSidebar();
    });

    if (navBoxesBtn) {
        navBoxesBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'boxes')) return;
            resetViews();
            boxesView.classList.remove('hidden');
            navBoxesBtn.classList.add('bg-slate-700', 'text-white');
            loadBoxesView();
            closeSidebar();
        });
    }

    if (navComparativoBtn) {
        navComparativoBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'comparison')) return;
            resetViews();
            comparisonView.classList.remove('hidden');
            navComparativoBtn.classList.add('bg-slate-700', 'text-white');
            loadComparisonView();
            closeSidebar();
        });
    }

    if (navBranchBtn) {
        navBranchBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'branch')) return;
            resetViews();
            branchView.classList.remove('hidden');
            navBranchBtn.classList.add('bg-slate-700', 'text-white');
            loadBranchView();
            closeSidebar();
        });
    }

    navUploaderBtn.addEventListener('click', () => {
        if (window.userRole !== 'adm') {
            alert('Acesso negado: Apenas administradores podem acessar o uploader.');
            return;
        }
        uploaderModal.classList.remove('hidden');
        closeSidebar();
    });

    closeUploaderBtn.addEventListener('click', () => {
        uploaderModal.classList.add('hidden');
    });

    // Set initial active state
    navDashboardBtn.classList.add('bg-slate-700', 'text-white');


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
        mesFilter.value = '';

        // Reset Multi Select Arrays
        selectedFiliais = [];
        selectedCidades = [];
        selectedSupervisores = [];
        selectedVendedores = [];
        selectedFornecedores = [];
        selectedTiposVenda = [];
        selectedRedes = [];

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
        const hasFiles = files.salesPrevYearFile && files.salesCurrYearFile && files.salesCurrMonthFile && files.clientsFile && files.productsFile;
        generateBtn.disabled = !hasFiles;
    };

    if(salesPrevYearInput) salesPrevYearInput.addEventListener('change', (e) => { files.salesPrevYearFile = e.target.files[0]; checkFiles(); });
    if(salesCurrYearInput) salesCurrYearInput.addEventListener('change', (e) => { files.salesCurrYearFile = e.target.files[0]; checkFiles(); });
    if(salesCurrMonthInput) salesCurrMonthInput.addEventListener('change', (e) => { files.salesCurrMonthFile = e.target.files[0]; checkFiles(); });
    if(clientsFileInput) clientsFileInput.addEventListener('change', (e) => { files.clientsFile = e.target.files[0]; checkFiles(); });
    if(productsFileInput) productsFileInput.addEventListener('change', (e) => { files.productsFile = e.target.files[0]; checkFiles(); });

    if(optimizeDbBtn) optimizeDbBtn.addEventListener('click', async () => {
        if (window.userRole !== 'adm') {
            alert('Apenas administradores podem executar esta ação.');
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
            alert(data);
        } catch (e) {
            statusText.textContent = 'Erro: ' + e.message;
            alert('Erro: ' + e.message);
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
            console.error("Erro ao buscar mapa de cidades:", error);
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

    if(navUploaderBtn) navUploaderBtn.addEventListener('click', async () => {
        if (window.userRole !== 'adm') {
            alert('Acesso negado: Apenas administradores podem acessar o uploader.');
            return;
        }
        uploaderModal.classList.remove('hidden');
        closeSidebar();
        checkMissingBranches();
    });

    if(generateBtn) generateBtn.addEventListener('click', async () => {
        if (!files.salesPrevYearFile || !files.salesCurrYearFile || !files.salesCurrMonthFile || !files.clientsFile || !files.productsFile) return;

        generateBtn.disabled = true;
        statusContainer.classList.remove('hidden');
        statusText.textContent = 'Carregando configurações...';
        progressBar.style.width = '2%';

        // Fetch current city map
        const cityBranchMap = await fetchCityBranchMap();

        statusText.textContent = 'Processando...';
        
        const worker = new Worker('src/js/worker.js?v=2');
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
                        if (cityErr) console.warn('Erro ao inserir novas cidades:', cityErr);
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
                        initDashboard();
                    }, 1500);
                } catch (e) {
                    statusText.innerHTML = `<span class="text-red-500">Erro: ${e.message}</span>`;
                    generateBtn.disabled = false;
                }
            } else if (type === 'error') {
                statusText.innerHTML = `<span class="text-red-500">Erro: ${message}</span>`;
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
                    console.warn(`Tentativa ${i + 1} falhou. Retentando em ${delay}ms...`, error);
                    await new Promise(resolve => setTimeout(resolve, delay));
                    delay *= 2; // Exponential backoff
                }
            }
        };

        const performUpsert = async (table, batch) => {
            await retryOperation(async () => {
                const { error } = await supabase.from(table).insert(batch);
                if (error) throw new Error(`Erro ${table}: ${error.message}`);
            });
        };
        const performDimensionUpsert = async (table, batch) => {
             // For dimensions, we must upsert (update if exists)
             // Supabase JS upsert needs onConflict column
             await retryOperation(async () => {
                 const { error } = await supabase.from(table).upsert(batch, { onConflict: 'codigo' });
                 if (error) {
                     if (error.message && (error.message.includes('Could not find the table') || error.message.includes('relation') || error.code === '42P01')) {
                         alert("Erro de Configuração: As tabelas novas (dimensões) não foram encontradas. \n\nPor favor, execute o script 'sql/optimization_plan.sql' no Editor SQL do Supabase para criar as tabelas necessárias e tente novamente.");
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

        const BATCH_SIZE = 4000;
        const CONCURRENT_REQUESTS = 10;

        const uploadBatch = async (table, items) => {
            const totalBatches = Math.ceil(items.length / BATCH_SIZE);
            let processedBatches = 0;
            const processChunk = async (chunkIndex) => {
                const start = chunkIndex * BATCH_SIZE;
                const end = start + BATCH_SIZE;
                const batch = items.slice(start, end);
                await performUpsert(table, batch);
                processedBatches++;
                const progress = Math.round((processedBatches / totalBatches) * 100);
                updateStatus(`Enviando ${table}... ${progress}%`, progress);
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
                 await performDimensionUpsert('dim_vendedores', data.newVendors);
            }
            if (data.newProviders && data.newProviders.length > 0) {
                 updateStatus('Atualizando Fornecedores...', 3);
                 await performDimensionUpsert('dim_fornecedores', data.newProviders);
            }

            if (data.history?.length) { updateStatus('Limpar hist...', 10); await clearTable('data_history'); await uploadBatch('data_history', data.history); }
            if (data.detailed?.length) { updateStatus('Limpar det...', 40); await clearTable('data_detailed'); await uploadBatch('data_detailed', data.detailed); }
            if (data.clients?.length) { updateStatus('Limpar cli...', 70); await clearTable('data_clients'); await uploadBatch('data_clients', data.clients); }

            updateStatus('Atualizando filtros...', 90);
            await supabase.rpc('refresh_cache_filters');
            
            updateStatus('Atualizando resumo...', 95);
            await supabase.rpc('refresh_cache_summary');

        } catch (error) {
            console.error(error);
            throw error;
        }
    }

    // --- Dashboard Data Logic ---


    // Boxes Logic
    let boxesFilterDebounceTimer;
    const handleBoxesFilterChange = async () => {
        clearTimeout(boxesFilterDebounceTimer);
        boxesFilterDebounceTimer = setTimeout(async () => {
            await loadBoxesView();
        }, 500);
    };

    if (boxesAnoFilter) boxesAnoFilter.addEventListener('change', handleBoxesFilterChange);
    if (boxesMesFilter) boxesMesFilter.addEventListener('change', handleBoxesFilterChange);

    document.addEventListener('click', (e) => {
        const dropdowns = [boxesFilialFilterDropdown, boxesProdutoFilterDropdown, boxesSupervisorFilterDropdown, boxesVendedorFilterDropdown, boxesFornecedorFilterDropdown, boxesCidadeFilterDropdown];
        const btns = [boxesFilialFilterBtn, boxesProdutoFilterBtn, boxesSupervisorFilterBtn, boxesVendedorFilterBtn, boxesFornecedorFilterBtn, boxesCidadeFilterBtn];
        let anyClosed = false;
        dropdowns.forEach((dd, idx) => {
            if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
                dd.classList.add('hidden');
                anyClosed = true;
            }
        });
        if (anyClosed && !boxesView.classList.contains('hidden')) {
            handleBoxesFilterChange();
        }
    });

    if (boxesClearFiltersBtn) {
        boxesClearFiltersBtn.addEventListener('click', () => {
            boxesAnoFilter.value = 'todos';
            boxesMesFilter.value = '';
            boxesSelectedFiliais = [];
            boxesSelectedProducts = [];
            boxesSelectedSupervisores = [];
            boxesSelectedVendedores = [];
            boxesSelectedFornecedores = [];
            boxesSelectedCidades = [];
            initBoxesFilters().then(loadBoxesView);
        });
    }

    async function initBoxesFilters() {
        const filters = {
            p_ano: 'todos',
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: []
        };
        const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
        if (error) console.error('Error fetching boxes filters:', error);
        if (!filterData) return;

        if (filterData.anos && boxesAnoFilter) {
            const currentVal = boxesAnoFilter.value;
            boxesAnoFilter.innerHTML = '<option value="todos">Todos</option>';
            filterData.anos.forEach(a => {
                const opt = document.createElement('option');
                opt.value = a;
                opt.textContent = a;
                boxesAnoFilter.appendChild(opt);
            });
            if (currentVal && currentVal !== 'todos') boxesAnoFilter.value = currentVal;
            else if (filterData.anos.length > 0) boxesAnoFilter.value = filterData.anos[0];
        }

        if (boxesMesFilter && boxesMesFilter.options.length <= 1) {
            boxesMesFilter.innerHTML = '<option value="">Todos</option>';
            const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
            meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; boxesMesFilter.appendChild(opt); });
        }

        setupCityMultiSelect(boxesFilialFilterBtn, boxesFilialFilterDropdown, boxesFilialFilterDropdown, filterData.filiais, boxesSelectedFiliais);
        setupCityMultiSelect(boxesSupervisorFilterBtn, boxesSupervisorFilterDropdown, boxesSupervisorFilterDropdown, filterData.supervisors, boxesSelectedSupervisores);
        setupCityMultiSelect(boxesVendedorFilterBtn, boxesVendedorFilterDropdown, boxesVendedorFilterList, filterData.vendedores, boxesSelectedVendedores, boxesVendedorFilterSearch);
        setupCityMultiSelect(boxesFornecedorFilterBtn, boxesFornecedorFilterDropdown, boxesFornecedorFilterList, filterData.fornecedores, boxesSelectedFornecedores, boxesFornecedorFilterSearch, true);
        setupCityMultiSelect(boxesCidadeFilterBtn, boxesCidadeFilterDropdown, boxesCidadeFilterList, filterData.cidades, boxesSelectedCidades, boxesCidadeFilterSearch);

        // Products - filterData.produtos
        setupCityMultiSelect(boxesProdutoFilterBtn, boxesProdutoFilterDropdown, boxesProdutoFilterList, filterData.produtos || [], boxesSelectedProducts, boxesProdutoFilterSearch, true);
    }

    async function loadBoxesView() {
        showDashboardLoading('boxes-view');

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
            p_ano: boxesAnoFilter.value === 'todos' ? null : boxesAnoFilter.value,
            p_mes: boxesMesFilter.value === '' ? null : boxesMesFilter.value
        };

        const { data, error } = await supabase.rpc('get_boxes_dashboard_data', filters);

        hideDashboardLoading();

        if (error) {
            console.error(error);
            if (error.message.includes('function get_boxes_dashboard_data') && error.message.includes('does not exist')) {
                alert("Erro: A função 'get_boxes_dashboard_data' não foi encontrada. Aplique o script de migração 'sql/migration_boxes.sql'.");
            }
            return;
        }

        renderBoxesDashboard(data);
    }

    function renderBoxesDashboard(data) {
        // KPIs
        const kpis = data.kpis || { total_fat: 0, total_peso: 0, total_caixas: 0 };
        document.getElementById('boxes-kpi-fat').textContent = (kpis.total_fat || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
        document.getElementById('boxes-kpi-peso').textContent = ((kpis.total_peso || 0) / 1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';
        document.getElementById('boxes-kpi-caixas').textContent = Math.round(kpis.total_caixas || 0).toLocaleString('pt-BR');

        // Chart
        const monthlyData = data.monthly_data || [];
        // Map to 12 months (0-11)
        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const labels = monthNames;
        const boxesValues = new Array(12).fill(0);

        monthlyData.forEach(d => {
            if (d.month_index >= 0 && d.month_index < 12) {
                boxesValues[d.month_index] = d.caixas;
            }
        });

        createChart('boxesChart', 'bar', labels, [{
            label: 'Caixas',
            data: boxesValues,
            backgroundColor: '#10b981', // Emerald
            borderColor: '#10b981',
            borderWidth: 1
        }], (v) => Math.round(v).toLocaleString('pt-BR')); // Formatter for boxes

        // Table
        const products = data.products_table || [];
        const tableBody = document.getElementById('boxesProductTableBody');
        if (products.length > 0) {
            tableBody.innerHTML = products.map(p => `
                <tr class="table-row">
                    <td class="p-2">${p.produto}</td>
                    <td class="p-2">${p.descricao}</td>
                    <td class="p-2 text-right font-bold text-emerald-400">${Math.round(p.caixas || 0).toLocaleString('pt-BR')}</td>
                    <td class="p-2 text-right">${(p.faturamento || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })}</td>
                    <td class="p-2 text-right">${((p.peso || 0) / 1000).toLocaleString('pt-BR', { minimumFractionDigits: 2 })} Ton</td>
                </tr>
            `).join('');
        } else {
            tableBody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-slate-500">Nenhum produto encontrado.</td></tr>';
        }
    }

    // Boxes Filter Elements - MOVED UP

    // Boxes Logic
    let boxesFilterDebounceTimer;
    const handleBoxesFilterChange = async () => {
        clearTimeout(boxesFilterDebounceTimer);
        boxesFilterDebounceTimer = setTimeout(async () => {
            await loadBoxesView();
        }, 500);
    };

    if (boxesAnoFilter) boxesAnoFilter.addEventListener('change', handleBoxesFilterChange);
    if (boxesMesFilter) boxesMesFilter.addEventListener('change', handleBoxesFilterChange);

    document.addEventListener('click', (e) => {
        const dropdowns = [boxesFilialFilterDropdown, boxesProdutoFilterDropdown, boxesSupervisorFilterDropdown, boxesVendedorFilterDropdown, boxesFornecedorFilterDropdown, boxesCidadeFilterDropdown];
        const btns = [boxesFilialFilterBtn, boxesProdutoFilterBtn, boxesSupervisorFilterBtn, boxesVendedorFilterBtn, boxesFornecedorFilterBtn, boxesCidadeFilterBtn];
        let anyClosed = false;
        dropdowns.forEach((dd, idx) => {
            if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
                dd.classList.add('hidden');
                anyClosed = true;
            }
        });
        if (anyClosed && !boxesView.classList.contains('hidden')) {
            handleBoxesFilterChange();
        }
    });

    if (boxesClearFiltersBtn) {
        boxesClearFiltersBtn.addEventListener('click', () => {
            boxesAnoFilter.value = 'todos';
            boxesMesFilter.value = '';
            boxesSelectedFiliais = [];
            boxesSelectedProducts = [];
            boxesSelectedSupervisores = [];
            boxesSelectedVendedores = [];
            boxesSelectedFornecedores = [];
            boxesSelectedCidades = [];
            initBoxesFilters().then(loadBoxesView);
        });
    }

    async function initBoxesFilters() {
        const filters = {
            p_ano: 'todos',
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: []
        };
        const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
        if (error) console.error('Error fetching boxes filters:', error);
        if (!filterData) return;

        if (filterData.anos && boxesAnoFilter) {
            const currentVal = boxesAnoFilter.value;
            boxesAnoFilter.innerHTML = '<option value="todos">Todos</option>';
            filterData.anos.forEach(a => {
                const opt = document.createElement('option');
                opt.value = a;
                opt.textContent = a;
                boxesAnoFilter.appendChild(opt);
            });
            if (currentVal && currentVal !== 'todos') boxesAnoFilter.value = currentVal;
            else if (filterData.anos.length > 0) boxesAnoFilter.value = filterData.anos[0];
        }

        if (boxesMesFilter && boxesMesFilter.options.length <= 1) {
            boxesMesFilter.innerHTML = '<option value="">Todos</option>';
            const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
            meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; boxesMesFilter.appendChild(opt); });
        }

        setupCityMultiSelect(boxesFilialFilterBtn, boxesFilialFilterDropdown, boxesFilialFilterDropdown, filterData.filiais, boxesSelectedFiliais);
        setupCityMultiSelect(boxesSupervisorFilterBtn, boxesSupervisorFilterDropdown, boxesSupervisorFilterDropdown, filterData.supervisors, boxesSelectedSupervisores);
        setupCityMultiSelect(boxesVendedorFilterBtn, boxesVendedorFilterDropdown, boxesVendedorFilterList, filterData.vendedores, boxesSelectedVendedores, boxesVendedorFilterSearch);
        setupCityMultiSelect(boxesFornecedorFilterBtn, boxesFornecedorFilterDropdown, boxesFornecedorFilterList, filterData.fornecedores, boxesSelectedFornecedores, boxesFornecedorFilterSearch, true);
        setupCityMultiSelect(boxesCidadeFilterBtn, boxesCidadeFilterDropdown, boxesCidadeFilterList, filterData.cidades, boxesSelectedCidades, boxesCidadeFilterSearch);

        // Products - filterData.produtos
        setupCityMultiSelect(boxesProdutoFilterBtn, boxesProdutoFilterDropdown, boxesProdutoFilterList, filterData.produtos || [], boxesSelectedProducts, boxesProdutoFilterSearch, true);
    }

    async function loadBoxesView() {
        showDashboardLoading('boxes-view');

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
            p_ano: boxesAnoFilter.value === 'todos' ? null : boxesAnoFilter.value,
            p_mes: boxesMesFilter.value === '' ? null : boxesMesFilter.value
        };

        const { data, error } = await supabase.rpc('get_boxes_dashboard_data', filters);

        hideDashboardLoading();

        if (error) {
            console.error(error);
            if (error.message.includes('function get_boxes_dashboard_data') && error.message.includes('does not exist')) {
                alert("Erro: A função 'get_boxes_dashboard_data' não foi encontrada. Aplique o script de migração 'sql/migration_boxes.sql'.");
            }
            return;
        }

        renderBoxesDashboard(data);
    }

    function renderBoxesDashboard(data) {
        // KPIs
        const kpis = data.kpis || { total_fat: 0, total_peso: 0, total_caixas: 0 };
        document.getElementById('boxes-kpi-fat').textContent = (kpis.total_fat || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
        document.getElementById('boxes-kpi-peso').textContent = ((kpis.total_peso || 0) / 1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';
        document.getElementById('boxes-kpi-caixas').textContent = Math.round(kpis.total_caixas || 0).toLocaleString('pt-BR');

        // Chart
        const monthlyData = data.monthly_data || [];
        // Map to 12 months (0-11)
        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const labels = monthNames;
        const boxesValues = new Array(12).fill(0);

        monthlyData.forEach(d => {
            if (d.month_index >= 0 && d.month_index < 12) {
                boxesValues[d.month_index] = d.caixas;
            }
        });

        createChart('boxesChart', 'bar', labels, [{
            label: 'Caixas',
            data: boxesValues,
            backgroundColor: '#10b981', // Emerald
            borderColor: '#10b981',
            borderWidth: 1
        }], (v) => Math.round(v).toLocaleString('pt-BR')); // Formatter for boxes

        // Table
        const products = data.products_table || [];
        const tableBody = document.getElementById('boxesProductTableBody');
        if (products.length > 0) {
            tableBody.innerHTML = products.map(p => `
                <tr class="table-row">
                    <td class="p-2">${p.produto}</td>
                    <td class="p-2">${p.descricao}</td>
                    <td class="p-2 text-right font-bold text-emerald-400">${Math.round(p.caixas || 0).toLocaleString('pt-BR')}</td>
                    <td class="p-2 text-right">${(p.faturamento || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })}</td>
                    <td class="p-2 text-right">${((p.peso || 0) / 1000).toLocaleString('pt-BR', { minimumFractionDigits: 2 })} Ton</td>
                </tr>
            `).join('');
        } else {
            tableBody.innerHTML = '<tr><td colspan="5" class="p-4 text-center text-slate-500">Nenhum produto encontrado.</td></tr>';
        }
    }

    // Boxes Filter Elements
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
    const boxesClearFiltersBtn = document.getElementById('boxes-clear-filters-btn');

    let boxesSelectedFiliais = [];
    let boxesSelectedProducts = [];
    let boxesSelectedSupervisores = [];
    let boxesSelectedVendedores = [];
    let boxesSelectedFornecedores = [];
    let boxesSelectedCidades = [];

    // State
    let currentCityPage = 0;
    const cityPageSize = 50;
    let totalActiveClients = 0;
    let currentCityInactivePage = 0;
    const cityInactivePageSize = 50;
    let totalInactiveClients = 0;

    let selectedFiliais = [];
    let selectedCidades = [];
    let selectedSupervisores = [];
    let selectedVendedores = [];
    let selectedFornecedores = [];
    let selectedTiposVenda = [];
    let selectedRedes = [];
    let currentCharts = {};
    let holidays = [];
    let lastSalesDate = null;
    let currentChartMode = 'faturamento'; // 'faturamento' or 'peso'
    let lastDashboardData = null;

    // Prefetch State
    let availableFiltersState = { filiais: [], supervisors: [], cidades: [], vendedores: [], fornecedores: [], tipos_venda: [], redes: [] };
    let prefetchQueue = [];
    let isPrefetching = false;

    // --- Loading Helpers ---
    function showDashboardLoading(targetId = 'main-dashboard-view') {
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

    function hideDashboardLoading() {
        const overlay = document.getElementById('dashboard-loading-overlay');
        if (overlay) overlay.classList.add('hidden');
    }

    async function initDashboard() {
        showDashboardLoading();
        await checkDataVersion(); // Check for invalidation first

        const filters = getCurrentFilters();
        await loadFilters(filters);
        await loadMainDashboardData();
        
        // Trigger background prefetch after main load
        setTimeout(() => {
            queueCommonFilters();
        }, 3000);
    }

    async function checkDataVersion() {
        try {
            const { data: serverVersion, error } = await supabase.rpc('get_data_version');
            if (error) { console.warn('Erro ao verificar versão:', error); return; }

            const localVersion = localStorage.getItem('dashboard_data_version');
            
            if (serverVersion && serverVersion !== localVersion) {
                console.log('Nova versão de dados detectada. Limpando cache...', serverVersion);
                
                // Clear IndexedDB
                const db = await initDB();
                await db.clear(STORE_NAME);
                
                // Update Local Version
                localStorage.setItem('dashboard_data_version', serverVersion);
            }
        } catch (e) {
            console.error('Falha na validação de cache:', e);
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
            p_rede: selectedRedes
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
                    console.log('Serving filters from cache (fresh)');
                    applyFiltersData(cachedEntry.data);
                    return; 
                }
            }
        } catch (e) { console.warn('Cache error:', e); }

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

    function setupMultiSelect(btn, dropdown, container, items, selectedArray, labelCallback, isObject = false, searchInput = null) {
        const MAX_ITEMS = 100;
        btn.onclick = (e) => { e.stopPropagation(); dropdown.classList.toggle('hidden'); };
        
        let debounceTimer;
        const renderItems = (filterText = '') => {
            container.innerHTML = '';
            let filteredItems = items || [];
            if (filterText) {
                const lower = filterText.toLowerCase();
                filteredItems = filteredItems.filter(item => {
                    const val = isObject ? item.name : item;
                    return String(val).toLowerCase().includes(lower);
                });
            }
            
            const displayItems = filteredItems.slice(0, MAX_ITEMS);
            
            displayItems.forEach(item => {
                const value = isObject ? item.cod : item;
                const label = isObject ? item.name : item;
                const isSelected = selectedArray.includes(String(value));
                const div = document.createElement('div');
                div.className = 'flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded';
                div.innerHTML = `<input type="checkbox" value="${value}" ${isSelected ? 'checked' : ''} class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2"><label class="ml-2 text-sm text-slate-200 cursor-pointer flex-1">${label}</label>`;
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    const val = String(value);
                    if (checkbox.checked) { if (!selectedArray.includes(val)) selectedArray.push(val); } else { const idx = selectedArray.indexOf(val); if (idx > -1) selectedArray.splice(idx, 1); }
                    updateBtnLabel();
                };
                container.appendChild(div);
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
            if (selectedArray.length === 0) {
                span.textContent = 'Todas';
                if(btn.id.includes('vendedor') || btn.id.includes('fornecedor') || btn.id.includes('supervisor') || btn.id.includes('tipovenda')) span.textContent = 'Todos';
            } else if (selectedArray.length === 1) {
                const val = selectedArray[0];
                let found;
                if (isObject) found = items.find(i => String(i.cod) === val); else found = items.find(i => String(i) === val);
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

    function applyFiltersData(data) {
        // Capture available options for prefetcher
        availableFiltersState.filiais = data.filiais || [];
        availableFiltersState.supervisors = data.supervisors || [];
        availableFiltersState.cidades = data.cidades || [];
        availableFiltersState.vendedores = data.vendedores || [];
        availableFiltersState.fornecedores = data.fornecedores || []; // Array of objects
        availableFiltersState.tipos_venda = data.tipos_venda || [];
        availableFiltersState.redes = data.redes || [];

        const updateSingleSelect = (element, items) => {
            const currentVal = element.value;
            element.innerHTML = '';
            // Only add 'Todos' if it's NOT the year filter
            if (element.id !== 'ano-filter') {
                const allOpt = document.createElement('option');
                allOpt.value = (element.id === 'ano-filter') ? 'todos' : ''; // Fallback, though ano-filter skips this block
                allOpt.textContent = 'Todos';
                element.appendChild(allOpt);
            }
            if (items) {
                items.forEach(item => {
                    const opt = document.createElement('option');
                    opt.value = item;
                    opt.textContent = item;
                    element.appendChild(opt);
                });
            }
            // Logic to set default or preserve selection
            if (currentVal && Array.from(element.options).some(o => o.value === currentVal)) {
                element.value = currentVal;
            } else if (element.id === 'ano-filter' && items && items.length > 0) {
                 // Default to first year (usually current/max)
                 element.value = items[0];
            }
        };
        updateSingleSelect(anoFilter, data.anos);
        if (mesFilter.options.length <= 1) { 
            mesFilter.innerHTML = '<option value="">Todos</option>';
            const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
            meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; mesFilter.appendChild(opt); });
        }
        setupMultiSelect(filialFilterBtn, filialFilterDropdown, filialFilterDropdown, data.filiais, selectedFiliais, () => {});
        setupMultiSelect(cidadeFilterBtn, cidadeFilterDropdown, cidadeFilterList, data.cidades, selectedCidades, () => {}, false, cidadeFilterSearch);
        setupMultiSelect(supervisorFilterBtn, supervisorFilterDropdown, supervisorFilterDropdown, data.supervisors, selectedSupervisores, () => {});
        setupMultiSelect(vendedorFilterBtn, vendedorFilterDropdown, vendedorFilterList, data.vendedores, selectedVendedores, () => {}, false, vendedorFilterSearch);
        setupMultiSelect(fornecedorFilterBtn, fornecedorFilterDropdown, fornecedorFilterList, data.fornecedores, selectedFornecedores, () => {}, true, fornecedorFilterSearch);
        setupMultiSelect(tipovendaFilterBtn, tipovendaFilterDropdown, tipovendaFilterDropdown, data.tipos_venda, selectedTiposVenda, () => {});

        // Rede Logic with "Com Rede" and "Sem Rede"
        const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
        setupMultiSelect(redeFilterBtn, redeFilterDropdown, redeFilterList, redes, selectedRedes, () => {}, false, redeFilterSearch);
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [filialFilterDropdown, cidadeFilterDropdown, supervisorFilterDropdown, vendedorFilterDropdown, fornecedorFilterDropdown, tipovendaFilterDropdown, redeFilterDropdown];
        const btns = [filialFilterBtn, cidadeFilterBtn, supervisorFilterBtn, vendedorFilterBtn, fornecedorFilterBtn, tipovendaFilterBtn, redeFilterBtn];
        let anyClosed = false;
        dropdowns.forEach((dd, idx) => {
            if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx].contains(e.target)) {
                dd.classList.add('hidden');
                anyClosed = true;
            }
        });
        if (anyClosed && !mainDashboardView.classList.contains('hidden')) {
            handleFilterChange();
        }
    });

    let filterDebounceTimer;
    const handleFilterChange = async () => {
        const filters = getCurrentFilters();
        clearTimeout(filterDebounceTimer);
        filterDebounceTimer = setTimeout(async () => {
            showDashboardLoading();
            try { await loadFilters(filters); } catch (err) { console.error("Failed to load filters:", err); }
            try { await loadMainDashboardData(); } catch (err) { console.error("Failed to load dashboard data:", err); }
            if (!cityView.classList.contains('hidden')) { currentCityPage = 0; currentCityInactivePage = 0; await loadCityView(); }
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
                        if (!isBackground) console.log('Serving from Cache (Instant)');
                        return { data: cachedEntry.data, source: 'cache', timestamp: cachedEntry.timestamp };
                    } else {
                         return { data: cachedEntry.data, source: 'stale', timestamp: cachedEntry.timestamp };
                    }
                }
            } catch (e) { console.warn('Cache error:', e); }
        } else {
            console.log('Force Refresh: Bypassing cache.');
        }

        // 2. Network Request
        if (isBackground) console.log(`[Background] Fetching data from API...`);
        const { data, error } = await supabase.rpc('get_main_dashboard_data', filters);
        
        if (error) {
            console.error('API Error:', error);
            return { data: null, error };
        }

        // 3. Save to Cache
        await saveToCache(cacheKey, data);
        if (isBackground) console.log(`[Background] Cached successfully.`);

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
                    console.log('SWR: Rendering cached data immediately...');
                    renderDashboard(cachedEntry.data);
                    lastDashboardData = cachedEntry.data;

                    const age = Date.now() - cachedEntry.timestamp;
                    if (age < 60 * 1000) { // Fresh enough (1 min)
                         console.log('SWR: Cache is fresh (<1min), skipping background fetch.');
                         await fetchLastSalesDate();
                         hideDashboardLoading();
                         prefetchViews(filters);
                         return;
                    } else {
                        console.log('SWR: Cache is stale, fetching update in background...');
                        showDashboardLoading(); // Optional: show loading indicator non-intrusively
                    }
                } else {
                    showDashboardLoading();
                }
            } catch (e) {
                console.warn('SWR Cache Error:', e);
                showDashboardLoading();
            }
        } else {
            showDashboardLoading();
        }

        // 2. Network Fetch (Background or Foreground)
        const [dashboardResult, _] = await Promise.all([
            fetchDashboardData(filters, false, true), // Force network fetch logic reusing existing func but we handle flow here
            fetchLastSalesDate()
        ]);

        const { data, error } = dashboardResult;
        
        if (data && !error) {
            console.log('SWR: Updated with fresh data.');
            lastDashboardData = data;
            renderDashboard(data);

            // Prefetch Next
            prefetchViews(filters);
        }
        
        hideDashboardLoading();
    }

    // Prefetch Background Logic
    let prefetchDebounce;
    async function prefetchViews(filters) {
        clearTimeout(prefetchDebounce);

        const runPrefetch = async () => {
            if (document.hidden) return; // Save resources if tab hidden

            console.log('[Prefetch] Starting background fetch for other views...');

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
            const cityFilters = { ...filters, p_page: 0, p_limit: 50, p_inactive_page: 0, p_inactive_limit: 50 };
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
                .single();
            
            if (data && data.dtped) {
                // dtped is timestamp with time zone, e.g., "2026-01-20T14:00:00+00:00"
                // We want just the date part in YYYY-MM-DD for comparison
                lastSalesDate = data.dtped.split('T')[0];
            } else {
                lastSalesDate = null;
            }
        } catch (e) {
            console.error("Error fetching last sales date:", e);
        }
    }

    // --- Background Prefetch Logic ---

    async function queueCommonFilters() {
        console.log('[Background] Iniciando estratégia de pré-carregamento massivo...');
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

        // Wait for all checks
        await Promise.all(tasks);

        if (prefetchQueue.length > 0) {
            console.log(`[Background] ${prefetchQueue.length} filtros novos agendados.`);
            processQueue();
        } else {
            console.log('[Background] Todos os filtros comuns já estão em cache.');
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
        
        console.log(`[Background] Processando filtro para: ${task.label} (${prefetchQueue.length} restantes)`);
        
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

        // KPI Calculation Variables
        let currFat, currKg, prevFat, prevKg, triAvgFat, triAvgPeso;
        let kpiTitleFat, kpiTitleKg;
        
        // --- KPI LOGIC (Scenario Check) ---
        if (anoFilter.value !== 'todos' && mesFilter.value === '') {
            // SCENARIO A: Year Selected, Month All -> Show Year vs Previous Year (Accumulated)
            
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
            
            kpiTitleFat = `Tend. FAT ${data.current_year} vs Ano Ant.`;
            kpiTitleKg = `Tend. TON ${data.current_year} vs Ano Ant.`;

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
            // Logic for Previous: If Month selected, compare to same month prev year. If Year selected, compare to full prev year.
            const activePreviousData = (mesFilter.value !== '') ? previousData.filter(d => d.month_index === targetIndex) : previousData;

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
            const fmtBRL = (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
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
            document.getElementById('kpi-mix-val').textContent = avgMixCurr.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
            const elMixPerc = document.getElementById('kpi-mix-perc');
            elMixPerc.textContent = `${varMix > 0 ? '+' : ''}${varMix.toFixed(1)}%`;
            elMixPerc.className = `text-lg font-bold ${varMix >= 0 ? 'text-emerald-400' : 'text-red-400'}`;
            document.getElementById('kpi-mix-sec').textContent = avgMixPrev.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        } catch (err) {
            console.error('Error updating new KPIs:', err);
        }

        updateKpiCard({
            prefix: 'fat',
            trendVal: currFat,
            prevVal: prevFat,
            fmt: (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }),
            calcEvo
        });
        
        updateKpiCard({
            prefix: 'kg',
            trendVal: currKg,
            prevVal: prevKg,
            fmt: (v) => `${(v/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} Ton`,
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
        
        if (anoFilter.value !== 'todos' && mesFilter.value === '') {
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
            fmt: (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }),
            calcEvo
        });

        updateKpiCard({
            prefix: 'tri-kg',
            trendVal: currMonthKgForTri,
            prevVal: triAvgPeso,
            fmt: (v) => `${(v/1000).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Ton`,
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
        const currencyFormatter = (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : ''));
        const weightFormatter = (v) => (v && v > 1000 ? (v/1000).toFixed(0) + ' Ton' : (v ? v.toFixed(0) : ''));
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

    function createChart(canvasId, type, labels, datasetsData, formatterVal) {
        const container = document.getElementById(canvasId + 'Container');
        if (!container) return;
        container.innerHTML = '';
        const newCanvas = document.createElement('canvas');
        newCanvas.id = canvasId;
        container.appendChild(newCanvas);

        const ctx = newCanvas.getContext('2d');
        const professionalPalette = { 'current': '#06b6d4', 'previous': '#f97316', 'trend': '#8b5cf6' };

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
                borderWidth: 1,
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
                plugins: {
                    legend: { labels: { color: '#cbd5e1' } },
                    datalabels: {
                        display: true,
                        anchor: 'end',
                        align: 'top',
                        offset: 4,
                        color: '#cbd5e1',
                        font: { size: 9, weight: 'bold' },
                        formatter: formatterVal || ((v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : '')))
                    }
                },
                scales: {
                    y: { 
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

    function updateTable(currData, prevData, currYear, prevYear, trendData) {
        const tableBody = document.getElementById('monthly-summary-table-body');
        const tableHead = document.querySelector('#monthly-summary-table thead tr');
        tableBody.innerHTML = '';

        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        let headerHTML = '<th class="px-2 py-2 text-left">INDICADOR</th>';
        monthNames.forEach(m => headerHTML += `<th class="px-2 py-2 text-center">${m}</th>`);
        if (trendData) {
            headerHTML += `<th class="px-2 py-2 text-center bg-purple-900/30 text-purple-200">Tendência</th>`;
        }
        tableHead.innerHTML = headerHTML;

        const indicators = [
            { name: 'POSITIVAÇÃO', key: 'positivacao', fmt: v => v.toLocaleString('pt-BR') },
            { name: 'FATURAMENTO', key: 'faturamento', fmt: v => v.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}) },
            { name: 'Mix PDV', key: 'mix_pdv', fmt: v => v.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) },
            { name: 'Ticket Médio', key: 'ticket_medio', fmt: v => v.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}) },
            { name: 'BONIFICAÇÃO', key: 'bonificacao', fmt: v => v.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}) },
            { name: '% Perda', key: 'perc_perda', allowNull: true, fmt: v => v !== null ? `${v.toFixed(1)}%` : '-' },
            { name: 'DEVOLUÇÃO', key: 'devolucao', fmt: v => `<span class="text-red-400">${v.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'})}</span>` },
            { name: '% Devolução', key: 'perc_devolucao', allowNull: true, fmt: v => v !== null ? `${v.toFixed(1)}%` : '-' },
            { name: 'TON VENDIDA', key: 'peso', fmt: v => `${(v/1000).toFixed(2)} Kg` }
        ];

        indicators.forEach(ind => {
            let rowHTML = `<tr class="table-row"><td class="font-bold p-2 text-left">${ind.name}</td>`;
            for(let i=0; i<12; i++) {
                const d = currData.find(x => x.month_index === i);
                let val = d ? d[ind.key] : null;
                if (val === undefined) val = null;
                if (val === null && !ind.allowNull) val = 0;
                rowHTML += `<td class="px-2 py-1.5 text-center">${ind.fmt(val)}</td>`;
            }
            if (trendData) {
                 let tVal = trendData[ind.key];
                 if (tVal === undefined) tVal = null;
                 if (tVal === null && !ind.allowNull) tVal = 0;
                 rowHTML += `<td class="px-2 py-1.5 text-center font-bold text-purple-300 bg-purple-900/20">${ind.fmt(tVal)}</td>`;
            }
            rowHTML += '</tr>';
            tableBody.innerHTML += rowHTML;
        });
    }


    let citySelectedFiliais = [];
    let citySelectedCidades = [];
    let citySelectedSupervisores = [];
    let citySelectedVendedores = [];
    let citySelectedFornecedores = [];
    let citySelectedTiposVenda = [];
    let citySelectedRedes = [];

    let cityFilterDebounceTimer;
    const handleCityFilterChange = () => {
        clearTimeout(cityFilterDebounceTimer);
        cityFilterDebounceTimer = setTimeout(() => {
            currentCityPage = 0; 
            currentCityInactivePage = 0;
            loadCityView();
        }, 500);
    };

    if (cityAnoFilter) cityAnoFilter.addEventListener('change', handleCityFilterChange);
    if (cityMesFilter) cityMesFilter.addEventListener('change', handleCityFilterChange);

    if (cityClearFiltersBtn) {
        cityClearFiltersBtn.addEventListener('click', () => {
             cityAnoFilter.value = 'todos';
             cityMesFilter.value = '';
             citySelectedFiliais = [];
             citySelectedCidades = [];
             citySelectedSupervisores = [];
             citySelectedVendedores = [];
             citySelectedFornecedores = [];
             citySelectedTiposVenda = [];
             citySelectedRedes = [];
             initCityFilters().then(loadCityView);
        });
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [cityFilialFilterDropdown, cityCidadeFilterDropdown, citySupervisorFilterDropdown, cityVendedorFilterDropdown, cityFornecedorFilterDropdown, cityTipovendaFilterDropdown, cityRedeFilterDropdown];
        const btns = [cityFilialFilterBtn, cityCidadeFilterBtn, citySupervisorFilterBtn, cityVendedorFilterBtn, cityFornecedorFilterBtn, cityTipovendaFilterBtn, cityRedeFilterBtn];
        let anyClosed = false;
        dropdowns.forEach((dd, idx) => {
            if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
                dd.classList.add('hidden');
                anyClosed = true;
            }
        });
        if (anyClosed && !cityView.classList.contains('hidden')) {
            handleCityFilterChange();
        }
    });

    function setupCityMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
        if(!btn || !dropdown) return;
        // Safety check for container
        if (!container) {
            console.warn('Container not found for filter', btn.id);
            return;
        }
        
        const MAX_ITEMS = 100;
        let debounceTimer;

        btn.onclick = (e) => { e.stopPropagation(); dropdown.classList.toggle('hidden'); };
        const renderItems = (filterText = '') => {
            container.innerHTML = '';
            let filteredItems = items || [];
            if (filterText) {
                const lower = filterText.toLowerCase();
                filteredItems = filteredItems.filter(item => {
                    const val = isObject ? item.name : item;
                    return String(val).toLowerCase().includes(lower);
                });
            }
            
            const displayItems = filteredItems.slice(0, MAX_ITEMS);

            displayItems.forEach(item => {
                const value = isObject ? item.cod : item;
                const label = isObject ? item.name : item;
                const isSelected = selectedArray.includes(String(value));
                const div = document.createElement('div');
                div.className = 'flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded';
                div.innerHTML = `<input type="checkbox" value="${value}" ${isSelected ? 'checked' : ''} class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2"><label class="ml-2 text-sm text-slate-200 cursor-pointer flex-1">${label}</label>`;
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    const val = String(value);
                    if (checkbox.checked) { if (!selectedArray.includes(val)) selectedArray.push(val); } else { const idx = selectedArray.indexOf(val); if (idx > -1) selectedArray.splice(idx, 1); }
                    updateBtnLabel();
                };
                container.appendChild(div);
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
                if (isObject) found = items.find(i => String(i.cod) === val); else found = items.find(i => String(i) === val);
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

    async function initCityFilters() {
        const filters = {
            p_ano: 'todos',
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: []
        };
         const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
         if (error) console.error('Error fetching city filters:', error);
         if (!filterData) return;

         if (filterData.anos && cityAnoFilter) {
             const currentVal = cityAnoFilter.value;
             cityAnoFilter.innerHTML = '<option value="todos">Todos</option>';
             filterData.anos.forEach(a => {
                 const opt = document.createElement('option');
                 opt.value = a;
                 opt.textContent = a;
                 cityAnoFilter.appendChild(opt);
             });
             if (currentVal && currentVal !== 'todos') cityAnoFilter.value = currentVal;
             else if (filterData.anos.length > 0) cityAnoFilter.value = filterData.anos[0];
         }
         
         if (cityMesFilter && cityMesFilter.options.length <= 1) {
            cityMesFilter.innerHTML = '<option value="">Todos</option>';
            const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
            meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; cityMesFilter.appendChild(opt); });
        }

        setupCityMultiSelect(cityFilialFilterBtn, cityFilialFilterDropdown, cityFilialFilterDropdown, filterData.filiais, citySelectedFiliais);
        setupCityMultiSelect(cityCidadeFilterBtn, cityCidadeFilterDropdown, cityCidadeFilterList, filterData.cidades, citySelectedCidades, cityCidadeFilterSearch);
        setupCityMultiSelect(citySupervisorFilterBtn, citySupervisorFilterDropdown, citySupervisorFilterDropdown, filterData.supervisors, citySelectedSupervisores);
        setupCityMultiSelect(cityVendedorFilterBtn, cityVendedorFilterDropdown, cityVendedorFilterList, filterData.vendedores, citySelectedVendedores, cityVendedorFilterSearch);
        setupCityMultiSelect(cityFornecedorFilterBtn, cityFornecedorFilterDropdown, cityFornecedorFilterList, filterData.fornecedores, citySelectedFornecedores, cityFornecedorFilterSearch, true);
        setupCityMultiSelect(cityTipovendaFilterBtn, cityTipovendaFilterDropdown, cityTipovendaFilterDropdown, filterData.tipos_venda, citySelectedTiposVenda);

        const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
        setupCityMultiSelect(cityRedeFilterBtn, cityRedeFilterDropdown, cityRedeFilterList, redes, citySelectedRedes, cityRedeFilterSearch);
    }

    async function loadCityView() {
        showDashboardLoading('city-view');

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
            p_ano: cityAnoFilter.value === 'todos' ? null : cityAnoFilter.value,
            p_mes: cityMesFilter.value === '' ? null : cityMesFilter.value,
            p_page: currentCityPage,
            p_limit: cityPageSize,
            p_inactive_page: currentCityInactivePage,
            p_inactive_limit: cityInactivePageSize
        };

        const { data, error } = await supabase.rpc('get_city_view_data', filters);
        
        hideDashboardLoading();

        if(error) { console.error(error); return; }

        totalActiveClients = data.total_active_count || 0;
        totalInactiveClients = data.total_inactive_count || 0;

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
        const inactiveClients = Array.isArray(data.inactive_clients) ? data.inactive_clients : mapRows(data.inactive_clients);

        const renderTable = (bodyId, items) => {
            const body = document.getElementById(bodyId);
            if (items && items.length > 0) {
                body.innerHTML = items.map(c => `
                    <tr class="table-row">
                        <td class="p-2">${c['Código']}</td>
                        <td class="p-2">${c.fantasia || c.razaoSocial}</td>
                        ${c.totalFaturamento !== undefined ? `<td class="p-2 text-right">${c.totalFaturamento.toLocaleString('pt-BR', {style:'currency', currency: 'BRL'})}</td>` : ''}
                        <td class="p-2">${c.cidade}</td>
                        <td class="p-2">${c.bairro}</td>
                        ${c.ultimaCompra ? `<td class="p-2 text-center">${new Date(c.ultimaCompra).toLocaleDateString('pt-BR')}</td>` : ''}
                        <td class="p-2">${c.rca1 || '-'}</td>
                    </tr>
                `).join('');
            } else {
                body.innerHTML = '<tr><td colspan="7" class="p-4 text-center text-slate-500">Nenhum registro encontrado.</td></tr>';
            }
        };

        renderTable('city-active-detail-table-body', activeClients);
        renderTable('city-inactive-detail-table-body', inactiveClients);

        renderCityPaginationControls();
        renderCityInactivePaginationControls();
    }


    let branchSelectedFiliais = [];
    let branchSelectedCidades = [];
    let branchSelectedSupervisores = [];
    let branchSelectedVendedores = [];
    let branchSelectedFornecedores = [];
    let branchSelectedTiposVenda = [];
    let branchSelectedRedes = [];
    let currentBranchChartMode = 'faturamento';

    // Filter Change Handler
    let branchFilterDebounceTimer;
    const handleBranchFilterChange = () => {
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
        const dropdowns = [branchFilialFilterDropdown, branchCidadeFilterDropdown, branchSupervisorFilterDropdown, branchVendedorFilterDropdown, branchFornecedorFilterDropdown, branchTipovendaFilterDropdown, branchRedeFilterDropdown];
        const btns = [branchFilialFilterBtn, branchCidadeFilterBtn, branchSupervisorFilterBtn, branchVendedorFilterBtn, branchFornecedorFilterBtn, branchTipovendaFilterBtn, branchRedeFilterBtn];
        let anyClosed = false;
        dropdowns.forEach((dd, idx) => {
            if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx].contains(e.target)) {
                dd.classList.add('hidden');
                anyClosed = true;
            }
        });
        if (anyClosed && !branchView.classList.contains('hidden')) {
            handleBranchFilterChange();
        }
    });
    
    branchClearFiltersBtn?.addEventListener('click', () => {
         branchAnoFilter.value = 'todos';
         branchMesFilter.value = '';
         branchSelectedFiliais = []; // Reset but re-init will likely pick first 2
         branchSelectedCidades = [];
         branchSelectedSupervisores = [];
         branchSelectedVendedores = [];
         branchSelectedFornecedores = [];
         branchSelectedTiposVenda = [];
         branchSelectedRedes = [];
         // Re-init filters to update UI
         initBranchFilters().then(loadBranchView);
    });


    async function initBranchFilters() {
        const filters = {
            p_ano: 'todos',
            p_mes: null,
            p_filial: [],
            p_cidade: [],
            p_supervisor: [],
            p_vendedor: [],
            p_fornecedor: [],
            p_tipovenda: [],
            p_rede: []
        };
         const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
         if (error) console.error('Error fetching branch filters:', error);
         if (!filterData) return;

         // Years
         if (filterData.anos) {
             const currentVal = branchAnoFilter.value;
             branchAnoFilter.innerHTML = '<option value="todos">Todos</option>';
             filterData.anos.forEach(a => {
                 const opt = document.createElement('option');
                 opt.value = a;
                 opt.textContent = a;
                 branchAnoFilter.appendChild(opt);
             });
             // Preserve selection or default to current year
             if (currentVal && currentVal !== 'todos') branchAnoFilter.value = currentVal;
             else if (filterData.anos.length > 0) branchAnoFilter.value = filterData.anos[0];
         }
         
         // Months
         if (branchMesFilter.options.length <= 1) {
            branchMesFilter.innerHTML = '<option value="">Todos</option>';
            const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
            meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; branchMesFilter.appendChild(opt); });
        }

        // Multi Selects
        setupBranchFilialSelect(branchFilialFilterBtn, branchFilialFilterDropdown, branchFilialFilterDropdown, filterData.filiais, branchSelectedFiliais);
        setupBranchMultiSelect(branchCidadeFilterBtn, branchCidadeFilterDropdown, branchCidadeFilterList, filterData.cidades, branchSelectedCidades, branchCidadeFilterSearch);
        setupBranchMultiSelect(branchSupervisorFilterBtn, branchSupervisorFilterDropdown, branchSupervisorFilterDropdown, filterData.supervisors, branchSelectedSupervisores);
        setupBranchMultiSelect(branchVendedorFilterBtn, branchVendedorFilterDropdown, branchVendedorFilterList, filterData.vendedores, branchSelectedVendedores, branchVendedorFilterSearch);
        setupBranchMultiSelect(branchFornecedorFilterBtn, branchFornecedorFilterDropdown, branchFornecedorFilterList, filterData.fornecedores, branchSelectedFornecedores, branchFornecedorFilterSearch, true);
        setupBranchMultiSelect(branchTipovendaFilterBtn, branchTipovendaFilterDropdown, branchTipovendaFilterDropdown, filterData.tipos_venda, branchSelectedTiposVenda);

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

        btn.onclick = (e) => { e.stopPropagation(); dropdown.classList.toggle('hidden'); };
        
        const renderItems = () => {
            container.innerHTML = '';
            (items || []).forEach(item => {
                const val = String(item);
                const isSelected = selectedArray.includes(val);
                const div = document.createElement('div');
                div.className = 'flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded';
                div.innerHTML = `<input type="checkbox" value="${val}" ${isSelected ? 'checked' : ''} class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2"><label class="ml-2 text-sm text-slate-200 cursor-pointer flex-1">${val}</label>`;
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    // Toggle logic
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    
                    if (checkbox.checked) {
                        if (!selectedArray.includes(val)) {
                            selectedArray.push(val);
                            // Enforce max 2: remove first added
                            if (selectedArray.length > 2) selectedArray.shift();
                        }
                    } else {
                        const idx = selectedArray.indexOf(val);
                        if (idx > -1) selectedArray.splice(idx, 1);
                    }
                    
                    renderItems(); // Re-render to update checks visually (e.g. if one was auto-removed)
                    updateBtnLabel();
                };
                container.appendChild(div);
            });
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
        const MAX_ITEMS = 100;
        let debounceTimer;

        btn.onclick = (e) => { e.stopPropagation(); dropdown.classList.toggle('hidden'); };
        const renderItems = (filterText = '') => {
            container.innerHTML = '';
            let filteredItems = items || [];
            if (filterText) {
                const lower = filterText.toLowerCase();
                filteredItems = filteredItems.filter(item => {
                    const val = isObject ? item.name : item;
                    return String(val).toLowerCase().includes(lower);
                });
            }
            
            const displayItems = filteredItems.slice(0, MAX_ITEMS);

            displayItems.forEach(item => {
                const value = isObject ? item.cod : item;
                const label = isObject ? item.name : item;
                const isSelected = selectedArray.includes(String(value));
                const div = document.createElement('div');
                div.className = 'flex items-center p-2 hover:bg-slate-700 cursor-pointer rounded';
                div.innerHTML = `<input type="checkbox" value="${value}" ${isSelected ? 'checked' : ''} class="w-4 h-4 text-teal-600 bg-gray-700 border-gray-600 rounded focus:ring-teal-500 focus:ring-2"><label class="ml-2 text-sm text-slate-200 cursor-pointer flex-1">${label}</label>`;
                div.onclick = (e) => {
                    e.stopPropagation();
                    const checkbox = div.querySelector('input');
                    if (e.target !== checkbox) checkbox.checked = !checkbox.checked;
                    const val = String(value);
                    if (checkbox.checked) { if (!selectedArray.includes(val)) selectedArray.push(val); } else { const idx = selectedArray.indexOf(val); if (idx > -1) selectedArray.splice(idx, 1); }
                    updateBtnLabel();
                };
                container.appendChild(div);
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
            if (selectedArray.length === 0) {
                span.textContent = 'Todas';
                if(btn.id.includes('vendedor') || btn.id.includes('fornecedor') || btn.id.includes('supervisor') || btn.id.includes('tipovenda')) span.textContent = 'Todos';
            } else if (selectedArray.length === 1) {
                const val = selectedArray[0];
                let found;
                if (isObject) found = items.find(i => String(i.cod) === val); else found = items.find(i => String(i) === val);
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

    async function loadBranchView() {
        showDashboardLoading('branch-view');

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
            p_rede: branchSelectedRedes.length > 0 ? branchSelectedRedes : null
        };

        // Aggregated Fetch (Fast Response)
        const cacheKey = generateCacheKey('branch_data', filters);
        let branchDataMap = null;

        try {
            const cachedEntry = await getFromCache(cacheKey);
            if (cachedEntry && cachedEntry.data) {
                console.log('Serving Branch View from Cache');
                branchDataMap = cachedEntry.data;
            } else {
                const { data, error } = await supabase.rpc('get_branch_comparison_data', filters);
                if (!error && data) {
                    branchDataMap = data;
                    saveToCache(cacheKey, data);
                } else {
                    console.error('Erro ao carregar filiais:', error);
                }
            }
        } catch (e) {
            console.error("Erro geral no fetch de filiais:", e);
        }
        
        hideDashboardLoading();
        if (branchDataMap) {
            renderBranchDashboard(branchDataMap, selectedYear, selectedMonth);
        }
    }

    function renderBranchDashboard(branchDataMap, selectedYear, selectedMonth) {
         const now = new Date();
         const branches = Object.keys(branchDataMap).sort();
         const kpiBranches = {}; 
         const chartBranches = {};
         const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

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
         const elVal1Fat = document.getElementById('branch-val-1-fat'); if(elVal1Fat) elVal1Fat.textContent = val1Fat.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'});
         const elVal2Fat = document.getElementById('branch-val-2-fat'); if(elVal2Fat) elVal2Fat.textContent = val2Fat.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'});
         
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
         const elVal1Kg = document.getElementById('branch-val-1-kg'); if(elVal1Kg) elVal1Kg.textContent = (val1Kg/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';
         const elVal2Kg = document.getElementById('branch-val-2-kg'); if(elVal2Kg) elVal2Kg.textContent = (val2Kg/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';

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

         const elTotalValFat = document.getElementById('branch-total-fat-val'); if(elTotalValFat) elTotalValFat.textContent = totalFat.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'});
         const elTotalValKg = document.getElementById('branch-total-kg-val'); if(elTotalValKg) elTotalValKg.textContent = (totalKg/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';


         // --- Chart Rendering ---
         const datasets = [];
         const colors = ['#06b6d4', '#f97316', '#8b5cf6', '#10b981']; 
         const trendColors = ['#c084fc', '#7e22ce']; // Lilac, Purple

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
                ? (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : ''))
                : (v) => (v && v > 1000 ? (v/1000).toFixed(0) + ' Ton' : (v ? v.toFixed(0) : ''));
             createChart('branch-chart', 'bar', labels, datasets, fmt);
         } else {
             const labels = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
             const fmt = currentBranchChartMode === 'faturamento' 
                ? (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : ''))
                : (v) => (v && v > 1000 ? (v/1000).toFixed(0) + ' Ton' : (v ? v.toFixed(0) : ''));
             createChart('branch-chart', 'bar', labels, datasets, fmt);
         }
    }

    function renderCityPaginationControls() {
        const container = document.getElementById('city-pagination-container');
        const totalPages = Math.ceil(totalActiveClients / cityPageSize);
        const startItem = (currentCityPage * cityPageSize) + 1;
        const endItem = Math.min((currentCityPage + 1) * cityPageSize, totalActiveClients);

        container.innerHTML = `
            <div class="flex justify-between items-center mt-4 px-4 text-sm text-slate-400">
                <div>Mostrando ${totalActiveClients > 0 ? startItem : 0} a ${endItem} de ${totalActiveClients}</div>
                <div class="flex gap-2">
                    <button id="city-prev-btn" class="px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50" ${currentCityPage === 0 ? 'disabled' : ''}>Anterior</button>
                    <span>${currentCityPage + 1} / ${totalPages || 1}</span>
                    <button id="city-next-btn" class="px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50" ${currentCityPage >= totalPages - 1 ? 'disabled' : ''}>Próxima</button>
                </div>
            </div>
        `;
        document.getElementById('city-prev-btn')?.addEventListener('click', () => { if(currentCityPage > 0) { currentCityPage--; loadCityView(); }});
        document.getElementById('city-next-btn')?.addEventListener('click', () => { if(currentCityPage < totalPages-1) { currentCityPage++; loadCityView(); }});
    }

    function renderCityInactivePaginationControls() {
        const container = document.getElementById('city-inactive-pagination-container');
        const totalPages = Math.ceil(totalInactiveClients / cityInactivePageSize);
        const startItem = (currentCityInactivePage * cityInactivePageSize) + 1;
        const endItem = Math.min((currentCityInactivePage + 1) * cityInactivePageSize, totalInactiveClients);

        container.innerHTML = `
            <div class="flex justify-between items-center mt-4 px-4 text-sm text-slate-400">
                <div>Mostrando ${totalInactiveClients > 0 ? startItem : 0} a ${endItem} de ${totalInactiveClients}</div>
                <div class="flex gap-2">
                    <button id="city-inactive-prev-btn" class="px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50" ${currentCityInactivePage === 0 ? 'disabled' : ''}>Anterior</button>
                    <span>${currentCityInactivePage + 1} / ${totalPages || 1}</span>
                    <button id="city-inactive-next-btn" class="px-3 py-1 bg-slate-700 rounded hover:bg-slate-600 disabled:opacity-50" ${currentCityInactivePage >= totalPages - 1 ? 'disabled' : ''}>Próxima</button>
                </div>
            </div>
        `;
        document.getElementById('city-inactive-prev-btn')?.addEventListener('click', () => { if(currentCityInactivePage > 0) { currentCityInactivePage--; loadCityView(); }});
        document.getElementById('city-inactive-next-btn')?.addEventListener('click', () => { if(currentCityInactivePage < totalPages-1) { currentCityInactivePage++; loadCityView(); }});
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

        const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

        let html = `<div class="mb-2 font-bold text-slate-300 text-center">${monthNames[month]} ${year}</div>`;
        html += `<div class="grid grid-cols-7 gap-1 text-center">`;
        
        const weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
        weekDays.forEach(day => html += `<div class="w-8 h-8 flex items-center justify-center text-xs font-bold text-slate-500 cursor-default">${day}</div>`);

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
            
            html += `<div class="${classes}" data-date="${dateStr}" title="${isLastSalesDay ? 'Última Venda' : ''}">${day}</div>`;
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
                console.log("Calendar day clicked:", el.getAttribute('data-date'));
                
                // Allow click even if role is unknown for debugging, but ideally check permissions
                if (window.userRole !== 'adm') {
                    console.warn("User role not adm:", window.userRole);
                    alert("Apenas administradores podem alterar feriados.");
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
                    console.error("Error toggling holiday:", error);
                    el.classList.toggle('selected'); // Revert
                    alert("Erro ao alterar feriado: " + error.message);
                } else {
                    console.log("Holiday toggled successfully.");
                    
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
        let comparisonRedeGroupFilter = '';
        let currentComparisonFornecedor = '';
        let useTendencyComparison = false;
        let comparisonChartType = 'weekly';
        let comparisonMonthlyMetric = 'faturamento';

        let comparisonFilterDebounceTimer;
        const handleComparisonFilterChange = () => {
            clearTimeout(comparisonFilterDebounceTimer);
            comparisonFilterDebounceTimer = setTimeout(() => {
                loadComparisonView();
            }, 500);
        };

        if (comparisonAnoFilter) comparisonAnoFilter.addEventListener('change', handleComparisonFilterChange);
        if (comparisonMesFilter) comparisonMesFilter.addEventListener('change', handleComparisonFilterChange);

        if (comparisonFilialFilter) comparisonFilialFilter.addEventListener('change', handleComparisonFilterChange);

        if (comparisonFornecedorToggleContainer) {
            comparisonFornecedorToggleContainer.addEventListener('click', (e) => {
                if (e.target.tagName === 'BUTTON') {
                    const fornecedor = e.target.dataset.fornecedor;
                    if (currentComparisonFornecedor === fornecedor) {
                        currentComparisonFornecedor = '';
                        e.target.classList.remove('active');
                    } else {
                        currentComparisonFornecedor = fornecedor;
                        comparisonFornecedorToggleContainer.querySelectorAll('.fornecedor-btn').forEach(b => b.classList.remove('active'));
                        e.target.classList.add('active');
                    }
                    handleComparisonFilterChange();
                }
            });
        }

        if (comparisonRedeGroupContainer) {
            comparisonRedeGroupContainer.addEventListener('click', (e) => {
                if (e.target.closest('button')) {
                    const button = e.target.closest('button');
                    comparisonRedeGroupFilter = button.dataset.group;
                    comparisonRedeGroupContainer.querySelectorAll('button').forEach(b => b.classList.remove('active'));
                    button.classList.add('active');
                    if (comparisonRedeGroupFilter !== 'com_rede') {
                        comparisonRedeFilterDropdown.classList.add('hidden');
                        selectedComparisonRedes = [];
                    }
                    handleComparisonFilterChange();
                }
            });
        }

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
            clearComparisonFiltersBtn.addEventListener('click', () => {
                comparisonAnoFilter.value = 'todos';
                comparisonMesFilter.value = '';
                selectedComparisonSupervisors = [];
                selectedComparisonSellers = [];
                selectedComparisonSuppliers = [];
                selectedComparisonProducts = [];
                selectedComparisonTiposVenda = [];
                selectedComparisonRedes = [];
                comparisonRedeGroupFilter = '';
                currentComparisonFornecedor = '';
                comparisonCityFilter.value = '';
                comparisonFilialFilter.value = 'ambas';

                // Reset UI active states
                comparisonFornecedorToggleContainer.querySelectorAll('.fornecedor-btn').forEach(b => b.classList.remove('active'));
                comparisonRedeGroupContainer.querySelectorAll('button').forEach(b => b.classList.remove('active'));
                comparisonRedeGroupContainer.querySelector('button[data-group=""]').classList.add('active');

                initComparisonFilters().then(loadComparisonView);
            });
        }

        document.addEventListener('click', (e) => {
            const dropdowns = [comparisonSupervisorFilterDropdown, comparisonVendedorFilterDropdown, comparisonSupplierFilterDropdown, comparisonProductFilterDropdown, comparisonTipoVendaFilterDropdown, comparisonRedeFilterDropdown];
            const btns = [comparisonSupervisorFilterBtn, comparisonVendedorFilterBtn, comparisonSupplierFilterBtn, comparisonProductFilterBtn, comparisonTipoVendaFilterBtn, comparisonComRedeBtn];
            let anyClosed = false;

            dropdowns.forEach((dd, idx) => {
                if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
                    dd.classList.add('hidden');
                    anyClosed = true;
                }
            });

            if (anyClosed) {
                // If closing Rede Filter and items are selected, update group state visually
                if (selectedComparisonRedes.length > 0 && comparisonRedeGroupFilter !== 'com_rede') {
                    comparisonRedeGroupFilter = 'com_rede';
                    if (comparisonRedeGroupContainer) {
                        comparisonRedeGroupContainer.querySelectorAll('button').forEach(b => b.classList.remove('active'));
                        if (comparisonComRedeBtn) comparisonComRedeBtn.classList.add('active');
                    }
                }
                handleComparisonFilterChange();
            }
        });

        function setupAutocomplete(input, suggestionsContainer, items) {
            if (!input || !suggestionsContainer) return;

            input.addEventListener('input', () => {
                const val = input.value.toLowerCase();
                suggestionsContainer.innerHTML = '';
                if (!val) {
                    suggestionsContainer.classList.add('hidden');
                    return;
                }

                const filtered = items.filter(i => i.toLowerCase().includes(val));
                if (filtered.length > 0) {
                    suggestionsContainer.classList.remove('hidden');
                    filtered.slice(0, 50).forEach(item => {
                        const div = document.createElement('div');
                        div.className = 'p-2 hover:bg-slate-700 cursor-pointer text-sm text-slate-200';
                        div.textContent = item;
                        div.addEventListener('click', () => {
                            input.value = item;
                            suggestionsContainer.classList.add('hidden');
                            handleComparisonFilterChange();
                        });
                        suggestionsContainer.appendChild(div);
                    });
                } else {
                    suggestionsContainer.classList.add('hidden');
                }
            });

            // Hide on outside click
            document.addEventListener('click', (e) => {
                if (e.target !== input && e.target !== suggestionsContainer) {
                    suggestionsContainer.classList.add('hidden');
                }
            });

            // Trigger filter change on manual input (debounce handled in handler)
            input.addEventListener('input', handleComparisonFilterChange);
        }

        async function initComparisonFilters() {
            const filters = {
                p_ano: 'todos',
                p_mes: null,
                p_filial: [],
                p_cidade: [],
                p_supervisor: [],
                p_vendedor: [],
                p_fornecedor: [],
                p_tipovenda: [],
                p_rede: []
            };
            const { data: filterData, error } = await supabase.rpc('get_dashboard_filters', filters);
            if (error) console.error('Error fetching comparison filters:', error);
            if (!filterData) return;

            if (filterData.anos && comparisonAnoFilter) {
                const currentVal = comparisonAnoFilter.value;
                comparisonAnoFilter.innerHTML = '<option value="todos">Todos</option>';
                filterData.anos.forEach(a => {
                    const opt = document.createElement('option');
                    opt.value = a;
                    opt.textContent = a;
                    comparisonAnoFilter.appendChild(opt);
                });
                if (currentVal && currentVal !== 'todos') comparisonAnoFilter.value = currentVal;
                else if (filterData.anos.length > 0) comparisonAnoFilter.value = filterData.anos[0];
            }

            if (comparisonMesFilter && comparisonMesFilter.options.length <= 1) {
                comparisonMesFilter.innerHTML = '<option value="">Todos</option>';
                const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
                meses.forEach((m, i) => { const opt = document.createElement('option'); opt.value = i; opt.textContent = m; comparisonMesFilter.appendChild(opt); });
            }

            try {
                // Try to find specific list containers, fallback to dropdown if not found
                const getList = (id) => document.getElementById(id);
                
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

                // Autocomplete
                setupAutocomplete(comparisonCityFilter, comparisonCitySuggestions, filterData.cidades || []);

                // Redes
                const redes = ['C/ REDE', 'S/ REDE', ...(filterData.redes || [])];
                const redeList = getList('comparison-rede-filter-list') || comparisonRedeFilterDropdown;
                setupCityMultiSelect(comparisonComRedeBtn, comparisonRedeFilterDropdown, redeList, redes, selectedComparisonRedes);
            } catch (e) {
                console.error('Error setting up comparison filters:', e);
            }
        }

        async function loadComparisonView() {
            showDashboardLoading('comparison-view');

            if (typeof initComparisonFilters === 'function' && (!comparisonSupervisorFilterDropdown.children.length || comparisonSupervisorFilterDropdown.children.length === 0)) {
                await initComparisonFilters();
            }

            const filters = {
                p_filial: comparisonFilialFilter.value === 'ambas' ? null : [comparisonFilialFilter.value],
                p_cidade: comparisonCityFilter.value ? [comparisonCityFilter.value] : null,
                p_supervisor: selectedComparisonSupervisors.length > 0 ? selectedComparisonSupervisors : null,
                p_vendedor: selectedComparisonSellers.length > 0 ? selectedComparisonSellers : null,
                p_fornecedor: selectedComparisonSuppliers.length > 0 ? selectedComparisonSuppliers : null,
                p_tipovenda: selectedComparisonTiposVenda.length > 0 ? selectedComparisonTiposVenda : null,
                p_rede: selectedComparisonRedes.length > 0 ? selectedComparisonRedes : null,
                p_ano: comparisonAnoFilter.value === 'todos' ? null : comparisonAnoFilter.value,
                p_mes: comparisonMesFilter.value === '' ? null : comparisonMesFilter.value
            };

            // Handle Special Fornecedor Toggles (Client-side UI mapped to codes for RPC)
            if (currentComparisonFornecedor) {
                if (!filters.p_fornecedor) filters.p_fornecedor = [];
                if (currentComparisonFornecedor === 'ELMA') {
                    filters.p_fornecedor.push('707', '708', '752');
                } else if (currentComparisonFornecedor === 'FOODS') {
                    filters.p_fornecedor.push('1119_TODDYNHO', '1119_TODDY', '1119_QUAKER', '1119_KEROCOCO', '1119_OUTROS');
                }
                // Note: Legacy "Pasta" logic might need clearer mapping if codes vary
            }

            const { data, error } = await supabase.rpc('get_comparison_view_data', filters);

            if (error) {
                console.error("RPC Error:", error);
                hideDashboardLoading();
                if (error.message.includes('function get_comparison_view_data') && error.message.includes('does not exist')) {
                    alert("A função 'get_comparison_view_data' não foi encontrada no banco de dados. \n\nPor favor, execute o script 'sql/comparison_view_rpc.sql' no Supabase SQL Editor para corrigir isso.");
                }
                return;
            }

            // Map RPC Data to UI format
            const metrics = mapRpcDataToMetrics(data);

            // Render KPIs
            renderKpiCards(metrics.kpis);

            // Render Charts
            renderComparisonCharts(metrics.charts);

            // Render Table
            renderSupervisorTable(metrics.supervisorData);

            hideDashboardLoading();
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

            // Trim empty tail weeks?
            // Keep it simple for now

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
                '#34d399', // Terca (Emerald)
                '#facc15', // Quarta (Yellow)
                '#fb923c', // Quinta (Orange)
                '#f87171', // Sexta (Red)
                '#a78bfa'  // Sabado (Purple)
            ];

            const datasetsDaily = dayNames.map((name, i) => ({
                label: name,
                data: dailyDataByWeek.map(weekData => weekData[i]),
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
                    weeklyCurrent,
                    weeklyHistory,
                    monthlyData,
                    dailyData: {
                        labels: ['Semana 1', 'Semana 2', 'Semana 3', 'Semana 4', 'Semana 5', 'Semana 6'],
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

                if (selectedYear && selectedYear !== 'todos') {
                    const year = parseInt(selectedYear);
                    if (selectedMonth !== '') {
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

            const datasetsDaily = dayNames.map((name, i) => ({
                label: name,
                data: dailyDataByWeek.map(weekData => weekData[i])
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
                if (format === 'currency') return val.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
                if (format === 'decimal') return val.toLocaleString('pt-BR', { minimumFractionDigits: 3 });
                if (format === 'decimal_2') return val.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
                return val.toLocaleString('pt-BR');
            };

            container.innerHTML = kpis.map(kpi => {
                const variation = kpi.history > 0 ? ((kpi.current - kpi.history) / kpi.history) * 100 : 0;
                const colorClass = variation >= 0 ? 'text-green-400' : 'text-red-400';

                // Determine glow color
                let glowClass = 'kpi-glow-blue';
                if (kpi.title.includes('Faturamento')) glowClass = 'kpi-glow-green';
                else if (kpi.title.includes('Peso')) glowClass = 'kpi-glow-blue';
                else if (kpi.title.includes('Clientes')) glowClass = 'kpi-glow-purple';

                return `<div class="kpi-card p-4 rounded-lg text-center kpi-glow-base ${glowClass}">
                            <p class="text-slate-300 text-sm">${kpi.title}</p>
                            <p class="text-2xl font-bold text-white my-2">${fmt(kpi.current, kpi.format)}</p>
                            <p class="text-sm ${colorClass}">${variation > 0 ? '+' : ''}${variation.toFixed(1)}% vs Média</p>
                            <p class="text-xs text-slate-500">Média: ${fmt(kpi.history, kpi.format)}</p>
                        </div>`;
            }).join('');
        }

        function renderComparisonCharts(chartsData) {
            // Weekly Chart
            if (comparisonChartType === 'weekly') {
                document.getElementById('monthlyComparisonChartContainer').classList.add('hidden');
                document.getElementById('weeklyComparisonChartContainer').classList.remove('hidden');

                createChart('weeklyComparisonChart', 'line',
                    chartsData.weeklyCurrent.map((_, i) => `Semana ${i+1}`),
                    [
                        { label: 'Mês Atual', data: chartsData.weeklyCurrent, borderColor: '#14b8a6', backgroundColor: '#14b8a6', tension: 0.1, isCurrent: true },
                        { label: 'Média Histórica', data: chartsData.weeklyHistory, borderColor: '#f97316', backgroundColor: '#f97316', tension: 0.1, isPrevious: true }
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
                    backgroundColor: '#06b6d4'
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

        function renderSupervisorTable(data) {
            const tbody = document.getElementById('supervisorComparisonTableBody');
            if (!tbody) return;
            tbody.innerHTML = Object.entries(data).map(([sup, vals]) => {
                const variation = vals.history > 0 ? ((vals.current - vals.history) / vals.history) * 100 : 0;
                const colorClass = variation >= 0 ? 'text-green-400' : 'text-red-400';
                return `<tr class="hover:bg-slate-700">
                            <td class="px-4 py-2">${sup}</td>
                            <td class="px-4 py-2 text-right">${vals.history.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'})}</td>
                            <td class="px-4 py-2 text-right">${vals.current.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'})}</td>
                            <td class="px-4 py-2 text-right ${colorClass}">${variation.toFixed(2)}%</td>
                        </tr>`;
            }).join('');
        }
});
