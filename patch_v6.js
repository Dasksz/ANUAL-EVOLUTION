const fs = require('fs');
let sql = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const functionStartStr = 'CREATE OR REPLACE FUNCTION get_frequency_table_data(';
let functionStart = sql.indexOf(functionStartStr);

// Find the correct get_frequency_table_data function definition block
while (functionStart !== -1) {
    let snippet = sql.substring(functionStart, functionStart + 500);
    if (snippet.includes('p_categoria text[] default null')) {
        break; // found the right one!
    }
    functionStart = sql.indexOf(functionStartStr, functionStart + 1);
}

const functionEnd = sql.indexOf('END;', functionStart) + 4;
let targetFunction = sql.substring(functionStart, functionEnd);


// Replace DECL
let declBlock = `    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';`;
let declReplacement = `    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';
    v_mix_constraint text;
    v_where_summary text := ' WHERE 1=1 ';`;

targetFunction = targetFunction.replace(declBlock, declReplacement);


// Replace IF Tipovenda block
let tipovendaIfStart = targetFunction.indexOf("IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN");
let tipovendaIfEnd = targetFunction.indexOf("END IF;", tipovendaIfStart) + 7;
let tipovendaBlock = targetFunction.substring(tipovendaIfStart, tipovendaIfEnd);

let tipovendaReplacement = `IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_summary := v_where_summary || ' AND ds.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    -- Mix Constraint Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_mix_constraint := ' 1=1 ';
    ELSE
        v_mix_constraint := ' ds.codfor IN (''707'', ''708'', ''752'') ';
    END IF;

    -- Build v_where_summary
    v_where_summary := v_where_summary || ' AND ds.ano = ' || v_current_year || ' ';
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_where_summary := v_where_summary || ' AND ds.mes = ' || v_target_month || ' ';
    END IF;
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_summary := v_where_summary || ' AND ds.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_summary := v_where_summary || ' AND ds.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_summary := v_where_summary || ' AND ds.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_summary := v_where_summary || ' AND ds.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_summary := v_where_summary || ' AND ds.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
    END IF;
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF 'C/ REDE' = ANY(p_rede) THEN
            v_where_summary := v_where_summary || ' AND (ds.ramo IS NOT NULL AND ds.ramo != '''') ';
        ELSIF 'S/ REDE' = ANY(p_rede) THEN
            v_where_summary := v_where_summary || ' AND (ds.ramo IS NULL OR ds.ramo = '''') ';
        ELSE
            v_where_summary := v_where_summary || ' AND ds.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_summary := v_where_summary || ' AND ds.categoria_produto = ANY(ARRAY[''' || array_to_string(p_categoria, ''',''') || ''']) ';
    END IF;`;

targetFunction = targetFunction.replace(tipovendaBlock, tipovendaReplacement);

// Replace CTE block
let cteStart = targetFunction.indexOf("    current_skus AS (");
let cteEnd = targetFunction.indexOf("    monthly_freq AS (");
let cteBlock = targetFunction.substring(cteStart, cteEnd);

let cteReplacement = `    current_skus AS (
        SELECT ds.codcli, ds.codusur, cb.filial, ds.cidade, ds.tipovenda, ds.pre_mix_count, ds.vlvenda
        FROM public.data_summary ds
        LEFT JOIN public.config_city_branches cb ON ds.cidade = cb.cidade
        '' || v_where_summary || ''
    ),
    pre_aggregated_skus AS (
        SELECT
            COALESCE(filial, ''SEM FILIAL'') as filial,
            COALESCE(cidade, ''SEM CIDADE'') as cidade,
            codusur,
            codcli,
            SUM(CASE
                WHEN tipovenda IN (''1'', ''9'') AND ('' || v_mix_constraint || '') THEN pre_mix_count
                ELSE 0
            END) as dist_skus_per_cli
        FROM current_skus ds
        GROUP BY 1, 2, 3, 4
    ),

`;
targetFunction = targetFunction.replace(cteBlock, cteReplacement);

// Substitute back into SQL
sql = sql.substring(0, functionStart) + targetFunction + sql.substring(functionEnd);
fs.writeFileSync('sql/full_system_v1.sql', sql);
