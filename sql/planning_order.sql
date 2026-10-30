-- Apply after planning_unrouted.sql. Planning-only ideal: five Salty brands and Toddy/Toddynho.
CREATE OR REPLACE FUNCTION private.planning_order_enrich()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE y integer:=extract(year FROM now() AT TIME ZONE 'America/Bahia');mo integer:=extract(month FROM now() AT TIME ZONE 'America/Bahia');
BEGIN
 -- Same default Share measure: net >= R$1 per client/category divided by Salty-positive clients.
 CREATE TEMP TABLE pl_order_share ON COMMIT DROP AS
 WITH raw AS MATERIALIZED(SELECT codusur,codcli,codfor,categoria_produto,vlvenda FROM public.data_summary_current WHERE ano=y AND mes=mo),
 base AS(SELECT codusur,codcli FROM raw WHERE codfor IN('707','708','752') GROUP BY 1,2 HAVING sum(vlvenda)>=1),
 denominators AS(SELECT codusur,count(*) n FROM base GROUP BY 1),
 category_clients AS(SELECT codusur,codcli,coalesce(categoria_produto,'SEM CATEGORIA') category FROM raw GROUP BY 1,2,3 HAVING sum(vlvenda)>=1)
 SELECT c.codusur,c.category,count(*) buyers,coalesce(d.n,0) base,
 CASE WHEN d.n>0 THEN count(*)::numeric/d.n*100 END positivity
 FROM category_clients c LEFT JOIN denominators d ON d.codusur=c.codusur GROUP BY c.codusur,c.category,d.n;
 CREATE UNIQUE INDEX ON pl_order_share(codusur,category);
 CREATE TEMP TABLE pl_order_base ON COMMIT DROP AS
 SELECT codusur,count(*) n FROM(SELECT codusur,codcli FROM public.data_summary_current WHERE ano=y AND mes=mo AND codfor IN('707','708','752') GROUP BY 1,2 HAVING sum(vlvenda)>=1)t GROUP BY 1;
 CREATE UNIQUE INDEX ON pl_order_base(codusur);
 CREATE TEMP TABLE pl_order_ideal ON COMMIT DROP AS
 WITH flags AS(
 SELECT codcli,max(has_cheetos) cheetos,max(has_doritos) doritos,max(has_fandangos) fandangos,max(has_ruffles) ruffles,max(has_torcida) torcida,
 max(has_toddy) toddy,max(has_toddynho) toddynho
 FROM public.data_summary_frequency_current WHERE ano=y AND mes=mo AND tipovenda NOT IN('5','11') GROUP BY codcli
 ), presence AS(
 SELECT c.code,coalesce(f.cheetos,0)=1 cheetos,coalesce(f.doritos,0)=1 doritos,coalesce(f.fandangos,0)=1 fandangos,
 coalesce(f.ruffles,0)=1 ruffles,coalesce(f.torcida,0)=1 torcida,coalesce(f.toddy,0)=1 toddy,coalesce(f.toddynho,0)=1 toddynho
 FROM public.planning_clients c LEFT JOIN flags f ON f.codcli=c.code
 )
 SELECT p.code,jsonb_build_object('salty',cheetos AND doritos AND fandangos AND ruffles AND torcida,'foods',toddy AND toddynho,
 'achieved',cheetos AND doritos AND fandangos AND ruffles AND torcida AND toddy AND toddynho,
 'saltyCount',cheetos::integer+doritos::integer+fandangos::integer+ruffles::integer+torcida::integer,
 'foodsCount',toddy::integer+toddynho::integer,
 'present',(SELECT jsonb_agg(name ORDER BY ord) FROM(VALUES(1,'CHEETOS',cheetos),(2,'DORITOS',doritos),(3,'FANDANGOS',fandangos),(4,'RUFFLES',ruffles),(5,'TORCIDA',torcida),(6,'TODDY',toddy),(7,'TODDYNHO',toddynho))v(ord,name,bought) WHERE bought),
 'missing',(SELECT coalesce(jsonb_agg(name ORDER BY ord),'[]') FROM(VALUES(1,'CHEETOS',cheetos),(2,'DORITOS',doritos),(3,'FANDANGOS',fandangos),(4,'RUFFLES',ruffles),(5,'TORCIDA',torcida),(6,'TODDY',toddy),(7,'TODDYNHO',toddynho))v(ord,name,bought) WHERE NOT bought)) ideal
 FROM presence p;
 CREATE UNIQUE INDEX ON pl_order_ideal(code);
 UPDATE public.planning_clients c SET summary=c.summary||jsonb_build_object('mixIdeal',i.ideal,'orderSchema',1),
 detail=c.detail||jsonb_build_object('skus',enriched.skus,'suggestions',enriched.suggestions)
 FROM pl_order_ideal i CROSS JOIN LATERAL(
 SELECT
 (SELECT coalesce(jsonb_agg(s||jsonb_build_object('category',pr.categoria_produto,'idealCategory',CASE WHEN upper(pr.mix_marca) IN('CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA','TODDY','TODDYNHO') THEN upper(pr.mix_marca) END,
 'sharePositivity',CASE WHEN nullif(btrim(pr.categoria_produto),'') IS NOT NULL AND b.n>0 THEN coalesce(sh.positivity,0) END,'shareBuyers',coalesce(sh.buyers,0),'shareBase',coalesce(b.n,0)) ORDER BY ord),'[]')
 FROM public.planning_clients source CROSS JOIN LATERAL jsonb_array_elements(source.detail->'skus') WITH ORDINALITY r(s,ord)
 LEFT JOIN public.dim_produtos pr ON pr.codigo=s->>'code' LEFT JOIN pl_order_base b ON b.codusur=source.seller_code
 LEFT JOIN pl_order_share sh ON sh.codusur=source.seller_code AND sh.category=pr.categoria_produto WHERE source.code=i.code) skus,
 (SELECT coalesce(jsonb_agg(s||jsonb_build_object('category',pr.categoria_produto,'idealCategory',CASE WHEN upper(pr.mix_marca) IN('CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA','TODDY','TODDYNHO') THEN upper(pr.mix_marca) END,
 'sharePositivity',CASE WHEN nullif(btrim(pr.categoria_produto),'') IS NOT NULL AND b.n>0 THEN coalesce(sh.positivity,0) END,'shareBuyers',coalesce(sh.buyers,0),'shareBase',coalesce(b.n,0)) ORDER BY ord),'[]')
 FROM public.planning_clients source CROSS JOIN LATERAL jsonb_array_elements(source.detail->'suggestions') WITH ORDINALITY r(s,ord)
 LEFT JOIN public.dim_produtos pr ON pr.codigo=s->>'code' LEFT JOIN pl_order_base b ON b.codusur=source.seller_code
 LEFT JOIN pl_order_share sh ON sh.codusur=source.seller_code AND sh.category=pr.categoria_produto WHERE source.code=i.code) suggestions
 )enriched WHERE c.code=i.code;
