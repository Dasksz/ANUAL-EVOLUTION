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

        clearArrays(innovationsSelectedSupervisors, innovationsSelectedVendedores, innovationsSelectedCidades, innovationsSelectedTiposVenda, innovationsSelectedRedes, innovationsSelectedFiliais, innovationsSelectedCategorias);

        // Uncheck all custom select items visually
        const wrappers = [
            'innovations-supervisor-filter-dropdown', 'innovations-vendedor-filter-dropdown',
            'innovations-cidade-filter-dropdown', 'innovations-tipovenda-filter-dropdown',
            'innovations-rede-filter-dropdown', 'innovations-filial-filter-dropdown',
            'innovations-categoria-filter-dropdown'
        ];
        clearArrays(lpSelectedCidades);
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
                setupDefaultMultiSelect(document.getElementById('innovations-supervisor-filter-btn'), document.getElementById('innovations-supervisor-filter-dropdown'), document.getElementById('innovations-supervisor-filter-dropdown'), data.supervisors, innovationsSelectedSupervisors);
                setupDefaultMultiSelect(document.getElementById('innovations-vendedor-filter-btn'), document.getElementById('innovations-vendedor-filter-dropdown'), document.getElementById('innovations-vendedor-filter-list'), data.vendedores, innovationsSelectedVendedores, document.getElementById('innovations-vendedor-filter-search'));
                setupDefaultMultiSelect(document.getElementById('innovations-cidade-filter-btn'), document.getElementById('innovations-cidade-filter-dropdown'), document.getElementById('innovations-cidade-filter-list'), data.cidades, innovationsSelectedCidades, document.getElementById('innovations-cidade-filter-search'));
                setupDefaultMultiSelect(document.getElementById('innovations-tipovenda-filter-btn'), document.getElementById('innovations-tipovenda-filter-dropdown'), document.getElementById('innovations-tipovenda-filter-dropdown'), data.tipos_venda, innovationsSelectedTiposVenda);

                const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
                setupDefaultMultiSelect(document.getElementById('innovations-rede-filter-btn'), document.getElementById('innovations-rede-filter-dropdown'), document.getElementById('innovations-rede-filter-list'), redes, innovationsSelectedRedes, document.getElementById('innovations-rede-filter-search'));

                setupDefaultMultiSelect(document.getElementById('innovations-filial-filter-btn'), document.getElementById('innovations-filial-filter-dropdown'), document.getElementById('innovations-filial-filter-dropdown'), data.filiais, innovationsSelectedFiliais);

                supabase.from('data_innovations').select('inovacoes').order('inovacoes', { ascending: true }).then(({data: inovacData}) => {
                    if (inovacData) {
                        const uniqueInovacoes = [...new Set(inovacData.map(i => i.inovacoes).filter(i => i))];
                        setupDefaultMultiSelect(document.getElementById('innovations-categoria-filter-btn'), document.getElementById('innovations-categoria-filter-dropdown'), document.getElementById('innovations-categoria-filter-dropdown'), uniqueInovacoes, innovationsSelectedCategorias);
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

        clearArrays(estrelasSelectedSupervisors, estrelasSelectedVendedores, estrelasSelectedCidades, estrelasSelectedTiposVenda, estrelasSelectedRedes, estrelasSelectedFiliais, estrelasSelectedCategorias, estrelasSelectedFornecedores);

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
            if (data && !error && typeof setupDefaultMultiSelect === 'function') {
                setupDefaultMultiSelect(document.getElementById('estrelas-supervisor-filter-btn'), document.getElementById('estrelas-supervisor-filter-dropdown'), document.getElementById('estrelas-supervisor-filter-dropdown'), data.supervisors, estrelasSelectedSupervisors);
                setupDefaultMultiSelect(document.getElementById('estrelas-vendedor-filter-btn'), document.getElementById('estrelas-vendedor-filter-dropdown'), document.getElementById('estrelas-vendedor-filter-list'), data.vendedores, estrelasSelectedVendedores, document.getElementById('estrelas-vendedor-filter-search'));
                setupDefaultMultiSelect(document.getElementById('estrelas-fornecedor-filter-btn'), document.getElementById('estrelas-fornecedor-filter-dropdown'), document.getElementById('estrelas-fornecedor-filter-list'), data.fornecedores, estrelasSelectedFornecedores, document.getElementById('estrelas-fornecedor-filter-search'), true);
                setupDefaultMultiSelect(document.getElementById('estrelas-cidade-filter-btn'), document.getElementById('estrelas-cidade-filter-dropdown'), document.getElementById('estrelas-cidade-filter-list'), data.cidades, estrelasSelectedCidades, document.getElementById('estrelas-cidade-filter-search'));
                setupDefaultMultiSelect(document.getElementById('estrelas-tipovenda-filter-btn'), document.getElementById('estrelas-tipovenda-filter-dropdown'), document.getElementById('estrelas-tipovenda-filter-dropdown'), data.tipos_venda, estrelasSelectedTiposVenda);

                const redes = ['C/ REDE', 'S/ REDE', ...(data.redes || [])];
                setupDefaultMultiSelect(document.getElementById('estrelas-rede-filter-btn'), document.getElementById('estrelas-rede-filter-dropdown'), document.getElementById('estrelas-rede-filter-list'), redes, estrelasSelectedRedes, document.getElementById('estrelas-rede-filter-search'));

                setupDefaultMultiSelect(document.getElementById('estrelas-filial-filter-btn'), document.getElementById('estrelas-filial-filter-dropdown'), document.getElementById('estrelas-filial-filter-dropdown'), data.filiais, estrelasSelectedFiliais);
                setupDefaultMultiSelect(document.getElementById('estrelas-categoria-filter-btn'), document.getElementById('estrelas-categoria-filter-dropdown'), document.getElementById('estrelas-categoria-filter-list'), data.categorias || [], estrelasSelectedCategorias, document.getElementById('estrelas-categoria-filter-search'));

                updateEstrelasView();
            } else {
                updateEstrelasView();
            }
        });

    } else if (prefix === 'agenda') {
        clearArrays(agendaSelectedSupervisors, agendaSelectedRotas, agendaSelectedFoco);

        ['agenda-supervisor', 'agenda-rota', 'agenda-foco'].forEach(pref => {
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

        const anoSelect = document.getElementById('agenda-ano-filter');
        const mesSelect = document.getElementById('agenda-mes-filter');

        const currentYear = new Date().getFullYear().toString();
        const currentMonth = (new Date().getMonth() + 1).toString().padStart(2, '0');

        if (anoSelect) {
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        // No need to call updateAgendaView directly, as the dispatchEvent('change') on ano/mes selects will trigger handleAgendaFilterChange if they are attached, OR the user might not have them.
        // Actually, let's call it just to be safe, but wait, if dispatchEvent triggers debounce, and we call it, it might trigger twice.
        // Let's just call it directly to ensure update, as debounce will protect us.
        handleAgendaFilterChange();
    } else if (prefix === 'lp') {
        const anoSelect = document.getElementById('lp-ano-filter');
        const mesSelect = document.getElementById('lp-mes-filter');
        const currentYear = new Date().getFullYear().toString();
        const currentMonth = (new Date().getMonth() + 1).toString().padStart(2, '0');

        if (anoSelect) {
            let hasYear = Array.from(anoSelect.options).some(opt => opt.value === currentYear);
            anoSelect.value = hasYear ? currentYear : 'todos';
            anoSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }
        if (mesSelect) {
            mesSelect.value = currentMonth;
            mesSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        clearArrays(lpSelectedCidades, lpSelectedFiliais, lpSelectedSupervisors, lpSelectedVendedores, lpSelectedRedes, lpSelectedPesquisadores);

        ['lp-supervisor', 'lp-vendedor', 'lp-rede', 'lp-cidade', 'lp-pesquisador'].forEach(prefix => {
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
