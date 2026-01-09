
import supabase from './supabase.js';

document.addEventListener('DOMContentLoaded', () => {
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
    const openSidebarBranchBtn = document.getElementById('open-sidebar-branch-btn'); // Branch Header Hamburger
    const openSidebarCityBtn = document.getElementById('open-sidebar-city-btn'); // City Header Hamburger
    // No close button explicit in new design, clicking outside handles it
    const sidebarBackdrop = document.getElementById('sidebar-backdrop');
    
    const navDashboardBtn = document.getElementById('nav-dashboard');
    const navCityAnalysisBtn = document.getElementById('nav-city-analysis');
    const navBranchBtn = document.getElementById('nav-branch-btn');
    const navUploaderBtn = document.getElementById('nav-uploader');

    // Views
    const dashboardContainer = document.getElementById('dashboard-container');
    const uploaderModal = document.getElementById('uploader-modal');
    const closeUploaderBtn = document.getElementById('close-uploader-btn');

    // Dashboard Internal Views
    const mainDashboardHeader = document.getElementById('main-dashboard-header');
    const mainDashboardContent = document.getElementById('main-dashboard-content');
    const cityView = document.getElementById('city-view');
    const branchView = document.getElementById('branch-view');

    // Buttons in Dashboard
    const clearFiltersBtn = document.getElementById('clear-filters-btn');
    const calendarBtn = document.getElementById('calendar-btn'); // New Calendar Button
    const chartToggleBtn = document.getElementById('chart-toggle-btn'); // Chart Mode Toggle

    // Calendar Modal Elements
    const calendarModal = document.getElementById('calendar-modal');
    const calendarModalBackdrop = document.getElementById('calendar-modal-backdrop');
    const closeCalendarModalBtn = document.getElementById('close-calendar-modal-btn');
    const calendarModalContent = document.getElementById('calendar-modal-content');

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
                    showScreen('app-layout');
                    initDashboard();
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
                    showScreen('app-layout');
                    initDashboard();
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
                    showScreen('app-layout');
                    initDashboard();
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
    sidebarBackdrop.addEventListener('click', closeSidebar);

    // Nav Links (Close sidebar on click)
    const resetViews = () => {
        dashboardContainer.classList.remove('hidden');
        uploaderModal.classList.add('hidden');
        mainDashboardHeader.classList.add('hidden');
        mainDashboardContent.classList.add('hidden');
        cityView.classList.add('hidden');
        branchView.classList.add('hidden');
        // Reset active state styles (simple)
        [navDashboardBtn, navCityAnalysisBtn, navBranchBtn, navUploaderBtn].forEach(btn => btn?.classList.remove('bg-slate-700', 'text-white'));
    };

    navDashboardBtn.addEventListener('click', () => {
        resetViews();
        mainDashboardHeader.classList.remove('hidden');
        mainDashboardContent.classList.remove('hidden');
        navDashboardBtn.classList.add('bg-slate-700', 'text-white');
        closeSidebar();
    });

    navCityAnalysisBtn.addEventListener('click', () => {
        resetViews();
        cityView.classList.remove('hidden');
        navCityAnalysisBtn.classList.add('bg-slate-700', 'text-white');
        loadCityView();
        closeSidebar();
    });

    if (navBranchBtn) {
        navBranchBtn.addEventListener('click', () => {
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
        
        const worker = new Worker('src/js/worker.js');
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
        const performUpsert = async (table, batch) => {
            const { error } = await supabase.from(table).insert(batch);
            if (error) throw new Error(`Erro ${table}: ${error.message}`);
        };
        const clearTable = async (table) => {
            const { error } = await supabase.rpc('truncate_table', { table_name: table });
            if (error) throw new Error(`Erro clear ${table}: ${error.message}`);
        };

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
            if (data.history?.length) { updateStatus('Limpar hist...', 10); await clearTable('data_history'); await uploadBatch('data_history', data.history); }
            if (data.detailed?.length) { updateStatus('Limpar det...', 40); await clearTable('data_detailed'); await uploadBatch('data_detailed', data.detailed); }
            if (data.clients?.length) { updateStatus('Limpar cli...', 70); await clearTable('data_clients'); await uploadBatch('data_clients', data.clients); }

            updateStatus('Atualizando cache...', 90);
            await supabase.rpc('refresh_cache_filters');
            await supabase.rpc('refresh_cache_summary');

        } catch (error) {
            console.error(error);
            throw error;
        }
    }

    // --- Dashboard Data Logic ---

    // Filter Elements
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
    let currentCharts = {};
    let holidays = [];
    let currentChartMode = 'faturamento'; // 'faturamento' or 'peso'
    let lastDashboardData = null;

    // Prefetch State
    let availableFiltersState = { filiais: [], supervisors: [], cidades: [], vendedores: [], fornecedores: [], tipos_venda: [] };
    let prefetchQueue = [];
    let isPrefetching = false;

    // --- Loading Helpers ---
    const showDashboardLoading = () => {
        const container = document.getElementById('main-dashboard-content');
        let overlay = document.getElementById('dashboard-loading-overlay');

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
    };

    const hideDashboardLoading = () => {
        const overlay = document.getElementById('dashboard-loading-overlay');
        if (overlay) overlay.classList.add('hidden');
    };

    async function initDashboard() {
        showDashboardLoading();
        await checkDataVersion(); // Check for invalidation first

        const filters = getCurrentFilters();
        await loadFilters(filters);
        await loadMainDashboardData();
        
        // Trigger background prefetch after main load
        setTimeout(() => {
            // queueCommonFilters();
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
            p_tipovenda: selectedTiposVenda
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
            filteredItems.forEach(item => {
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
                    handleFilterChange();
                };
                container.appendChild(div);
            });
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
        if (searchInput) { searchInput.oninput = (e) => renderItems(e.target.value); searchInput.onclick = (e) => e.stopPropagation(); }
    }

    function applyFiltersData(data) {
        // Capture available options for prefetcher
        availableFiltersState.filiais = data.filiais || [];
        availableFiltersState.supervisors = data.supervisors || [];
        availableFiltersState.cidades = data.cidades || [];
        availableFiltersState.vendedores = data.vendedores || [];
        availableFiltersState.fornecedores = data.fornecedores || []; // Array of objects
        availableFiltersState.tipos_venda = data.tipos_venda || [];

        const updateSingleSelect = (element, items) => {
            const currentVal = element.value;
            element.innerHTML = '';
            const allOpt = document.createElement('option');
            allOpt.value = (element.id === 'ano-filter') ? 'todos' : '';
            allOpt.textContent = 'Todos';
            element.appendChild(allOpt);
            if (items) { items.forEach(item => { const opt = document.createElement('option'); opt.value = item; opt.textContent = item; element.appendChild(opt); }); }
            if (currentVal && Array.from(element.options).some(o => o.value === currentVal)) element.value = currentVal;
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
    }

    document.addEventListener('click', (e) => {
        const dropdowns = [filialFilterDropdown, cidadeFilterDropdown, supervisorFilterDropdown, vendedorFilterDropdown, fornecedorFilterDropdown, tipovendaFilterDropdown];
        const btns = [filialFilterBtn, cidadeFilterBtn, supervisorFilterBtn, vendedorFilterBtn, fornecedorFilterBtn, tipovendaFilterBtn];
        dropdowns.forEach((dd, idx) => { if (!dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx].contains(e.target)) dd.classList.add('hidden'); });
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
    async function fetchDashboardData(filters, isBackground = false) {
        const cacheKey = generateCacheKey('dashboard_data', filters);
        const CACHE_TTL = 1000 * 60 * 10; // 10 minutes TTL

        // 1. Try Cache
        try {
            const cachedEntry = await getFromCache(cacheKey);
            if (cachedEntry && cachedEntry.timestamp && cachedEntry.data) {
                const age = Date.now() - cachedEntry.timestamp;
                if (age < CACHE_TTL) {
                    if (!isBackground) console.log('Serving from Cache (Instant)');
                    return { data: cachedEntry.data, source: 'cache' };
                }
            }
        } catch (e) { console.warn('Cache error:', e); }

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

    async function loadMainDashboardData() {
        const filters = getCurrentFilters();
        
        showDashboardLoading();

        const { data, source } = await fetchDashboardData(filters);
        
        if (data) {
            lastDashboardData = data;
            renderDashboard(data);
        }
        
        hideDashboardLoading();
    }

    // --- Background Prefetch Logic ---

    function queueCommonFilters() {
        console.log('[Background] Iniciando estratégia de pré-carregamento massivo...');
        const currentFilters = getCurrentFilters();
        const baseFilters = {
            p_ano: currentFilters.p_ano,
            p_mes: currentFilters.p_mes,
            p_filial: [], p_cidade: [], p_supervisor: [], p_vendedor: [], p_fornecedor: [], p_tipovenda: []
        };
        
        // Strategy: Pre-fetch "One Dimensional" filters (most common drill-down)
        
        // 1. Filiais
        availableFiltersState.filiais.forEach(v => addToPrefetchQueue(`Filial: ${v}`, { ...baseFilters, p_filial: [v] }));

        // 2. Supervisors
        availableFiltersState.supervisors.forEach(v => addToPrefetchQueue(`Superv: ${v}`, { ...baseFilters, p_supervisor: [v] }));

        // 3. Cidades
        availableFiltersState.cidades.forEach(v => addToPrefetchQueue(`Cidade: ${v}`, { ...baseFilters, p_cidade: [v] }));

        // 4. Vendedores
        availableFiltersState.vendedores.forEach(v => addToPrefetchQueue(`Vend: ${v}`, { ...baseFilters, p_vendedor: [v] }));

        // 5. Fornecedores (Handle Object Structure)
        availableFiltersState.fornecedores.forEach(v => {
            const cod = v.cod || v; // Handle if object or raw
            addToPrefetchQueue(`Forn: ${cod}`, { ...baseFilters, p_fornecedor: [String(cod)] });
        });

        // 6. Tipos Venda
        availableFiltersState.tipos_venda.forEach(v => addToPrefetchQueue(`Tipo: ${v}`, { ...baseFilters, p_tipovenda: [v] }));
        
        console.log(`[Background] ${prefetchQueue.length} filtros agendados.`);
        processQueue();
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

            currFat = currSums.faturamento;
            currKg = currSums.peso;
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
        
        // Data Mapping Helper based on Mode
        const getDataValue = (d) => currentChartMode === 'faturamento' ? d.faturamento : d.peso;
        
        // Formatters
        const currencyFormatter = (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : ''));
        const weightFormatter = (v) => (v && v > 1000 ? (v/1000).toFixed(0) + ' Ton' : (v ? v.toFixed(0) : ''));
        const currentFormatter = currentChartMode === 'faturamento' ? currencyFormatter : weightFormatter;

        if (currentChartMode === 'faturamento') {
            mainChartTitle.textContent = "FATURAMENTO MENSAL";
        } else {
            mainChartTitle.textContent = "TONELAGEM MENSAL";
        }

        const mapTo12 = (arr) => { 
            const res = new Array(12).fill(0); 
            arr.forEach(d => res[d.month_index] = getDataValue(d)); 
            return res; 
        };
        
        const datasets = [];

        // Only show previous year if "Todos" is selected (Default View)
        if (anoFilter.value === 'todos') {
            datasets.push({ label: `Ano ${data.previous_year}`, data: mapTo12(previousData), isPrevious: true });
        }

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
            { name: 'DEVOLUÇÃO', key: 'devolucao', fmt: v => `<span class="text-red-400">${v.toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'})}</span>` },
            { name: 'TON VENDIDA', key: 'peso', fmt: v => `${(v/1000).toFixed(2)} Kg` }
        ];

        indicators.forEach(ind => {
            let rowHTML = `<tr class="table-row"><td class="font-bold p-2 text-left">${ind.name}</td>`;
            for(let i=0; i<12; i++) {
                const d = currData.find(x => x.month_index === i) || { [ind.key]: 0 };
                const val = d[ind.key] || 0;
                rowHTML += `<td class="px-2 py-1.5 text-center">${ind.fmt(val)}</td>`;
            }
            if (trendData) {
                 const tVal = trendData[ind.key] || 0;
                 rowHTML += `<td class="px-2 py-1.5 text-center font-bold text-purple-300 bg-purple-900/20">${ind.fmt(tVal)}</td>`;
            }
            rowHTML += '</tr>';
            tableBody.innerHTML += rowHTML;
        });
    }

    async function loadCityView() {
        const filters = getCurrentFilters();
        filters.p_page = currentCityPage;
        filters.p_limit = cityPageSize;
        filters.p_inactive_page = currentCityInactivePage;
        filters.p_inactive_limit = cityInactivePageSize;

        const { data, error } = await supabase.rpc('get_city_view_data', filters);
        if(error) { console.error(error); return; }

        totalActiveClients = data.total_active_count || 0;
        totalInactiveClients = data.total_inactive_count || 0;

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

        renderTable('city-active-detail-table-body', data.active_clients);
        renderTable('city-inactive-detail-table-body', data.inactive_clients);

        renderCityPaginationControls();
        renderCityInactivePaginationControls();
    }

    // --- Branch View Logic ---
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
    const branchTipovendaFilterBtn = document.getElementById('branch-tipovenda-filter-btn');
    const branchTipovendaFilterDropdown = document.getElementById('branch-tipovenda-filter-dropdown');
    const branchClearFiltersBtn = document.getElementById('branch-clear-filters-btn');

    let branchSelectedCidades = [];
    let branchSelectedSupervisores = [];
    let branchSelectedVendedores = [];
    let branchSelectedFornecedores = [];
    let branchSelectedTiposVenda = [];

    // Filter Change Handler
    let branchFilterDebounceTimer;
    const handleBranchFilterChange = () => {
        clearTimeout(branchFilterDebounceTimer);
        branchFilterDebounceTimer = setTimeout(loadBranchView, 500);
    };

    if (branchAnoFilter) branchAnoFilter.addEventListener('change', handleBranchFilterChange);
    if (branchMesFilter) branchMesFilter.addEventListener('change', handleBranchFilterChange);

    document.addEventListener('click', (e) => {
        const dropdowns = [branchCidadeFilterDropdown, branchSupervisorFilterDropdown, branchVendedorFilterDropdown, branchFornecedorFilterDropdown, branchTipovendaFilterDropdown];
        const btns = [branchCidadeFilterBtn, branchSupervisorFilterBtn, branchVendedorFilterBtn, branchFornecedorFilterBtn, branchTipovendaFilterBtn];
        dropdowns.forEach((dd, idx) => { if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx].contains(e.target)) dd.classList.add('hidden'); });
    });
    
    branchClearFiltersBtn?.addEventListener('click', () => {
         branchAnoFilter.value = 'todos';
         branchMesFilter.value = '';
         branchSelectedCidades = [];
         branchSelectedSupervisores = [];
         branchSelectedVendedores = [];
         branchSelectedFornecedores = [];
         branchSelectedTiposVenda = [];
         // Re-init filters to update UI
         initBranchFilters().then(loadBranchView);
    });

    function setupBranchMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
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
            filteredItems.forEach(item => {
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
                    handleBranchFilterChange();
                };
                container.appendChild(div);
            });
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
        if (searchInput) { searchInput.oninput = (e) => renderItems(e.target.value); searchInput.onclick = (e) => e.stopPropagation(); }
    }

    async function initBranchFilters() {
         const { data: filterData } = await supabase.rpc('get_dashboard_filters', { p_ano: 'todos' });
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
        setupBranchMultiSelect(branchCidadeFilterBtn, branchCidadeFilterDropdown, branchCidadeFilterList, filterData.cidades, branchSelectedCidades, branchCidadeFilterSearch);
        setupBranchMultiSelect(branchSupervisorFilterBtn, branchSupervisorFilterDropdown, branchSupervisorFilterDropdown, filterData.supervisors, branchSelectedSupervisores);
        setupBranchMultiSelect(branchVendedorFilterBtn, branchVendedorFilterDropdown, branchVendedorFilterList, filterData.vendedores, branchSelectedVendedores, branchVendedorFilterSearch);
        setupBranchMultiSelect(branchFornecedorFilterBtn, branchFornecedorFilterDropdown, branchFornecedorFilterList, filterData.fornecedores, branchSelectedFornecedores, branchFornecedorFilterSearch, true);
        setupBranchMultiSelect(branchTipovendaFilterBtn, branchTipovendaFilterDropdown, branchTipovendaFilterDropdown, filterData.tipos_venda, branchSelectedTiposVenda);
    }
    
    // Patch setupMultiSelect to support custom handler?
    // Instead of modifying setupMultiSelect which is used by main dashboard, I will create a specific setup helper for branch or just duplicate the logic slightly modified.
    // Or better: I can assign the global handleFilterChange to be context aware? No.
    // I will redefine setupMultiSelect parameters to accept a callback for change.
    // But I cannot easily change the existing function without breaking main dashboard usage unless I update all calls.
    // I will duplicate the logic for Branch MultiSelects to be safe and quick.
    
    function setupBranchMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
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
            filteredItems.forEach(item => {
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
                    handleBranchFilterChange();
                };
                container.appendChild(div);
            });
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
        if (searchInput) { searchInput.oninput = (e) => renderItems(e.target.value); searchInput.onclick = (e) => e.stopPropagation(); }
    }

    async function loadBranchView() {
        showDashboardLoading();

        // Ensure filters are populated (branches list needed)
        let branchList = availableFiltersState.filiais;
        if (!branchList || branchList.length === 0) {
             const { data: filterData } = await supabase.rpc('get_dashboard_filters', { p_ano: 'todos' });
             if (filterData) {
                 branchList = filterData.filiais || [];
                 availableFiltersState.filiais = branchList; // Cache it
             }
        }
        
        // Populate Dropdowns if needed (Check every time to ensure UI is ready)
        if (branchAnoFilter.options.length <= 1) {
            await initBranchFilters(); 
        }

        // Prepare Filters for RPC
        const selectedYear = branchAnoFilter.value === 'todos' ? null : branchAnoFilter.value; // String for RPC
        const selectedMonth = branchMesFilter.value === '' ? null : branchMesFilter.value; // String for RPC (0-11)

        const rpcFilters = {
            p_ano: selectedYear,
            p_mes: selectedMonth,
            p_cidade: branchSelectedCidades.length > 0 ? branchSelectedCidades : null,
            p_supervisor: branchSelectedSupervisores.length > 0 ? branchSelectedSupervisores : null,
            p_vendedor: branchSelectedVendedores.length > 0 ? branchSelectedVendedores : null,
            p_fornecedor: branchSelectedFornecedores.length > 0 ? branchSelectedFornecedores : null,
            p_tipovenda: branchSelectedTiposVenda.length > 0 ? branchSelectedTiposVenda : null
        };

        const branchDataMap = {};
        const branchesToFetch = branchList || [];

        // Parallel Fetch for each branch
        try {
            await Promise.all(branchesToFetch.map(async (branch) => {
                const branchFilters = { ...rpcFilters, p_filial: [branch] };
                const { data, error } = await supabase.rpc('get_main_dashboard_data', branchFilters);
                if (!error && data) {
                    branchDataMap[branch] = data;
                } else {
                    console.error(`Erro ao carregar filial ${branch}:`, error);
                }
            }));
        } catch (e) {
            console.error("Erro geral no fetch de filiais:", e);
        }
        
        hideDashboardLoading();
        renderBranchDashboard(branchDataMap, selectedYear, selectedMonth);
    }

    function renderBranchDashboard(branchDataMap, selectedYear, selectedMonth) {
         const now = new Date();
         const branches = Object.keys(branchDataMap).sort();
         const kpiBranches = {}; 
         const chartBranches = {};

         // Process Data from RPC Results
         branches.forEach(b => {
             const data = branchDataMap[b];
             const monthlyData = data.monthly_data_current || [];
             
             // Chart Data: Map to 12 months array
             const chartArr = new Array(12).fill(0);
             monthlyData.forEach(d => {
                 // d has month_index (0-11)
                 if (d.month_index >= 0 && d.month_index < 12) {
                     chartArr[d.month_index] = d.faturamento; 
                 }
             });
             chartBranches[b] = chartArr;

             // KPI Data
             let kpiFat = 0;
             let kpiKg = 0;

             if (!selectedYear || selectedYear === 'todos') {
                 // "Todos" -> Current Month (of Current Year)
                 const targetMonthIdx = now.getMonth();
                 const mData = monthlyData.find(d => d.month_index === targetMonthIdx);
                 if (mData) {
                     kpiFat = mData.faturamento || 0;
                     kpiKg = mData.peso || 0;
                 }
             } else {
                 // Specific Year -> Sum of returned monthly data
                 monthlyData.forEach(d => {
                     kpiFat += (d.faturamento || 0);
                     kpiKg += (d.peso || 0);
                 });
             }
             
             kpiBranches[b] = { faturamento: kpiFat, peso: kpiKg };
         });

         // --- KPI Rendering ---
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
         
         let diffFat = 0;
         if (val2Fat > 0) diffFat = ((val1Fat / val2Fat) - 1) * 100;
         const elDiffFat = document.getElementById('branch-diff-fat');
         if(elDiffFat) {
             elDiffFat.textContent = `${diffFat > 0 ? '+' : ''}${diffFat.toFixed(1)}% (${b1} vs ${b2})`;
             elDiffFat.className = `font-bold ${diffFat >= 0 ? 'text-emerald-400' : 'text-red-400'}`;
         }

         const elB1NameKg = document.getElementById('branch-name-1-kg'); if(elB1NameKg) elB1NameKg.textContent = b1;
         const elB2NameKg = document.getElementById('branch-name-2-kg'); if(elB2NameKg) elB2NameKg.textContent = b2;
         const elVal1Kg = document.getElementById('branch-val-1-kg'); if(elVal1Kg) elVal1Kg.textContent = (val1Kg/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';
         const elVal2Kg = document.getElementById('branch-val-2-kg'); if(elVal2Kg) elVal2Kg.textContent = (val2Kg/1000).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + ' Ton';

         let diffKg = 0;
         if (val2Kg > 0) diffKg = ((val1Kg / val2Kg) - 1) * 100;
         const elDiffKg = document.getElementById('branch-diff-kg');
         if(elDiffKg) {
             elDiffKg.textContent = `${diffKg > 0 ? '+' : ''}${diffKg.toFixed(1)}% (${b1} vs ${b2})`;
             elDiffKg.className = `font-bold ${diffKg >= 0 ? 'text-emerald-400' : 'text-red-400'}`;
         }
         
         // Update Title Context
         const kpiContext = (!selectedYear || selectedYear === 'todos') ? `Mês Atual (${now.toLocaleDateString('pt-BR', { month: 'long' })})` : `Ano ${selectedYear}`;
         const elTitleFat = document.getElementById('branch-kpi-title-fat'); if(elTitleFat) elTitleFat.textContent = `Faturamento (${kpiContext})`;
         const elTitleKg = document.getElementById('branch-kpi-title-kg'); if(elTitleKg) elTitleKg.textContent = `Tonelagem (${kpiContext})`;


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
         const isCurrentYear = (chartYear === now.getFullYear());
         
         if (isCurrentYear) {
             branches.forEach((b, idx) => {
                 const bData = branchDataMap[b];
                 if (bData && bData.trend_allowed && bData.trend_data) {
                     const tVal = bData.trend_data.faturamento || 0; 
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
             createChart('branch-chart', 'bar', labels, datasets, (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : '')));
         } else {
             const labels = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
             createChart('branch-chart', 'bar', labels, datasets, (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : '')));
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
        const year = now.getFullYear();
        const month = now.getMonth();
        
        const firstDay = new Date(year, month, 1);
        const lastDay = new Date(year, month + 1, 0);
        
        const daysInMonth = lastDay.getDate();
        const startingDay = firstDay.getDay(); // 0 = Sunday

        const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

        let html = `<div class="mb-2 font-bold text-slate-300 text-center">${monthNames[month]} ${year}</div>`;
        html += `<div class="grid grid-cols-7 gap-1 text-center">`;
        
        const weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
        weekDays.forEach(day => html += `<div class="calendar-day header">${day}</div>`);

        // Empty cells for starting day
        for (let i = 0; i < startingDay; i++) {
            html += `<div></div>`;
        }

        // Days
        for (let day = 1; day <= daysInMonth; day++) {
            const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const isHoliday = holidays.includes(dateStr);
            const isToday = day === now.getDate();
            
            let classes = 'calendar-day';
            if (isHoliday) classes += ' selected';
            if (isToday) classes += ' today';
            
            html += `<div class="${classes}" data-date="${dateStr}">${day}</div>`;
        }
        
        html += `</div>`;
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
                    // Reload Data to update trend
                    loadMainDashboardData();
                }
            });
        });
    }
});
