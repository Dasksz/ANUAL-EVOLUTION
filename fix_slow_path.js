const fs = require('fs');
let sql = fs.readFileSync('/app/sql/full_system_v1.sql', 'utf8');

const targetFunctionStart = sql.indexOf('CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(');
const nextFunctionStart = sql.indexOf('CREATE OR REPLACE FUNCTION get_branch_comparison_data(');

let funcBody = sql.substring(targetFunctionStart, nextFunctionStart);

// 1. In v_where_raw handling, replace `dp.categoria_produto` with a subquery
funcBody = funcBody.replace(
    /v_where_raw := v_where_raw \|\| format\(' AND dp\.categoria_produto = ANY\(%L::text\[\]\) ', p_categoria\);/g,
    "v_where_raw := v_where_raw || format(' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ANY(%L::text[])) ', p_categoria);"
);
funcBody = funcBody.replace(
    /v_where_raw_base := v_where_raw_base \|\| format\(' AND dp\.categoria_produto = ANY\(%L::text\[\]\) ', p_categoria\);/g,
    "v_where_raw_base := v_where_raw_base || format(' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ANY(%L::text[])) ', p_categoria);"
);

// 2. Remove dp join from SLOW PATH base_data
funcBody = funcBody.replace(
    /SELECT s\.dtped, s\.vlvenda, s\.totpesoliq, s\.qtvenda, s\.produto, dp\.descricao, dp\.qtde_embalagem_master, s\.codcli, s\.tipovenda, s\.vlbonific, s\.codfor\n\s+FROM public\.data_detailed s\n\s+LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo/g,
    "SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, s.codcli, s.tipovenda, s.vlbonific, s.codfor\n                FROM public.data_detailed s"
);
funcBody = funcBody.replace(
    /SELECT s\.dtped, s\.vlvenda, s\.totpesoliq, s\.qtvenda, s\.produto, dp\.descricao, dp\.qtde_embalagem_master, s\.codcli, s\.tipovenda, s\.vlbonific, s\.codfor\n\s+FROM public\.data_history s\n\s+LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo/g,
    "SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, s.codcli, s.tipovenda, s.vlbonific, s.codfor\n                FROM public.data_history s"
);

// 3. Remove dp join from FAST PATH prod_raw
funcBody = funcBody.replace(
    /FROM public\.data_detailed s\n\s+LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo\n\s+%s AND s\.dtped/g,
    "FROM public.data_detailed s\n                %s AND s.dtped"
);
funcBody = funcBody.replace(
    /FROM public\.data_history s\n\s+LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo\n\s+%s AND s\.dtped/g,
    "FROM public.data_history s\n                %s AND s.dtped"
);

// 4. In SLOW PATH, we need to calculate `caixas`. Instead of doing it in `kpi_curr`, `kpi_prev`, `kpi_tri`, `chart_agg`, we'll delay it to the final step. Wait, `caixas` requires division by `qtde_embalagem_master`.
// We can't do it before aggregating! That's exactly the optimization!
// Instead of SUM(qtvenda / qtde_embalagem_master), we can just SUM(qtvenda) in the CTEs, and then do the division when selecting the final result.
// BUT since different products have different `qtde_embalagem_master`, we CANNOT aggregate `qtvenda` across different products first and then divide.
// Caixas = SUM(qtvenda / qtde_embalagem_master) PER PRODUCT, then SUM overall.
// Oh, the old code was doing: SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as caixas.
// To fix this without joining dim_produtos on millions of rows:
// We can join the aggregated result with dim_produtos!
// For chart_agg_base: group by yr, m_idx AND produto, then aggregate in chart_agg!
// Actually, it's simpler:

fs.writeFileSync('/app/sql/full_system_v1_fixed.sql',
    sql.substring(0, targetFunctionStart) + funcBody + sql.substring(nextFunctionStart)
);
console.log('Script updated successfully');
