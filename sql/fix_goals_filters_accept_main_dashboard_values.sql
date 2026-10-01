-- Faz os filtros do painel de Metas aceitarem os mesmos valores retornados
-- por public.get_dashboard_filters usados no dashboard principal.
-- Supervisor e vendedor podem chegar como nome canônico; a função de metas
-- converte/aceita nome ou código ao filtrar a base anual.

DO $$
DECLARE
    v_oid oid;
    v_def text;
    v_old text;
    v_new text;
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

    v_old := 'AND (p_codusur IS NULL OR p_codusur = '''' OR codusur = p_codusur)';
    v_new := $seller$
AND (
              p_codusur IS NULL OR p_codusur = ''
              OR codusur = p_codusur
              OR codusur IN (
                  SELECT codigo
                  FROM public.dim_vendedores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codusur))
              )
          )
$seller$;
    v_def := replace(v_def, v_old, v_new);

    v_old := 'AND (p_codsupervisor IS NULL OR p_codsupervisor = '''' OR codsupervisor = p_codsupervisor)';
    v_new := $supervisor$
AND (
              p_codsupervisor IS NULL OR p_codsupervisor = ''
              OR codsupervisor = p_codsupervisor
              OR codsupervisor IN (
                  SELECT codigo
                  FROM public.dim_supervisores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codsupervisor))
              )
          )
$supervisor$;
    v_def := replace(v_def, v_old, v_new);

    EXECUTE v_def;
END
$$;
