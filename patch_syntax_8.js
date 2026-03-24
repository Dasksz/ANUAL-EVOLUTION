const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

content = content.replace(`
    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$;`, `
    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;`);

content = content.replace(`SET search_path = public
AS $
BEGIN
    RETURN get_frequency_table_data(p_filial, p_cidade, p_supervisor, p_vendedor, p_fornecedor, null::text, null::text, p_tipovenda, p_rede, p_produto, p_categoria);
END;
$;`, `SET search_path = public
AS $$
BEGIN
    RETURN get_frequency_table_data(p_filial, p_cidade, p_supervisor, p_vendedor, p_fornecedor, null::text, null::text, p_tipovenda, p_rede, p_produto, p_categoria);
END;
$$;`);

fs.writeFileSync('sql/full_system_v1.sql', content);
console.log("Re-patched $$ markers");
