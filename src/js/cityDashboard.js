import supabase from './supabase.js?v=3';
import {
    generateYearOptionsHtml,
    generateMonthOptionsHtml,
    formatPercentage,
    escapeHtml,
    formatCurrency,
    handleDropdownsClickaway,
    clearArrays
} from './utils.js';

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
let currentCityPage = 0;
let cityPageSize = 250;
let totalActiveClients = 0;

export function initCityDashboard() {
    const cityView = document.getElementById('city-view');
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
             clearArrays(citySelectedFiliais, citySelectedCidades, citySelectedSupervisores, citySelectedVendedores, citySelectedFornecedores, citySelectedTiposVenda, citySelectedRedes, citySelectedCategorias);
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
         if (error) console.error('Error fetching city filters:', error);
         if (!filterData) return;

         if (filterData.anos && cityAnoFilter) {
             const currentVal = cityAnoFilter.value;
             cityAnoFilter.innerHTML = generateYearOptionsHtml(filterData.anos);
             if (currentVal && currentVal !== 'todos') cityAnoFilter.value = currentVal;
             else if (filterData.anos.length > 0) cityAnoFilter.value = filterData.anos[0];
             window.enhanceSelectToCustomDropdown(cityAnoFilter);
         }
         
         if (cityMesFilter && cityMesFilter.options.length <= 1) {
            cityMesFilter.innerHTML = generateMonthOptionsHtml('Todos', '', false);
            window.enhanceSelectToCustomDropdown(cityMesFilter);
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

    function renderCityPaginationControls() {
        const paginationContainer = document.getElementById('city-pagination');
        if (!paginationContainer) return;
        
        const totalPages = Math.ceil(totalActiveClients / cityPageSize);
        if (totalPages <= 1) {
             paginationContainer.innerHTML = '';
             return;
        }

        const prevDisabled = currentCityPage === 0;
        const nextDisabled = currentCityPage >= totalPages - 1;

        paginationContainer.innerHTML = `
            <div class="flex items-center gap-2 mt-4 justify-center">
                <button class="px-3 py-1 bg-slate-800 text-slate-300 rounded hover:bg-slate-700 disabled:opacity-50 transition-colors" ${prevDisabled ? 'disabled title="Primeira página"' : ''} id="city-prev-page">Anterior</button>
                <span class="text-sm text-slate-400">Página ${currentCityPage + 1} de ${totalPages}</span>
                <button class="px-3 py-1 bg-slate-800 text-slate-300 rounded hover:bg-slate-700 disabled:opacity-50 transition-colors" ${nextDisabled ? 'disabled title="Última página"' : ''} id="city-next-page">Próxima</button>
            </div>
        `;

        document.getElementById('city-prev-page')?.addEventListener('click', () => {
             if (currentCityPage > 0) {
                 currentCityPage--;
                 loadCityView();
             }
        });
        
        document.getElementById('city-next-page')?.addEventListener('click', () => {
             if (currentCityPage < totalPages - 1) {
                 currentCityPage++;
                 loadCityView();
             }
        });
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

        if(error) { console.error(error); return; }

        totalActiveClients = data.total_active_count || 0;

        const mapRows = (dataObj) => {
             if (!dataObj || !dataObj.cols || !dataObj.rows) return dataObj || []; 
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
                            <td class="p-2 text-right text-cyan-400 font-bold">${escapeHtml(formatPercentage(c['% Share'], 2))}</td>
                            <td class="p-2 text-right font-bold ${varClass}">${varArrow} ${escapeHtml(formatPercentage(Math.abs(c['Variação']), 2))}</td>
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

    const state = {
        citySelectedFiliais,
        citySelectedCidades,
        citySelectedSupervisores,
        citySelectedVendedores,
        citySelectedFornecedores,
        citySelectedTiposVenda,
        citySelectedRedes,
        citySelectedCategorias
    };

    return {
        loadCityView,
        initCityFilters,
        state
    };
}
