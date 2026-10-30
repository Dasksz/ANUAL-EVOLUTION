BEGIN;
SET LOCAL statement_timeout='15s';
DO $$
DECLARE mismatch integer;
BEGIN
 WITH flags AS(
 SELECT codcli,max(has_cheetos)=1 AND max(has_doritos)=1 AND max(has_fandangos)=1 AND max(has_ruffles)=1 AND max(has_torcida)=1 salty,
 max(has_toddy)=1 AND max(has_toddynho)=1 foods
 FROM public.data_summary_frequency_current WHERE ano=extract(year from now() AT TIME ZONE 'America/Bahia') AND mes=extract(month from now() AT TIME ZONE 'America/Bahia') AND tipovenda NOT IN('5','11') GROUP BY codcli)
 SELECT count(*) INTO mismatch FROM public.planning_clients c LEFT JOIN flags f ON f.codcli=c.code
 WHERE (c.summary->'mixIdeal'->>'achieved')::boolean IS DISTINCT FROM coalesce(f.salty AND f.foods,false)
 OR (c.summary->'mixIdeal'->>'foods')::boolean IS DISTINCT FROM coalesce(f.foods,false);
 IF mismatch>0 THEN RAISE EXCEPTION 'Planning ideal differs from five Salty + Toddy/Toddynho: %',mismatch; END IF;
 WITH raw AS MATERIALIZED(SELECT codusur,codcli,codfor,categoria_produto,vlvenda FROM public.data_summary_current WHERE ano=extract(year from now() AT TIME ZONE 'America/Bahia') AND mes=extract(month from now() AT TIME ZONE 'America/Bahia')),
 base AS(SELECT codusur,count(*) n FROM(SELECT codusur,codcli FROM raw WHERE codfor IN('707','708','752') GROUP BY 1,2 HAVING sum(vlvenda)>=1)t GROUP BY 1),
 cats AS(SELECT codusur,categoria_produto,count(*) n FROM(SELECT codusur,codcli,categoria_produto FROM raw GROUP BY 1,2,3 HAVING sum(vlvenda)>=1)t GROUP BY 1,2)
 SELECT count(*) INTO mismatch FROM public.planning_clients c CROSS JOIN LATERAL jsonb_array_elements((c.detail->'skus')||(c.detail->'suggestions'))s
 LEFT JOIN public.dim_produtos p ON p.codigo=s->>'code' LEFT JOIN base b ON b.codusur=c.seller_code LEFT JOIN cats ct ON ct.codusur=c.seller_code AND ct.categoria_produto=p.categoria_produto
 WHERE (s->>'sharePositivity')::numeric IS DISTINCT FROM CASE WHEN nullif(btrim(p.categoria_produto),'') IS NOT NULL AND b.n>0 THEN coalesce(ct.n,0)::numeric/b.n*100 END;
 IF mismatch>0 THEN RAISE EXCEPTION 'Category Share priority is incorrect for % SKUs',mismatch; END IF;
 IF EXISTS(SELECT 1 FROM public.planning_clients c CROSS JOIN LATERAL jsonb_array_elements(c.detail->'skus')s WHERE s->>'idealCategory' IN('QUAKER','KEROCOCO')) THEN RAISE EXCEPTION 'Quaker/Kerococo included in ideal'; END IF;
 IF has_function_privilege('authenticated','private.planning_order_enrich()','EXECUTE') THEN RAISE EXCEPTION 'Internal enrichment exposed'; END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='1s';
DO $$
DECLARE d jsonb;n integer;
BEGIN
 d:=public.get_planning_v1();SELECT count(*) INTO n FROM public.planning_clients WHERE(summary->'mixIdeal'->>'achieved')::boolean;
 IF (d->'kpis'->>'mixIdealCount')::integer<>n THEN RAISE EXCEPTION 'Ideal KPI mismatch'; END IF;
END;$$;
ROLLBACK;
