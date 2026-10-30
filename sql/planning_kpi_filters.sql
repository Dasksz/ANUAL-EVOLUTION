-- Apply after planning_unrouted.sql and planning_order.sql.
-- KPI totals remain scoped to day/team/search, while rows paginate by status.
CREATE OR REPLACE FUNCTION public.get_planning_filtered_v1(
 p_day text DEFAULT 'today',p_supervisor text DEFAULT NULL,p_seller text DEFAULT NULL,
 p_search text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 24,p_status text DEFAULT 'all')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE base jsonb;result jsonb;
BEGIN
 IF p_status IS NULL OR p_status NOT IN('all','no-sale','ideal','purchased') THEN
  RAISE EXCEPTION 'Classificação de planejamento inválida' USING ERRCODE='22023';
 END IF;
 -- Delegates authentication, approval, calendar and snapshot selection.
 base:=public.get_planning_day_v1(p_day,p_supervisor,p_seller,p_search,0,1);
 WITH filtered AS MATERIALIZED(
  SELECT summary r FROM public.planning_clients
  WHERE version=(base->>'version')::uuid
  AND(p_supervisor IS NULL OR supervisor_code=p_supervisor)
  AND(p_seller IS NULL OR seller_code=p_seller)
  AND(CASE WHEN p_day='unrouted' THEN jsonb_array_length(summary->'visitDates')=0
      ELSE summary->'visitDates' ? (base->>'planningDate') END)
  AND(coalesce(p_search,'')='' OR position(lower(p_search) in lower(summary->>'code'||' '||(summary->>'name')||' '||(summary->>'city')))>0)
  AND(CASE p_status WHEN 'no-sale' THEN (summary->>'currentMix')::integer=0
      WHEN 'ideal' THEN coalesce((summary->'mixIdeal'->>'achieved')::boolean,false)
      WHEN 'purchased' THEN (summary->>'currentMix')::integer>0 ELSE true END)
 ), page AS(SELECT r FROM filtered ORDER BY (r->>'missing')::integer DESC,r->>'name',r->>'code'
  OFFSET greatest(p_offset,0) LIMIT least(greatest(p_limit,1),100))
 SELECT jsonb_build_object('rows',coalesce((SELECT jsonb_agg(r) FROM page),'[]'::jsonb),'total',count(*))
 INTO result FROM filtered;
 RETURN base||result||jsonb_build_object('scopeTotal',base->'total','status',p_status);
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_filtered_v1(text,text,text,text,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_filtered_v1(text,text,text,text,integer,integer,text) TO authenticated;
