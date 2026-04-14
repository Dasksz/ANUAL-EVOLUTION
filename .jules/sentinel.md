## 2024-05-24 : (Filtragem SQL Condicional em Base KPI)
**Vulnerability:** Ao compor queries SQL dinamicamente no Postgres (RPCs), omissões na lógica "fallback" de filtros como "ambas / todas" (ex: ignorar a restrição regional quando nada for selecionado) podem causar filtragem rígida silenciosa, mascarando dados da Base Total (ex: escondendo 834 clientes atendidos do universo de 2.408 clientes) devido a falhas no mapeamento manual de configurações (`config_city_branches`).
**Learning:** Sempre garantir simetria entre a lógica de filtragem da Base Atendida (`v_where_base`) e a lógica da Base Teórica Total (`v_where_kpi`).
**Prevention:** Incluir sempre `IF NOT ('ambas' = ANY(p_filial)) THEN` nas lógicas dedicadas a KPIs isolados ou refatorar para utilizar CTEs globais de restrição.
