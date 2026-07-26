import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

search = """        -- [QueryTuner] Optimization: Replaced inline JSON/Array aggregations with DISTINCT.
        -- Constructing dynamic JSON or Array aggregations using json_agg(DISTINCT jsonb_build_object(...))
        -- directly against large tables severely degrades performance.
        -- Expected Impact: ~1375ms -> ~39ms (35x faster).
        'fornecedores', (
            SELECT json_agg(json_build_object('cod', cod, 'name', nome) ORDER BY nome)
            FROM (
                SELECT DISTINCT codfor as cod, fornecedor as nome
                FROM public.cache_filters f2
                WHERE
                   (v_filter_year IS NULL OR f2.ano = v_filter_year)
                   AND (p_filial IS NULL OR f2.filial = ANY(p_filial))
                   AND f2.codfor IS NOT NULL
            ) sub
        ),"""

replace = """        'fornecedores', (
            SELECT json_agg(json_build_object('cod', cod, 'name', nome) ORDER BY nome)
            FROM (
                SELECT DISTINCT codfor as cod, fornecedor as nome
                FROM public.cache_filters f2
                WHERE
                   (v_filter_year IS NULL OR f2.ano = v_filter_year)
                   AND (p_filial IS NULL OR f2.filial = ANY(p_filial))
                   -- ... (aplica mesmos filtros da query principal, ou simplifica para performance)
                   -- Nota: Para performance máxima, podemos simplificar a lista de fornecedores ou incluí-la no agg principal se não precisarmos do objeto {cod, name} complexo.
                   -- Mantendo compatibilidade com teu código atual:
                   AND f2.codfor IS NOT NULL
            ) sub
        ),"""

content_fixed = content.replace(search, replace)
if content != content_fixed:
    with open('sql/full_system_v1.sql', 'w') as f:
        f.write(content_fixed)
    print("Reverted get_dashboard_filters_optimized!")
else:
    print("Not replaced.")
