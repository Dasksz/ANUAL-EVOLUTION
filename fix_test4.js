const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// I replaced p_fornecedor logic in get_main_dashboard_data assuming it used data_summary_frequency and jsonb 'categorias'.
// But `data_summary` has no `categorias` JSONB array! That's why it threw the 42703 column does not exist!
// So I MUST revert the p_fornecedor logic in get_main_dashboard_data back to its original logic or adapt it to data_summary's structure.
// In data_summary, how do we distinguish 1119_TODDY? Does it store 1119_TODDY directly in codfor, or what?
// Let's check the old logic in get_main_dashboard_data before I changed it.
// The old logic was simply:
//    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
//        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
//    END IF;

const badDash1 = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
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

const restoredDash = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;`;

content = content.replace(badDash1, restoredDash);
content = content.replace(badDash1, restoredDash); // In case it was applied twice

fs.writeFileSync('sql/full_system_v1.sql', content);
