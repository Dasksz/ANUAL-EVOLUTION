const fs = require('fs');

let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// There's a duplicate block inside get_mix_salty_foods_data #1.
// At line 4395 we see IF p_fornecedor IS NOT NULL which is the old block that I failed to remove.
// And wait, what about get_mix_salty_foods_data #2? Did I leave the old block there?
// "v_where_chart := v_where_chart || ' AND ( s.codfor = ANY(ARRAY"
// I will just read lines and remove the old block in get_mix_salty_foods_data #1.

const oldBlock = `    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_chart := v_where_chart || ' AND (
                s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                OR (s.codfor = ''1119'' AND (
                    CASE
                        WHEN dp.descricao ILIKE ''%TODDYNHO%'' THEN ''1119_TODDYNHO''
                        WHEN dp.descricao ILIKE ''%TODDY%'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' THEN ''1119_TODDY''
                        WHEN dp.descricao ILIKE ''%QUAKER%'' THEN ''1119_QUAKER''
                        WHEN dp.descricao ILIKE ''%KEROCOCO%'' THEN ''1119_KEROCOCO''
                        ELSE ''1119_OUTROS''
                    END
                ) = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']))
            ) ';
        END IF;
    END IF;`;

content = content.replace(oldBlock, '');

// Also need to check if I injected twice in get_mix_salty_foods_data #2
// "Found at line 5004" and "Found at line 5039"
// Ah, the first is get_mix_salty_foods_data #2. What is 5039?

fs.writeFileSync('sql/full_system_v1.sql', content);
