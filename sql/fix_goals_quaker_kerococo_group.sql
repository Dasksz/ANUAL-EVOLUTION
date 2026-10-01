-- Agrupa QUAKER e KEROCOCO como um único fornecedor no painel de Metas.
-- A UI envia 1119_QUAKER_KEROCOCO; a RPC anual passa a:
-- - ler a meta importada da categoria consolidada 1119_QUAKER_KEROCOCO;
-- - considerar juntos os realizados 1119_QUAKER e 1119_KEROCOCO.

DO $$
DECLARE
    v_oid oid;
    v_def text;
BEGIN
    SELECT p.oid
      INTO v_oid
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'get_metas_anuais_chart'
       AND pg_get_function_identity_arguments(p.oid) LIKE '%p_filial%'
     LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Função public.get_metas_anuais_chart não encontrada';
    END IF;

    v_def := pg_get_functiondef(v_oid);

    v_def := replace(
        v_def,
        'p_fornecedor IN (''1119_QUAKER'', ''1119_KEROCOCO'', ''QUAKER'', ''KEROCOCO'')',
        'p_fornecedor IN (''1119_QUAKER'', ''1119_KEROCOCO'', ''1119_QUAKER_KEROCOCO'', ''QUAKER'', ''KEROCOCO'')'
    );

    v_def := replace(
        v_def,
        'AND (p_fornecedor = ''Todos'' OR codfor::text = p_fornecedor OR LTRIM(codfor::text, ''0'') = p_fornecedor OR (p_fornecedor = ''1119'' AND codfor::text LIKE ''1119_%''))',
        'AND (
              p_fornecedor = ''Todos''
              OR codfor::text = p_fornecedor
              OR LTRIM(codfor::text, ''0'') = p_fornecedor
              OR (p_fornecedor = ''1119'' AND codfor::text LIKE ''1119_%'')
              OR (
                  p_fornecedor = ''1119_QUAKER_KEROCOCO''
                  AND LTRIM(codfor::text, ''0'') IN (''1119_QUAKER'', ''1119_KEROCOCO'')
              )
          )'
    );

    EXECUTE v_def;
END
$$;
