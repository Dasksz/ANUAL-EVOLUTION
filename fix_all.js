const fs = require('fs');

let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// --- 1. Fix get_frequency_table_data ---
const oldLogicFreq = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            IF ('1119' = ANY(p_fornecedor)) THEN
                v_where_base := v_where_base || ' AND (
                    s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR s.codfor LIKE ''1119_%''
                ) ';
                v_where_base_prev := v_where_base_prev || ' AND (
                    s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR s.codfor LIKE ''1119_%''
                ) ';
                v_where_chart := v_where_chart || ' AND (
                    codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR codfor LIKE ''1119_%''
                ) ';
            ELSE
                v_where_base := v_where_base || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
                v_where_base_prev := v_where_base_prev || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
                v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            END IF;
        END IF;
    END IF;`;

const newLogicFreq = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            DECLARE
                v_code text;
                v_conditions text[] := '{}';
                v_simple_codes text[] := '{}';
                v_cond_str text;
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDYNHO'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDY'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''QUAKER'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''KEROCOCO'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias ?| ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                    ELSE
                        v_simple_codes := array_append(v_simple_codes, v_code);
                    END IF;
                END LOOP;

                IF array_length(v_simple_codes, 1) > 0 THEN
                    v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                END IF;

                IF array_length(v_conditions, 1) > 0 THEN
                    v_cond_str := array_to_string(v_conditions, ' OR ');
                    v_where_base := v_where_base || ' AND (' || v_cond_str || ') ';
                    v_where_base_prev := v_where_base_prev || ' AND (' || v_cond_str || ') ';
                    v_where_chart := v_where_chart || ' AND (' || replace(v_cond_str, 's.', '') || ') ';
                END IF;
            END;
        END IF;
    END IF;`;

content = content.replace(oldLogicFreq, newLogicFreq);

// --- 2. Fix get_main_dashboard_data (early dashboard filter) ---
const oldLogicDash = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codfor = ANY(%L::text[]) ', p_fornecedor);
    END IF;`;

const newLogicDash = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
            v_cond_str text;
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDYNHO'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDY'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''QUAKER'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''KEROCOCO'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias ?| ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;

            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
            END IF;

            IF array_length(v_conditions, 1) > 0 THEN
                v_cond_str := array_to_string(v_conditions, ' OR ');
                v_where_base := v_where_base || ' AND (' || v_cond_str || ') ';
            END IF;
        END;
    END IF;`;

content = content.replace(oldLogicDash, newLogicDash);

// --- 3. Fix get_main_dashboard_data (main body) ---
const oldLogicDash2 = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;`;

const newLogicDash2 = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
            v_cond_str text;
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND categorias ? ''TODDYNHO'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND categorias ? ''TODDY'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND categorias ? ''QUAKER'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND categorias ? ''KEROCOCO'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND NOT (categorias ?| ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;

            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
            END IF;

            IF array_length(v_conditions, 1) > 0 THEN
                v_cond_str := array_to_string(v_conditions, ' OR ');
                v_where_base := v_where_base || ' AND (' || v_cond_str || ') ';
            END IF;
        END;
    END IF;`;

content = content.replace(oldLogicDash2, newLogicDash2);

// --- 4. Fix get_mix_salty_foods_data #1 (around line 4300, it joins detailed/history and uses dp.descricao)
// The original code has this block:
const origMixBlock1 = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_chart := v_where_chart || ' AND (
                s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                OR (s.codfor = ''1119'' AND (
                    CASE
                        WHEN dp.descricao ILIKE ''%TODDYNHO%'' THEN ''1119_TODDYNHO''
                        WHEN dp.descricao ILIKE ''%TODDY %'' THEN ''1119_TODDY''
                        WHEN dp.descricao ILIKE ''%QUAKER%'' THEN ''1119_QUAKER''
                        WHEN dp.descricao ILIKE ''%KEROCOCO%'' THEN ''1119_KEROCOCO''
                        ELSE ''1119_OUTROS''
                    END
                ) = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']))
            ) ';
        END IF;
    END IF;`;

// We just fix '%TODDY %' to '%TODDY%' in origMixBlock1 for robustness
const newMixBlock1 = origMixBlock1.replace("WHEN dp.descricao ILIKE ''%TODDY %'' THEN ''1119_TODDY''", "WHEN dp.descricao ILIKE ''%TODDY%'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' THEN ''1119_TODDY''");

content = content.replace(origMixBlock1, newMixBlock1);

// --- 5. Fix get_mix_salty_foods_data #2 (around line 4917, reads from data_summary_frequency)
// This is the one missing the p_fornecedor filter completely.
// We will find `v_where_chart := v_where_chart || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';`
// and inject the new block right after it.

const origVendedorBlock = `    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;`;

const newMixBlock2 = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            DECLARE
                v_code text;
                v_conditions text[] := '{}';
                v_simple_codes text[] := '{}';
                v_cond_str text;
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDYNHO'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''TODDY'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''QUAKER'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias ? ''KEROCOCO'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias ?| ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                    ELSE
                        v_simple_codes := array_append(v_simple_codes, v_code);
                    END IF;
                END LOOP;

                IF array_length(v_simple_codes, 1) > 0 THEN
                    v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                END IF;

                IF array_length(v_conditions, 1) > 0 THEN
                    v_cond_str := array_to_string(v_conditions, ' OR ');
                    v_where_chart := v_where_chart || ' AND (' || v_cond_str || ') ';
                END IF;
            END;
        END IF;
    END IF;`;

// Only replace inside the second get_mix_salty_foods_data (which appears after line 4800)
// To do this reliably:
let parts = content.split('CREATE OR REPLACE FUNCTION get_mix_salty_foods_data');

if (parts.length > 2) { // it should have 3 parts (0, 1, 2)
    parts[2] = parts[2].replace(origVendedorBlock, origVendedorBlock + '\n\n' + newMixBlock2);
    content = parts.join('CREATE OR REPLACE FUNCTION get_mix_salty_foods_data');
}

// --- 6. Fix the 'TODDY ' trailing space in jsonb queries globally ---
content = content.replace(/\? ''TODDY ''/g, "? ''TODDY''");

// Also replace the CTE inside the first get_mix_salty_foods_data where it says '%TODDY %' for flags
content = content.replace(/ILIKE ''%TODDY %'' THEN ''1119_TODDY''/g, "ILIKE ''%TODDY%'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' THEN ''1119_TODDY''");

// Write back the final clean file
fs.writeFileSync('sql/full_system_v1.sql', content);
