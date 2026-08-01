const fs = require('fs');

let fileContent = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// 1. Fix p_produto
let replacement = `    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_use_cache := false;
        v_where_raw := v_where_raw || format(' AND s.produto = ANY(%L::text[]) ', p_produto);
        v_where_raw_base := v_where_raw_base || format(' AND s.produto = ANY(%L::text[]) ', p_produto);
    END IF;`;
fileContent = fileContent.replace(
    /    IF p_produto IS NOT NULL AND array_length\(p_produto, 1\) > 0 THEN\n        v_use_cache := false;\n        v_where_raw := v_where_raw \|\| format\(' AND produto = ANY\(%L::text\[\]\) ', p_produto\);\n    END IF;/g,
    replacement
);

// 2. Fix p_categoria
replacement = `    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND categoria_produto = ANY(%L::text[]) ', p_categoria);
        v_where_summary_base := v_where_summary_base || format(' AND categoria_produto = ANY(%L::text[]) ', p_categoria);
        v_where_raw := v_where_raw || format(' AND dp.categoria_produto = ANY(%L::text[]) ', p_categoria);
        v_where_raw_base := v_where_raw_base || format(' AND dp.categoria_produto = ANY(%L::text[]) ', p_categoria);
    END IF;`;
fileContent = fileContent.replace(
    /    -- Category Filter\n    IF p_categoria IS NOT NULL AND array_length\(p_categoria, 1\) > 0 THEN\n        v_where_summary := v_where_summary \|\| format\(' AND categoria_produto = ANY\(%L::text\[\]\) ', p_categoria\);\n        v_where_raw := v_where_raw \|\| format\(' AND dp.categoria_produto = ANY\(%L::text\[\]\) ', p_categoria\);\n    END IF;/g,
    replacement
);

// 3. Fix FAST PATH prod_raw query to include dim_produtos so `dp` is available
let fastPathProdRawOriginal = `            prod_raw AS (
                SELECT produto,
                       SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as faturamento,
                       SUM(totpesoliq) as peso,
                       SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                       COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes,
                       MAX(dtped) as ultima_venda
                FROM public.data_detailed s
                %s AND dtped >= make_date(%L, 1, 1) AND dtped <= make_date(%L, 12, 31) %s
                GROUP BY produto
                UNION ALL
                SELECT produto,
                       SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as faturamento,
                       SUM(totpesoliq) as peso,
                       SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                       COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes,
                       MAX(dtped) as ultima_venda
                FROM public.data_history s
                %s AND dtped >= make_date(%L, 1, 1) AND dtped <= make_date(%L, 12, 31) %s
                GROUP BY produto
            ),`;

let fastPathProdRawReplacement = `            prod_raw AS (
                SELECT s.produto,
                       SUM(CASE WHEN s.tipovenda IN (''5'', ''11'') THEN s.vlbonific::numeric ELSE s.vlvenda::numeric END) as faturamento,
                       SUM(s.totpesoliq) as peso,
                       SUM(COALESCE(s.qtvenda, 0)) as total_qtvenda,
                       COUNT(DISTINCT CASE WHEN %s THEN s.codcli END) as clientes,
                       MAX(s.dtped) as ultima_venda
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1) AND s.dtped <= make_date(%L, 12, 31) %s
                GROUP BY s.produto
                UNION ALL
                SELECT s.produto,
                       SUM(CASE WHEN s.tipovenda IN (''5'', ''11'') THEN s.vlbonific::numeric ELSE s.vlvenda::numeric END) as faturamento,
                       SUM(s.totpesoliq) as peso,
                       SUM(COALESCE(s.qtvenda, 0)) as total_qtvenda,
                       COUNT(DISTINCT CASE WHEN %s THEN s.codcli END) as clientes,
                       MAX(s.dtped) as ultima_venda
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1) AND s.dtped <= make_date(%L, 12, 31) %s
                GROUP BY s.produto
            ),`;
fileContent = fileContent.replace(fastPathProdRawOriginal, fastPathProdRawReplacement);


fs.writeFileSync('sql/full_system_v1.sql', fileContent);
