import re

with open('src/js/app.js', 'r', encoding='utf-8') as f:
    content = f.read()

# State variables
estrelas_state = """
let estrelasSelectedFiliais = [];
let estrelasSelectedCidades = [];
let estrelasSelectedSupervisors = [];
let estrelasSelectedVendedores = [];
let estrelasSelectedFornecedores = [];
let estrelasSelectedTiposVenda = [];
let estrelasSelectedRedes = [];
let estrelasSelectedCategorias = [];
"""
content = content.replace("let lpSelectedRedes = [];\n\nlet lpSelectedCidades = [];", "let lpSelectedRedes = [];\n\nlet lpSelectedCidades = [];\n" + estrelas_state)

# getFiltersFromActiveView
estrelas_get_filters = """        } else if (view === 'estrelas') {
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
"""
content = content.replace("} else if (view === 'loja-perfeita') {", estrelas_get_filters + "} else if (view === 'loja-perfeita') {")

# applyFiltersToView
estrelas_apply_filters = """        } else if (view === 'estrelas') {
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
"""
content = content.replace("} else if (view === 'loja-perfeita') {", estrelas_apply_filters + "} else if (view === 'loja-perfeita') {")

# Valid views array
content = content.replace("const validViews = ['dashboard', 'city', 'boxes', 'branch', 'comparison', 'innovations', 'loja-perfeita'];", "const validViews = ['dashboard', 'city', 'boxes', 'branch', 'comparison', 'innovations', 'loja-perfeita', 'estrelas'];")

# Append Estrelas logic to the end of the file
estrelas_logic = """
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
    let anyClosed = false;

    dropdowns.forEach((dd, idx) => {
        if (dd && !dd.classList.contains('hidden') && !dd.contains(e.target) && !btns[idx]?.contains(e.target)) {
            dd.classList.add('hidden');
            anyClosed = true;
        }
    });

    const view = document.getElementById('estrelas-view');
    if (anyClosed && view && !view.classList.contains('hidden')) {
        handleEstrelasFilterChange();
    }
});


const setupEstrelasFilters = async () => {
    if (isEstrelasInitialized) return;

    // We can use the dashboard overlay
    const overlay = document.getElementById('dashboard-loading-overlay');
    if (overlay) overlay.classList.remove('hidden');

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
        console.error(e);
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

    if (anoSelect && filterData.anos) {
        anoSelect.innerHTML = '<option value="todos">Todos</option>';
        filterData.anos.forEach(ano => {
            anoSelect.innerHTML += `<option value="${ano}">${ano}</option>`;
        });

        let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
        anoSelect.value = hasYear ? currentYear : 'todos';

        if(typeof enhanceSelectToCustomDropdown === 'function') enhanceSelectToCustomDropdown(anoSelect);
        anoSelect.addEventListener('change', handleEstrelasFilterChange);
    }

    if (mesSelect) {
        mesSelect.innerHTML = '<option value="">Todos</option>';
        const meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
        meses.forEach((m, i) => {
            const opt = document.createElement('option');
            const val = String(i + 1).padStart(2, '0');
            opt.value = val;
            opt.textContent = m;
            mesSelect.appendChild(opt);
        });

        mesSelect.value = currentMonth;
        mesSelect.dispatchEvent(new Event('change', { bubbles: true }));

        if(typeof enhanceSelectToCustomDropdown === 'function') enhanceSelectToCustomDropdown(mesSelect);
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
    if (!isEstrelasInitialized) {
        await setupEstrelasFilters();
    }
    updateEstrelasView();
}

async function updateEstrelasView() {
    // Placeholder for future data loading
    console.log("Estrelas view updated with filters", {
        ano: document.getElementById('estrelas-ano-filter')?.value,
        mes: document.getElementById('estrelas-mes-filter')?.value,
        filiais: estrelasSelectedFiliais,
        cidades: estrelasSelectedCidades,
        supervisores: estrelasSelectedSupervisors,
        vendedores: estrelasSelectedVendedores,
        fornecedores: estrelasSelectedFornecedores,
        tiposvenda: estrelasSelectedTiposVenda,
        redes: estrelasSelectedRedes,
        categorias: estrelasSelectedCategorias
    });
}
"""

# Append at the end of the file just before "});"
# Assuming the file ends with "});\nasync function loadFrequencyTable..."
last_brace_idx = content.rfind("\n});")
if last_brace_idx != -1:
    content = content[:last_brace_idx] + estrelas_logic + content[last_brace_idx:]
else:
    content += estrelas_logic

# Add to clearAllFilters logic
clear_estrelas = """
    } else if (prefix === 'estrelas') {
        const anoSelect = document.getElementById('estrelas-ano-filter');
        const mesSelect = document.getElementById('estrelas-mes-filter');

        if(typeof fetchLastSalesDate === 'function') await fetchLastSalesDate();
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

        if (anoSelect) {
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        estrelasSelectedSupervisors = [];
        estrelasSelectedVendedores = [];
        estrelasSelectedCidades = [];
        estrelasSelectedTiposVenda = [];
        estrelasSelectedRedes = [];
        estrelasSelectedFiliais = [];
        estrelasSelectedCategorias = [];
        estrelasSelectedFornecedores = [];

        const wrappers = [
            'estrelas-supervisor-filter-dropdown', 'estrelas-vendedor-filter-dropdown',
            'estrelas-cidade-filter-dropdown', 'estrelas-tipovenda-filter-dropdown',
            'estrelas-rede-filter-dropdown', 'estrelas-filial-filter-dropdown',
            'estrelas-categoria-filter-dropdown', 'estrelas-fornecedor-filter-dropdown'
        ];

        wrappers.forEach(id => {
            const dropdown = document.getElementById(id);
            if (dropdown) {
                dropdown.querySelectorAll('input[type="checkbox"]').forEach(cb => cb.checked = false);
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
"""
content = content.replace("} else if (prefix === 'lp') {", clear_estrelas + "\n    } else if (prefix === 'lp') {")

with open('src/js/app.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated filters logic")
