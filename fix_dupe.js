const fs = require('fs');

let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const injectedBlock = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
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

// I accidentally injected it twice or the previous replace was faulty.
// We just replace `injectedBlock + '\n' + injectedBlock` with just `injectedBlock`. Let's normalize spaces.

// Or simpler: Find the split block and remove duplicates.
let parts = content.split(injectedBlock);
if(parts.length > 2) {
    // If it was injected twice sequentially, we have an empty or whitespace string between them.
    content = content.replace(injectedBlock + '\n' + injectedBlock, injectedBlock);
    content = content.replace(injectedBlock + '\n\n' + injectedBlock, injectedBlock);
    content = content.replace(injectedBlock + injectedBlock, injectedBlock);
}
fs.writeFileSync('sql/full_system_v1.sql', content);
