-- Apply after planning_refresh.sql. The browser cannot choose a different route day.
CREATE OR REPLACE FUNCTION public.get_planning_today_v1(p_supervisor text DEFAULT NULL,p_seller text DEFAULT NULL,p_search text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 24)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE today text:=to_char(now() AT TIME ZONE 'America/Bahia','YYYY-MM-DD');result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 result:=public.get_planning_v1(p_supervisor,p_seller,today,p_search,p_offset,p_limit);
 RETURN result||jsonb_build_object('planningDate',today,'rosterPending',result->>'month'<>left(today,7));
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_today_v1(text,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_today_v1(text,text,text,integer,integer) TO authenticated;
