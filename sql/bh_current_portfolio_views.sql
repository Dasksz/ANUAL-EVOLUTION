-- Current-portfolio views must honor explicit virtual assignment before cadastro RCA.
DO $$ DECLARE t text; v text; BEGIN
 FOR t IN SELECT unnest(ARRAY['data_summary_current','data_summary_frequency_current','data_detailed_current','data_history_current']) LOOP
  SELECT pg_get_viewdef(format('public.%I',t)::regclass,true) INTO v;
  IF position('CASE COALESCE(NULLIF(c.rca1' IN v)=0 THEN RAISE EXCEPTION 'Unexpected current-portfolio view: %',t; END IF;
  v:=replace(v,'CASE COALESCE(NULLIF(c.rca1', 'CASE WHEN d.codusur = ''BH'' THEN ''BH''::text ELSE CASE COALESCE(NULLIF(c.rca1');
  v:=replace(v,'END AS codusur','END END AS codusur');
  v:=replace(v,'COALESCE(NULLIF(c.codsupervisor, ''''::text), d.codsupervisor) AS codsupervisor',
   'CASE WHEN d.codusur = ''BH'' THEN ''8''::text ELSE COALESCE(NULLIF(c.codsupervisor, ''''::text), d.codsupervisor) END AS codsupervisor');
  EXECUTE format('CREATE OR REPLACE VIEW public.%I AS %s',t,v);
 END LOOP;
END $$;
UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp();
