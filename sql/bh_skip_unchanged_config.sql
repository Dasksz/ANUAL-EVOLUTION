-- An unchanged save must not audit, update timestamps or reconcile data.
DO $$ DECLARE def text; anchor text := 'PERFORM pg_advisory_xact_lock(20261105,53);'; BEGIN
 SELECT pg_get_functiondef('public.bh_portfolio_config(integer,jsonb)'::regprocedure) INTO def;
 IF position(anchor IN def)=0 THEN RAISE EXCEPTION 'Unexpected BH configuration function'; END IF;
 def:=replace(def,anchor,anchor||$patch$
  IF (SELECT jsonb_agg(jsonb_build_array(btrim(e->>'code'),(e->>'percent')::numeric) ORDER BY btrim(e->>'code'))
       FROM private.special_portfolio_versions v,jsonb_array_elements(v.clients)e WHERE v.start_ym=p_start_ym)
     = (SELECT jsonb_agg(jsonb_build_array(btrim(e->>'code'),(e->>'percent')::numeric) ORDER BY btrim(e->>'code')) FROM jsonb_array_elements(p_clients)e) THEN
   SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY start_ym),'[]') INTO result FROM private.special_portfolio_versions v;
   RETURN result;
  END IF;
 $patch$);
 EXECUTE def;
END $$;
