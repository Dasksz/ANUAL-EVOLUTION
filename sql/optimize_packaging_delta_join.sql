CREATE OR REPLACE FUNCTION private.evolution_refresh_packaging_months()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_codes text[]; v_period record;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM private.evolution_assert_admin();
        -- Apply only the conversion delta. Atomic row updates preserve revenue, identity,
        -- category, and concurrent packaging changes without rebuilding every year.
        WITH changed AS (
            SELECT n.codigo, o.qtde_embalagem_master AS old_master, n.qtde_embalagem_master AS new_master
            FROM new_products n JOIN old_products o USING (codigo)
            WHERE n.qtde_embalagem_master IS DISTINCT FROM o.qtde_embalagem_master
        ), raw AS (
            SELECT s.* FROM public.data_detailed s JOIN changed c ON c.codigo=s.produto
            UNION ALL
            SELECT s.* FROM public.data_history s JOIN changed c ON c.codigo=s.produto
        ), grouped AS (
            SELECT EXTRACT(YEAR FROM s.dtped)::int ano, EXTRACT(MONTH FROM s.dtped)::int mes,
                CASE WHEN s.codcli='11625' AND s.dtped >= '2025-12-01' AND s.dtped < '2026-01-01' THEN '05' ELSE s.filial END filial,
                COALESCE(s.cidade, dc.cidade) cidade, s.codsupervisor,
                CASE WHEN s.codusur LIKE 'INAT_%' AND dc.rca1 IS NOT NULL AND dc.rca1 <> ''
                    AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo=dc.rca1
                        AND UPPER(COALESCE(dv.nome,'')) NOT LIKE 'INATIVOS%')
                    THEN dc.rca1 ELSE s.codusur END codusur,
                CASE WHEN s.codfor <> '1119' THEN s.codfor
                    WHEN p.descricao ILIKE '%TODDYNHO%' OR p.descricao ILIKE '%TODYNHO%' THEN '1119_TODDYNHO'
                    WHEN p.descricao ILIKE '%TODDY %' OR UPPER(TRIM(p.descricao))='TODDY' THEN '1119_TODDY'
                    WHEN p.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                    WHEN p.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                    ELSE '1119_OUTROS' END codfor,
                s.tipovenda, s.codcli, dc.ramo, p.categoria_produto,
                SUM(COALESCE(s.qtvenda,0) * (1.0 / c.new_master - 1.0 / c.old_master)) delta
            FROM raw s JOIN changed c ON c.codigo=s.produto
            JOIN public.dim_produtos p ON p.codigo=s.produto
            LEFT JOIN public.data_clients dc ON dc.codigo_cliente=s.codcli
            GROUP BY 1,2,3,4,5,6,7,8,9,10,11
        )
        UPDATE public.data_summary ds SET caixas=COALESCE(ds.caixas,0)+g.delta, created_at=clock_timestamp()
        FROM grouped g
        WHERE ds.ano=g.ano AND ds.mes=g.mes
          AND ds.filial IS NOT DISTINCT FROM g.filial AND ds.cidade IS NOT DISTINCT FROM g.cidade
          AND ds.codsupervisor IS NOT DISTINCT FROM g.codsupervisor AND ds.codusur IS NOT DISTINCT FROM g.codusur
          AND ds.codfor IS NOT DISTINCT FROM g.codfor AND ds.tipovenda IS NOT DISTINCT FROM g.tipovenda
          AND ds.codcli IS NOT DISTINCT FROM g.codcli AND ds.ramo IS NOT DISTINCT FROM g.ramo
          AND ds.categoria_produto IS NOT DISTINCT FROM g.categoria_produto
          -- Equality keys allow a hash join; exact null-safe predicates above
          -- still distinguish NULL from an empty string.
          AND coalesce(ds.filial,'')=coalesce(g.filial,'')
          AND coalesce(ds.cidade,'')=coalesce(g.cidade,'')
          AND coalesce(ds.codsupervisor,'')=coalesce(g.codsupervisor,'')
          AND coalesce(ds.codusur,'')=coalesce(g.codusur,'')
          AND coalesce(ds.codfor,'')=coalesce(g.codfor,'')
          AND coalesce(ds.tipovenda,'')=coalesce(g.tipovenda,'')
          AND coalesce(ds.codcli,'')=coalesce(g.codcli,'')
          AND coalesce(ds.ramo,'')=coalesce(g.ramo,'')
          AND coalesce(ds.categoria_produto,'')=coalesce(g.categoria_produto,'');
        RETURN NULL;
    ELSE
        SELECT array_agg(codigo) INTO v_codes FROM new_products;
    END IF;
    IF COALESCE(array_length(v_codes,1),0) = 0 THEN RETURN NULL; END IF;
    PERFORM private.evolution_assert_admin();
    -- One rebuild per affected month per statement, not per product row.
    FOR v_period IN
        SELECT DISTINCT EXTRACT(YEAR FROM dtped)::int ano, EXTRACT(MONTH FROM dtped)::int mes
        FROM (
            SELECT dtped FROM public.data_detailed WHERE produto = ANY(v_codes)
            UNION ALL
            SELECT dtped FROM public.data_history WHERE produto = ANY(v_codes)
        ) s ORDER BY 1,2
    LOOP
        PERFORM public.refresh_summary_month(v_period.ano,v_period.mes);
        PERFORM public.refresh_cache_filters(v_period.ano,v_period.mes);
    END LOOP;
    RETURN NULL;
END;
$function$