END;$$;
REVOKE ALL ON FUNCTION private.planning_order_enrich() FROM PUBLIC,anon,authenticated;

DO $install$
DECLARE definition text;
BEGIN
 definition:=pg_get_functiondef('private.planning_rebuild(boolean)'::regprocedure);
 IF position('private.planning_order_enrich()' in definition)=0 THEN
  definition:=replace(definition,' GET DIAGNOSTICS n=ROW_COUNT;',' GET DIAGNOSTICS n=ROW_COUNT;'||chr(10)||' PERFORM private.planning_order_enrich();');
  -- One segment opportunity per brand/category, instead of eight variations of popular brands.
  definition:=replace(definition,' SELECT pe.produto code,pr.descricao name,CASE WHEN pr.codfor',
  ' SELECT DISTINCT ON(coalesce(nullif(pr.mix_marca,''''),pr.categoria_produto)) pe.produto code,pr.descricao name,CASE WHEN pr.codfor');
  definition:=replace(definition,' ORDER BY pe.buyers DESC,pe.produto LIMIT 8)x',' ORDER BY coalesce(nullif(pr.mix_marca,''''),pr.categoria_produto),pe.buyers DESC,pe.produto)x');
  EXECUTE definition;
 END IF;
 definition:=pg_get_functiondef('public.get_planning_v1(text,text,text,text,integer,integer)'::regprocedure);
 IF position('mixIdealCount' in definition)=0 THEN
  definition:=replace(definition,$old$'kpis',jsonb_build_object('noSale',$old$,$new$'kpis',jsonb_build_object('mixIdealCount',count(*) FILTER(WHERE coalesce((r->'mixIdeal'->>'achieved')::boolean,false)),'noSale',$new$);
  EXECUTE definition;
 END IF;
END;$install$;
