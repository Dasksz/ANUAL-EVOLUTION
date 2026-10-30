CREATE OR REPLACE FUNCTION private.commercial_health_mix_classify(r jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 WITH rule AS (
  SELECT coalesce(r->>'sourceStatus',r->>'status') source_status,
   coalesce(coalesce(r->>'sourceStatus',r->>'status')='CRÍTICO' AND (r->>'mixHistorical')::numeric>0 AND (r->>'mixPrevious')::numeric>=(r->>'mixHistorical')::numeric*1.5,false) expanded
 )
 SELECT r||jsonb_build_object('sourceStatus',source_status,'status',CASE WHEN expanded THEN 'ANALISAR' ELSE source_status END,'mixReclassified',expanded) FROM rule;
$$;
REVOKE ALL ON FUNCTION private.commercial_health_mix_classify(jsonb) FROM PUBLIC,anon,authenticated;

-- Reclassify the current valid snapshot without pretending to have reread Sheets.
DO $$
BEGIN
 PERFORM pg_advisory_xact_lock(17890101,851597314);
 UPDATE public.commercial_health_sync SET payload=jsonb_set(payload,'{rows}',
 (SELECT jsonb_agg(private.commercial_health_mix_classify(r) ORDER BY ord)
 FROM jsonb_array_elements(payload->'rows') WITH ORDINALITY t(r,ord)))
 WHERE id=true AND payload IS NOT NULL;
END;$$;
