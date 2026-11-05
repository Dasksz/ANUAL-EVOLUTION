-- Keep raw import evidence independent from the current-supervisor projection.
CREATE TABLE private.current_seller_supervisors(codusur text PRIMARY KEY,codsupervisor text NOT NULL);
ALTER TABLE private.current_seller_supervisors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.current_seller_supervisors FROM PUBLIC,anon,authenticated;
DO $$ DECLARE t text; v text; BEGIN
 FOR t IN SELECT unnest(ARRAY['data_detailed_current','data_summary_current']) LOOP
  SELECT pg_get_viewdef(format('public.%I',t)::regclass,true) INTO v;
  -- A client still marked RCA 53 is inactive unless it belongs to an explicit special portfolio.
  v:=replace(v,'CASE COALESCE(NULLIF(c.rca1',
   'CASE WHEN d.codusur LIKE ''INAT_%'' AND coalesce(c.rca1,''53'') IN ('''',''53'') THEN d.codusur ELSE CASE COALESCE(NULLIF(c.rca1');
  v:=replace(v,'END AS codusur','END END AS codusur');
  EXECUTE format('CREATE VIEW private.%I AS %s','supervisor_evidence_'||t,v);
  EXECUTE format('REVOKE ALL ON private.%I FROM PUBLIC,anon,authenticated','supervisor_evidence_'||t);
 END LOOP;
END $$;
DO $$ DECLARE v text; BEGIN
 SELECT pg_get_functiondef('private.evolution_goals_supervisor_by_seller()'::regprocedure) INTO v;
 v:=replace(v,'public.data_detailed_current','private.supervisor_evidence_data_detailed_current');
 v:=replace(v,'public.data_summary_current','private.supervisor_evidence_data_summary_current');
 EXECUTE v;
END $$;
CREATE FUNCTION private.refresh_current_seller_supervisors() RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 INSERT INTO private.current_seller_supervisors SELECT * FROM private.evolution_goals_supervisor_by_seller()
 ON CONFLICT(codusur) DO UPDATE SET codsupervisor=excluded.codsupervisor;
 INSERT INTO private.current_seller_supervisors VALUES('BH','8'),('BALCAO_SP','8'),('53','8'),('AMERICANAS','SV_AMERICANAS'),('INAT_INATIVOS','SEM_SUPERVISOR')
 ON CONFLICT(codusur) DO UPDATE SET codsupervisor=excluded.codsupervisor;
END $$;
REVOKE ALL ON FUNCTION private.refresh_current_seller_supervisors() FROM PUBLIC,anon,authenticated;
INSERT INTO public.dim_supervisores(codigo,nome) VALUES('SEM_SUPERVISOR','SEM SUPERVISOR ATUAL') ON CONFLICT(codigo) DO NOTHING;
SELECT private.refresh_current_seller_supervisors();
DO $$ DECLARE t text; v text; cols text; BEGIN
 FOR t IN SELECT unnest(ARRAY['data_summary_current','data_summary_frequency_current','data_detailed_current','data_history_current']) LOOP
  SELECT pg_get_viewdef(format('public.%I',t)::regclass,true) INTO v;
  v:=replace(v,'CASE COALESCE(NULLIF(c.rca1',
   'CASE WHEN d.codusur LIKE ''INAT_%'' AND coalesce(c.rca1,''53'') IN ('''',''53'') THEN d.codusur ELSE CASE COALESCE(NULLIF(c.rca1');
  v:=replace(v,'END AS codusur','END END AS codusur');
  SELECT string_agg(CASE WHEN attname='codsupervisor' THEN 'coalesce(m.codsupervisor,q.codsupervisor) AS codsupervisor' ELSE 'q.'||quote_ident(attname) END,',' ORDER BY attnum)
  INTO cols FROM pg_attribute WHERE attrelid=format('public.%I',t)::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('CREATE OR REPLACE VIEW public.%I AS SELECT %s FROM (%s) q LEFT JOIN private.current_seller_supervisors m ON m.codusur=q.codusur',t,cols,rtrim(v,E';\n\r '));
 END LOOP;
 -- Goal quotas follow the same current supervisor as sales.
 FOR t IN SELECT unnest(ARRAY['evolution_client_goal_ownership','evolution_client_goal_totals']) LOOP
  SELECT pg_get_viewdef(format('private.%I',t)::regclass,true) INTO v;
  SELECT string_agg(CASE WHEN attname='owner_parent' THEN 'coalesce(m.codsupervisor,q.owner_parent) AS owner_parent' ELSE 'q.'||quote_ident(attname) END,',' ORDER BY attnum)
  INTO cols FROM pg_attribute WHERE attrelid=format('private.%I',t)::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('CREATE OR REPLACE VIEW private.%I AS SELECT %s FROM (%s) q LEFT JOIN private.current_seller_supervisors m ON m.codusur=q.owner_code',t,cols,rtrim(v,E';\n\r '));
 END LOOP;
END $$;
-- Every import refresh resolves current ownership before rebuilding dropdowns.
DO $$ DECLARE v text; BEGIN
 SELECT pg_get_functiondef('public.refresh_cache_filters(integer,integer)'::regprocedure) INTO v;
 v:=replace(v,'r RECORD;','r RECORD; assignment_before text;');
 v:=replace(v,'PERFORM private.evolution_assert_admin();',$patch$
 PERFORM private.evolution_assert_admin();
 SELECT md5(coalesce(string_agg(codusur||'/'||codsupervisor,',' ORDER BY codusur),'')) INTO assignment_before FROM private.current_seller_supervisors;
 PERFORM private.refresh_current_seller_supervisors();
 IF assignment_before IS DISTINCT FROM (SELECT md5(coalesce(string_agg(codusur||'/'||codsupervisor,',' ORDER BY codusur),'')) FROM private.current_seller_supervisors) THEN
  p_ano:=NULL; p_mes:=NULL;
  UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp();
 END IF;
 $patch$);
 v:=replace(v,'FROM public.data_summary','FROM public.data_summary_current');
 EXECUTE v;
 SELECT pg_get_functiondef('private.bh_reconcile()'::regprocedure) INTO v;
 v:=replace(v,'FROM public.data_summary s JOIN','FROM public.data_summary_current s JOIN');
 EXECUTE v;
END $$;
SELECT public.refresh_cache_filters();
UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp();
