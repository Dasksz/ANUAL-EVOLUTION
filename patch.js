const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const targetStr = `
    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;`;

const appendStr = `

-- OVERLOAD: Fallback function for missing 'p_ano' / 'p_mes' payload keys from Javascript (PGRST202 FIX)
CREATE OR REPLACE FUNCTION get_frequency_table_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN get_frequency_table_data(p_filial, p_cidade, p_supervisor, p_vendedor, p_fornecedor, null::text, null::text, p_tipovenda, p_rede, p_produto, p_categoria);
END;
$$;
`;

if (content.includes(targetStr)) {
    content = content.replace(targetStr, targetStr + appendStr);
    fs.writeFileSync('sql/full_system_v1.sql', content);
    console.log("Patched successfully!");
} else {
    console.log("Target string not found.");
}
