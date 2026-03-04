import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# Fix refresh_summary_year
year_pattern = re.compile(r'    -- Refresh Frequency Summary for the year\n    DELETE FROM public.dat_summary_frequency WHERE ano = p_year;\n    \n    INSERT INTO public.dat_summary_frequency \(\n        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede\n    \)\n    SELECT \n        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,\n        SUM\(vlvenda\) as vlvenda,\n        SUM\(totpesoliq\) as peso,\n        jsonb_agg\(DISTINCT produto\) as produtos,\n        jsonb_agg\(DISTINCT categoria_produto\) as categorias,\n        MAX\(ramo\) as rede\n    FROM augmented_data\n    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;')

year_replacement = """    -- Refresh Frequency Summary for the year
    DELETE FROM public.dat_summary_frequency WHERE ano = p_year;

    INSERT INTO public.dat_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_detailed
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_history
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.pedido, s.vlvenda, s.totpesoliq, dp.categoria_produto,
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,
        SUM(vlvenda) as vlvenda,
        SUM(totpesoliq) as peso,
        jsonb_agg(DISTINCT produto) as produtos,
        jsonb_agg(DISTINCT categoria_produto) as categorias,
        MAX(ramo) as rede
    FROM augmented_data
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;"""

content = year_pattern.sub(year_replacement, content)


# Fix refresh_summary_month
month_pattern = re.compile(r'    -- Refresh Frequency Summary for the month\n    DELETE FROM public.dat_summary_frequency WHERE ano = p_year AND mes = p_month;\n    \n    INSERT INTO public.dat_summary_frequency \(\n        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede\n    \)\n    SELECT \n        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,\n        SUM\(vlvenda\) as vlvenda,\n        SUM\(totpesoliq\) as peso,\n        jsonb_agg\(DISTINCT produto\) as produtos,\n        jsonb_agg\(DISTINCT categoria_produto\) as categorias,\n        MAX\(ramo\) as rede\n    FROM augmented_data\n    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;')

month_replacement = """    -- Refresh Frequency Summary for the month
    DELETE FROM public.dat_summary_frequency WHERE ano = p_year AND mes = p_month;

    INSERT INTO public.dat_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_detailed
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_history
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.pedido, s.vlvenda, s.totpesoliq, dp.categoria_produto,
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,
        SUM(vlvenda) as vlvenda,
        SUM(totpesoliq) as peso,
        jsonb_agg(DISTINCT produto) as produtos,
        jsonb_agg(DISTINCT categoria_produto) as categorias,
        MAX(ramo) as rede
    FROM augmented_data
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;"""

content = month_pattern.sub(month_replacement, content)

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)

print("Fixed syntax in refresh_summary_year and refresh_summary_month")
