1. **Diferença entre MIX PDV e SKU/PDV:**
   - **MIX PDV**: é derivado de `pre_mix_count` da tabela `data_summary` no `get_main_dashboard_data`. A métrica soma `pre_mix_count` e divide por `mix_client_count`. O `pre_mix_count` no `data_summary` é precalculado (provavelmente por fornecedor ou mix_marca).
   - **SKU/PDV**: é calculado na `get_frequency_table_data` baseando-se em `data_summary_frequency`, usando `jsonb_array_length(produtos)` e somado por cliente, depois calculando a média geral.
2. **A Base do Filtro:**
   - `SKU/PDV` usa `s.categorias ? 'BRAND'` ou exato `s.codfor = ANY(...)`. Como os jsonbs foram consertados, a filtragem das marcas exatas (KEROCOCO, QUAKER, TODDY, TODDYNHO) ocorre filtrando todas as linhas da Pepsico Foods (`1119`) que possuam essas tags no jsonb.
   - O `MIX PDV` faz `SUM(pre_mix_count)` do `data_summary`. No script `fix_test4.js`, eu reverti a atualização de `get_main_dashboard_data` para manter `v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);`. E nós vimos que `data_summary` POSSUI `1119_KEROCOCO`, `1119_TODDY` na coluna `codfor`?
   - Espere, nós vimos que `data_summary` possui `1119_KEROCOCO`? Vamos confirmar executando uma query sobre `data_summary` para ver se ele tem `1119_TODDY` em `codfor`.
