-- Corrige filtros globais de Supervisor/Vendedor após o refresh geral do Evolução.
-- Causa:
-- 1) a origem passou a trazer muitos codusur no formato INAT_*;
-- 2) dim_supervisores foi sobrescrita com "INATIVOS" para códigos ativos;
-- 3) refresh_dashboard_cache propagava esses placeholders para data_summary/cache_filters.
--
-- Estratégia:
-- - restaura os nomes conhecidos dos supervisores ativos;
-- - remapeia vendedores INAT_* para data_clients.rca1 quando houver vendedor válido;
-- - torna esse remapeamento persistente em refresh_summary_year;
-- - estabiliza nomes de supervisor no refresh_cache_filters;
-- - oculta placeholders INATIVOS dos dropdowns globais.

UPDATE public.dim_supervisores
SET nome = CASE codigo
    WHEN '12' THEN 'TIAGO JOSÉ DE S'
    WHEN '21' THEN 'RÔMULO AMADO DA'
    ELSE nome
END
WHERE codigo IN ('12','21');

UPDATE public.data_summary ds
SET codusur = c.rca1
FROM public.data_clients c
WHERE ds.codcli = c.codigo_cliente
  AND ds.codusur LIKE 'INAT_%'
  AND c.rca1 IS NOT NULL
  AND c.rca1 <> ''
  AND EXISTS (
      SELECT 1
      FROM public.dim_vendedores dv
      WHERE dv.codigo = c.rca1
        AND UPPER(COALESCE(dv.nome,'')) NOT LIKE 'INATIVOS%'
  );

UPDATE public.data_summary_frequency ds
SET codusur = c.rca1
FROM public.data_clients c
WHERE ds.codcli = c.codigo_cliente
  AND ds.codusur LIKE 'INAT_%'
  AND c.rca1 IS NOT NULL
  AND c.rca1 <> ''
  AND EXISTS (
      SELECT 1
      FROM public.dim_vendedores dv
      WHERE dv.codigo = c.rca1
        AND UPPER(COALESCE(dv.nome,'')) NOT LIKE 'INATIVOS%'
  );

DO $$
DECLARE
    v_oid oid;
    v_def text;
    v_marker text;
    v_patch text;
BEGIN
    SELECT p.oid INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='refresh_summary_year'
    LIMIT 1;

    v_def := pg_get_functiondef(v_oid);

    IF position('UPDATE public.data_summary ds' in v_def) = 0 THEN
        v_marker := E'    FROM final_agg;\n    -- ANALYZE public.data_summary;\nEND;';
        v_patch := E'    FROM final_agg;\n\n'
        || E'    UPDATE public.data_summary ds\n'
        || E'       SET codusur = c.rca1\n'
        || E'      FROM public.data_clients c\n'
        || E'     WHERE ds.ano = p_year\n'
        || E'       AND ds.codcli = c.codigo_cliente\n'
        || E'       AND ds.codusur LIKE ''INAT_%''\n'
        || E'       AND c.rca1 IS NOT NULL AND c.rca1 <> ''''\n'
        || E'       AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo=c.rca1 AND UPPER(COALESCE(dv.nome,'''')) NOT LIKE ''INATIVOS%'');\n\n'
        || E'    UPDATE public.data_summary_frequency ds\n'
        || E'       SET codusur = c.rca1\n'
        || E'      FROM public.data_clients c\n'
        || E'     WHERE ds.ano = p_year\n'
        || E'       AND ds.codcli = c.codigo_cliente\n'
        || E'       AND ds.codusur LIKE ''INAT_%''\n'
        || E'       AND c.rca1 IS NOT NULL AND c.rca1 <> ''''\n'
        || E'       AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo=c.rca1 AND UPPER(COALESCE(dv.nome,'''')) NOT LIKE ''INATIVOS%'');\n\n'
        || E'    -- ANALYZE public.data_summary;\nEND;';

        IF position(v_marker in v_def)=0 THEN
            RAISE EXCEPTION 'Trecho esperado de refresh_summary_year não encontrado';
        END IF;
        v_def := replace(v_def, v_marker, v_patch);
        EXECUTE v_def;
    END IF;
END
$$;

DO $$
DECLARE
    v_oid oid;
    v_def text;
    v_replacement text;
BEGIN
    SELECT p.oid INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='refresh_cache_filters'
    LIMIT 1;

    v_def := pg_get_functiondef(v_oid);

    v_replacement := E'CASE\n'
      || E'            WHEN dc.codsupervisor = ''12'' THEN ''TIAGO JOSÉ DE S''\n'
      || E'            WHEN dc.codsupervisor = ''21'' THEN ''RÔMULO AMADO DA''\n'
      || E'            WHEN dc.codsupervisor = ''SV_AMERICANAS'' THEN ''SV AMERICANAS''\n'
      || E'            WHEN dc.codsupervisor = ''8'' THEN ''BALCAO''\n'
      || E'            ELSE ds.nome\n'
      || E'        END as superv';

    IF position('WHEN dc.codsupervisor = ''12''' in v_def)=0 THEN
        v_def := replace(v_def, 'ds.nome as superv', v_replacement);
        v_def := replace(v_def, 'ds.nome as superv', v_replacement);
        EXECUTE v_def;
    END IF;
END
$$;

DO $$
DECLARE
    v_oid oid;
    v_def text;
BEGIN
    SELECT p.oid INTO v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='get_dashboard_filters'
    LIMIT 1;

    v_def := pg_get_functiondef(v_oid);

    v_def := replace(
        v_def,
        '''supervisors'', (SELECT array_agg(superv) FROM (SELECT DISTINCT superv FROM public.cache_filters '' || v_where_supervisor || '' ORDER BY superv) sub),',
        '''supervisors'', (SELECT array_agg(superv) FROM (SELECT DISTINCT superv FROM public.cache_filters '' || v_where_supervisor || '' AND superv IS NOT NULL AND UPPER(superv) NOT LIKE ''''INATIVOS%'''' ORDER BY superv) sub),'
    );

    v_def := replace(
        v_def,
        '''vendedores'', (SELECT array_agg(nome) FROM (SELECT DISTINCT nome FROM public.cache_filters '' || v_where_vendedor || '' ORDER BY nome) sub),',
        '''vendedores'', (SELECT array_agg(nome) FROM (SELECT DISTINCT nome FROM public.cache_filters '' || v_where_vendedor || '' AND nome IS NOT NULL AND UPPER(nome) NOT LIKE ''''INATIVOS%'''' ORDER BY nome) sub),'
    );

    EXECUTE v_def;
END
$$;

SELECT public.refresh_cache_filters(NULL,NULL);
