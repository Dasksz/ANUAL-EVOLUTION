
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
    // No close button explicit in new design, clicking outside handles it
    const sidebarBackdrop = document.getElementById('sidebar-backdrop');

    const navDashboardBtn = document.getElementById('nav-dashboard');
    const navCityAnalysisBtn = document.getElementById('nav-city-analysis');
    const navUploaderBtn = document.getElementById('nav-uploader');

    // Views
    const dashboardContainer = document.getElementById('dashboard-container');
    const uploaderModal = document.getElementById('uploader-modal');
    const closeUploaderBtn = document.getElementById('close-uploader-btn');

    // Dashboard Internal Views
    const mainDashboardContent = document.getElementById('main-dashboard-content');
    const cityView = document.getElementById('city-view');

    // Buttons in Dashboard
    const clearFiltersBtn = document.getElementById('clear-filters-btn');
    const calendarBtn = document.getElementById('calendar-btn'); // New Calendar Button

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
            await db.put(STORE_NAME, value, key);
        } catch (e) {
            console.warn('Erro ao salvar cache:', e);
        }
    };

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

            if (error && error.code !== 'PGRST116') throw error;

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
    sidebarBackdrop.addEventListener('click', closeSidebar);

    // Nav Links (Close sidebar on click)
    const resetViews = () => {
        dashboardContainer.classList.remove('hidden');
        uploaderModal.classList.add('hidden');
        mainDashboardContent.classList.add('hidden');
        cityView.classList.add('hidden');
        // Reset active state styles (simple)
        [navDashboardBtn, navCityAnalysisBtn, navUploaderBtn].forEach(btn => btn.classList.remove('bg-slate-700', 'text-white'));
    };

    navDashboardBtn.addEventListener('click', () => {
        resetViews();
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
    clearFiltersBtn.addEventListener('click', async () => {
        anoFilter.innerHTML = '<option value="todos">Todos</option>';
        anoFilter.value = 'todos';
        mesFilter.value = '';
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

    if(generateBtn) generateBtn.addEventListener('click', () => {
        if (!files.salesPrevYearFile || !files.salesCurrYearFile || !files.salesCurrMonthFile || !files.clientsFile || !files.productsFile) return;

        generateBtn.disabled = true;
        statusContainer.classList.remove('hidden');
        statusText.textContent = 'Processando...';
        progressBar.style.width = '0%';

        const worker = new Worker('src/js/worker.js');
        worker.postMessage(files);

        worker.onmessage = async (event) => {
            const { type, data, status, percentage, message } = event.data;
            if (type === 'progress') {
                statusText.textContent = status;
                progressBar.style.width = `${percentage}%`;
            } else if (type === 'result') {
                statusText.textContent = 'Upload...';
                try {
                    await enviarDadosParaSupabase(data);
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

        const BATCH_SIZE = 1000;
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

    async function initDashboard() {
        const filters = getCurrentFilters();
        await loadFilters(filters);
        await loadMainDashboardData();
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
        const { data, error } = await supabase.rpc('get_dashboard_filters', currentFilters);
        if (error) {
            if (retryCount < 1) {
                 await new Promise(r => setTimeout(r, 1000));
                 return loadFilters(currentFilters, retryCount + 1);
            }
            return;
        }
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
            try { await loadFilters(filters); } catch (err) { console.error("Failed to load filters:", err); }
            try { await loadMainDashboardData(); } catch (err) { console.error("Failed to load dashboard data:", err); }
            if (!cityView.classList.contains('hidden')) { currentCityPage = 0; currentCityInactivePage = 0; await loadCityView(); }
        }, 500);
    };
    anoFilter.onchange = handleFilterChange;
    mesFilter.onchange = handleFilterChange;

    async function loadMainDashboardData() {
        const filters = getCurrentFilters();
        const cacheKey = `dashboard_data_${JSON.stringify(filters)}`;
        const cachedData = await getFromCache(cacheKey);
        if (cachedData) renderDashboard(cachedData);

        const { data, error } = await supabase.rpc('get_main_dashboard_data', filters);
        if (error) { console.error('Error fetching dashboard data:', error); return; }

        await saveToCache(cacheKey, data);
        renderDashboard(data);
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

        if (mesFilter.value !== '') {
            const selectedMonthIndex = parseInt(mesFilter.value);
            currentData = currentData.filter(d => d.month_index === selectedMonthIndex);
            previousData = previousData.filter(d => d.month_index === selectedMonthIndex);
        }

        const targetIndex = data.target_month_index;
        const currMonthData = currentData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };
        const prevMonthData = previousData.find(d => d.month_index === targetIndex) || { faturamento: 0, peso: 0 };

        const calcEvo = (curr, prev) => prev > 0 ? ((curr / prev) - 1) * 100 : (curr > 0 ? 100 : 0);
        updateKpi('kpi-evo-vs-ano-fat', calcEvo(currMonthData.faturamento, prevMonthData.faturamento));
        updateKpi('kpi-evo-vs-ano-kg', calcEvo(currMonthData.peso, prevMonthData.peso));

        // Trimestral
        let triSumFat = 0, triSumPeso = 0, triCount = 0;
        for (let i = 1; i <= 3; i++) {
            const idx = targetIndex - i;
            const mData = currentData.find(d => d.month_index === idx);
            if (mData) { triSumFat += mData.faturamento; triSumPeso += mData.peso; triCount++; }
        }
        const triAvgFat = triCount > 0 ? triSumFat / triCount : 0;
        const triAvgPeso = triCount > 0 ? triSumPeso / triCount : 0;
        updateKpi('kpi-evo-vs-tri-fat', calcEvo(currMonthData.faturamento, triAvgFat));
        updateKpi('kpi-evo-vs-tri-kg', calcEvo(currMonthData.peso, triAvgPeso));

        const monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
        const mName = monthNames[targetIndex]?.toUpperCase() || "";
        document.getElementById('kpi-title-evo-ano-fat').textContent = `FAT ${mName} vs Ano Ant.`;
        document.getElementById('kpi-title-evo-ano-kg').textContent = `TON ${mName} vs Ano Ant.`;

        // Chart Data Prep
        const mapTo12 = (arr) => { const res = new Array(12).fill(0); arr.forEach(d => res[d.month_index] = d.faturamento); return res; };

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

            trendArray[12] = data.trend_data.faturamento; // Use 13th slot

            datasets.push({
                label: `Tendência ${monthNames[data.trend_data.month_index]}`,
                data: trendArray,
                isTrend: true
            });
        }

        const chartLabels = [...monthNames];
        if (data.trend_allowed) chartLabels.push('Tendência');

        createChart('main-chart', 'bar', chartLabels, datasets);
        updateTable(currentData, previousData, data.current_year, data.previous_year, data.trend_allowed ? data.trend_data : null);
    }

    function updateKpi(id, value) {
        const el = document.getElementById(id);
        el.textContent = `${value.toFixed(1)}%`;
        el.className = `text-2xl font-bold ${value >= 0 ? 'text-green-400' : 'text-red-400'}`;
    }

    function createChart(canvasId, type, labels, datasetsData) {
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
                label: d.label,
                data: d.data,
                backgroundColor: color,
                borderColor: color,
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
                        formatter: (v) => (v && v > 1000 ? (v/1000).toFixed(0) + 'k' : (v ? v.toFixed(0) : ''))
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
