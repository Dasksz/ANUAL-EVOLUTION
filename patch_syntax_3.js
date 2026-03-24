const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const oldFunc = `CREATE OR REPLACE FUNCTION public.update_products_stock(p_stock_data jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- p_stock_data expects: [{"codigo": "123", "filial": "05", "estoque": 100}, ...]
    WITH raw_stock AS (
        SELECT
            (rec->>'codigo')::text as codigo,
            (rec->>'filial')::text as filial,
            (rec->>'estoque')::numeric as estoque
        FROM jsonb_array_elements(p_stock_data) rec
    ),
    agg_stock AS (
        SELECT
            codigo,
            jsonb_object_agg(filial, estoque) as j
        FROM raw_stock
        WHERE codigo IS NOT NULL AND filial IS NOT NULL AND estoque IS NOT NULL
        GROUP BY codigo
    )
    UPDATE public.dim_produtos p
    SET estoque_filial = COALESCE(p.estoque_filial, '{}'::jsonb) || agg_stock.j
    FROM agg_stock
    WHERE p.codigo = agg_stock.codigo;
END;
$$;`;

const newFunc = `CREATE OR REPLACE FUNCTION public.update_products_stock(p_stock_data jsonb)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    WITH raw_stock AS (
        SELECT
            (rec->>'codigo')::text as codigo,
            (rec->>'filial')::text as filial,
            (rec->>'estoque')::numeric as estoque
        FROM jsonb_array_elements(p_stock_data) rec
    ),
    agg_stock AS (
        SELECT
            codigo,
            jsonb_object_agg(filial, estoque) as j
        FROM raw_stock
        WHERE codigo IS NOT NULL AND filial IS NOT NULL AND estoque IS NOT NULL
        GROUP BY codigo
    )
    UPDATE public.dim_produtos p
    SET estoque_filial = COALESCE(p.estoque_filial, '{}'::jsonb) || agg_stock.j
    FROM agg_stock
    WHERE p.codigo = agg_stock.codigo;
$$;`;

if (content.includes(oldFunc)) {
    content = content.replace(oldFunc, newFunc);
    console.log("Patched update_products_stock successfully!");
} else {
    console.log("oldFunc not found!");
}
fs.writeFileSync('sql/full_system_v1.sql', content);
