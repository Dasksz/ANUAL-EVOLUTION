-- Multi-seller daily portfolio and complete category matrix export.
CREATE OR REPLACE FUNCTION public.get_planning_portfolio_v1(
 p_day text DEFAULT 'today',p_supervisor text DEFAULT NULL,p_sellers text[] DEFAULT NULL,
 p_search text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 24,
 p_status text DEFAULT 'all',p_export boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE base jsonb;result jsonb;codes text[];finances jsonb;
BEGIN
 IF p_export AND p_day NOT IN('today','tomorrow') THEN RAISE EXCEPTION 'Exporte somente a carteira de hoje ou amanhã' USING ERRCODE='22023'; END IF;
 IF p_status IS NULL OR p_status NOT IN('all','no-sale','ideal','purchased') THEN RAISE EXCEPTION 'Classificação inválida' USING ERRCODE='22023'; END IF;
 base:=public.get_planning_day_v1(p_day,p_supervisor,NULL,p_search,0,1);
 IF p_export AND (coalesce((base->>'salesPending')::boolean,false) OR base->>'salesThrough' IS NULL OR coalesce((base->>'rosterPending')::boolean,false)) THEN RAISE EXCEPTION 'Aguarde a atualização da carteira e das vendas antes de exportar'; END IF;
 WITH scoped AS MATERIALIZED(
 SELECT c.* FROM public.planning_clients c WHERE version=(base->>'version')::uuid
 AND(p_supervisor IS NULL OR supervisor_code=p_supervisor)
 AND(coalesce(cardinality(p_sellers),0)=0 OR seller_code=ANY(p_sellers))
 AND(CASE WHEN p_day='unrouted' THEN jsonb_array_length(summary->'visitDates')=0 ELSE summary->'visitDates' ? (base->>'planningDate') END)
 AND(coalesce(p_search,'')='' OR position(lower(p_search) in lower(summary->>'code'||' '||(summary->>'name')||' '||(summary->>'city')))>0)
 ), filtered AS MATERIALIZED(
 SELECT * FROM scoped WHERE CASE p_status WHEN 'no-sale' THEN (summary->>'currentMix')::integer=0
 WHEN 'ideal' THEN coalesce((summary->'mixIdeal'->>'achieved')::boolean,false)
 WHEN 'purchased' THEN (summary->>'currentMix')::integer>0 ELSE true END
 ), page AS(
 SELECT * FROM filtered ORDER BY (summary->>'missing')::integer DESC,summary->>'name',code
 OFFSET CASE WHEN p_export THEN 0 ELSE greatest(p_offset,0) END
 LIMIT CASE WHEN p_export THEN NULL ELSE least(greatest(p_limit,1),100) END
 )
 SELECT jsonb_build_object('rows',coalesce((SELECT jsonb_agg(summary||CASE WHEN p_export THEN jsonb_build_object('categoryPresence',
 (SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('family',k->>'family','category',k->>'category')),'[]'::jsonb)
 FROM jsonb_array_elements(detail->'skus')k WHERE (k->>'current')::boolean AND nullif(k->>'category','') IS NOT NULL)) ELSE '{}'::jsonb END
 ORDER BY (summary->>'missing')::integer DESC,summary->>'name',code) FROM page),'[]'::jsonb),
 'total',(SELECT count(*) FROM filtered),'scopeTotal',count(*),'status',p_status,
 'kpis',jsonb_build_object('noSale',count(*)FILTER(WHERE (summary->>'currentMix')::integer=0),
 'mixIdealCount',count(*)FILTER(WHERE coalesce((summary->'mixIdeal'->>'achieved')::boolean,false)),
 'currentValue',coalesce(sum((summary->>'currentValue')::numeric),0))) INTO result FROM scoped;
 IF p_export THEN
  result:=result||jsonb_build_object('categoryCatalog',(SELECT coalesce(jsonb_agg(jsonb_build_object('family',family,'category',category) ORDER BY family,category),'[]'::jsonb)
  FROM(SELECT DISTINCT CASE WHEN codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family,categoria_produto category
   FROM public.dim_produtos WHERE codfor IN('707','708','752','1119') AND nullif(btrim(categoria_produto),'') IS NOT NULL
   UNION SELECT k->>'family',k->>'category' FROM public.planning_clients c CROSS JOIN LATERAL jsonb_array_elements(c.detail->'skus')k
   WHERE c.version=(base->>'version')::uuid AND k->>'family' IN('SALTY','FOODS') AND nullif(k->>'category','') IS NOT NULL)x));
 END IF;
 IF p_export AND jsonb_array_length(result->'rows')>0 THEN
  SELECT array_agg(r->>'code') INTO codes FROM jsonb_array_elements(result->'rows')r;
  finances:=private.planning_financial_fetch_v1(base->>'month',codes);
  result:=result||jsonb_build_object('rows',(SELECT jsonb_agg(r||(finances->'clients'->(r->>'code')) ORDER BY ord)
   FROM jsonb_array_elements(result->'rows') WITH ORDINALITY AS x(r,ord)),
   'financialReadAt',finances->'readAt','goalsAvailable',finances->'goalsAvailable');
 END IF;
 RETURN base||result;
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_portfolio_v1(text,text,text[],text,integer,integer,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_portfolio_v1(text,text,text[],text,integer,integer,text,boolean) TO authenticated;
