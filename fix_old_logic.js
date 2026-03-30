const fs = require('fs');

let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// I need to look closely at get_mix_salty_foods_data (around 4298 and 4917).
// Let's check the p_fornecedor block inside the first get_mix_salty_foods_data
// Ah, the first occurrence of get_mix_salty_foods_data is a drop or old version (around line 4300)? No, it's the actual code. Let's see if I added it twice and kept old logic.

// wait, get_mix_salty_foods_data has this original block:
const origFornecedorBlock = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
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

// Let's replace origFornecedorBlock with the new logic, and REMOVE the newly injected blocks that I just did blindly after p_vendedor.
// I will just read the file, and since my previous fix_mix.js script injected the new block AFTER `vendedorBlock`, I might have both the new block AND the old origFornecedorBlock immediately following it.

let newFornecedorBlock = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
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

// Find out where I injected it blindly and clean it up.
// Actually, let's just reset sql/full_system_v1.sql from git and re-apply cleanly.
