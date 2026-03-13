-- Add the new column to support storing cleaned CNPJ/CPF (only numbers)
ALTER TABLE public.data_clients ADD COLUMN IF NOT EXISTS cnpj text;

-- Create the secure RPC function to search clients (bypasses direct table permissions)
CREATE OR REPLACE FUNCTION public.search_clients(p_search text)
RETURNS TABLE (
    codigo_cliente text,
    razaosocial text,
    nomecliente text,
    cidade text,
    cnpj text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        dc.codigo_cliente,
        dc.razaosocial,
        dc.nomecliente,
        dc.cidade,
        dc.cnpj
    FROM public.data_clients dc
    WHERE
        dc.codigo_cliente ILIKE '%' || p_search || '%' OR
        dc.razaosocial ILIKE '%' || p_search || '%' OR
        dc.nomecliente ILIKE '%' || p_search || '%' OR
        dc.cidade ILIKE '%' || p_search || '%' OR
        dc.cnpj ILIKE '%' || p_search || '%'
    LIMIT 20;
END;
$$;

-- Grant execute to anon and authenticated roles
GRANT EXECUTE ON FUNCTION public.search_clients(text) TO anon, authenticated;
