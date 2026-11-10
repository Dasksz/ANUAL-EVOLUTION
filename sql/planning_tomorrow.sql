-- Apply after planning_unrouted.sql. Relative dates use the Bahia calendar.
CREATE OR REPLACE FUNCTION public.get_planning_day_v1(p_day text DEFAULT 'today',p_supervisor text DEFAULT NULL,p_seller text DEFAULT NULL,p_search text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 24)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE target text;result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 IF p_day IS NULL OR p_day NOT IN('today','yesterday','tomorrow','unrouted') THEN RAISE EXCEPTION 'Selecione hoje, ontem, amanhã ou sem roteirização' USING ERRCODE='22023'; END IF;
 target:=to_char((now() AT TIME ZONE 'America/Bahia')::date+CASE p_day WHEN 'yesterday' THEN -1 WHEN 'tomorrow' THEN 1 ELSE 0 END,'YYYY-MM-DD');
 result:=public.get_planning_v1(p_supervisor,p_seller,CASE WHEN p_day='unrouted' THEN '__unrouted__' ELSE target END,p_search,p_offset,p_limit);
 RETURN result||jsonb_build_object('planningDate',target,'planningDay',p_day,'rosterPending',NOT coalesce(result->'routeDates' ? target,false));
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_day_v1(text,text,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_day_v1(text,text,text,text,integer,integer) TO authenticated;
