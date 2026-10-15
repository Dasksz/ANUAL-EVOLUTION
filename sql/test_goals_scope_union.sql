-- Read-only regression checks for the audited September 2026 period.
-- Run as an approved dashboard user or the project administrator.
DO $$
DECLARE baseline jsonb; actual jsonb; cheetos jsonb;
BEGIN
 baseline:=public.get_metas_base_comparativo_multi(2026,9);
 actual:=public.get_metas_base_comparativo_multi(2026,9,ARRAY['05','08']);
 IF baseline IS DISTINCT FROM actual THEN RAISE EXCEPTION 'Selecting both branches changed the full target/base'; END IF;
 actual:=public.get_metas_base_comparativo_multi(2026,9,'{}',ARRAY['707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO']);
 IF baseline IS DISTINCT FROM actual THEN RAISE EXCEPTION 'Selecting all suppliers changed the full target/base'; END IF;
 cheetos:=public.get_metas_base_comparativo_multi(2026,9,'{}','{}','{}','{}',ARRAY['CHEETOS']);
 actual:=public.get_metas_base_comparativo_multi(2026,9,'{}','{}','{}','{}',ARRAY['CHEETOS','CHEETOS CRUNCHY','CHEETOS']);
 IF cheetos IS DISTINCT FROM actual THEN RAISE EXCEPTION 'Overlapping categories or duplicate selections duplicated the base'; END IF;
 actual:=public.get_metas_base_comparativo_multi(2026,9,'{}','{}',ARRAY['IMPOSSIVEL'],ARRAY['AMERICANAS']);
 IF jsonb_array_length(actual->'sellers')<>0 OR jsonb_array_length(actual->'metas')<>0 THEN RAISE EXCEPTION 'Incompatible dimensions leaked sales or targets'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(baseline->'metas') m GROUP BY m->>'codusur',m->>'categoria',m->>'metrica' HAVING count(*)>1) THEN RAISE EXCEPTION 'An imported target was counted twice'; END IF;
END; $$;
