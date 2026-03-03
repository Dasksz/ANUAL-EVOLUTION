with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# Fix prod_base
content = content.replace(
'''            prod_base AS (
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, s.dtped
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
                UNION ALL
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, s.dtped
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo''',
'''            prod_base AS (
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, s.dtped, dp.qtde_embalagem_master
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
                UNION ALL
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, s.dtped, dp.qtde_embalagem_master
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo'''
)

# Fix base_data
content = content.replace(
'''            WITH base_data AS (
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
                UNION ALL
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo''',
'''            WITH base_data AS (
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, dp.qtde_embalagem_master
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
                UNION ALL
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, dp.descricao, dp.qtde_embalagem_master
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo'''
)

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)
