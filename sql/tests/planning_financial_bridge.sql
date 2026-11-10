-- Run on EVOLUTION after provisioning the dedicated bridge token.
BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE d jsonb;r jsonb;finances jsonb;codes text[];expected numeric;
BEGIN
 d:=public.get_planning_portfolio_v1(p_export=>true);
 SELECT array_agg(x->>'code') INTO codes FROM jsonb_array_elements(d->'rows')x;
 finances:=private.planning_financial_fetch_v1(d->>'month',codes);
 FOR r IN SELECT value FROM jsonb_array_elements(d->'rows') LOOP
  IF r->'overdue' IS DISTINCT FROM finances->'clients'->(r->>'code')->'overdue'
  OR r->'revenueGoal' IS DISTINCT FROM finances->'clients'->(r->>'code')->'revenueGoal' THEN RAISE EXCEPTION 'Financial enrichment differs';END IF;
  SELECT (summary->>'averageValue')::numeric INTO expected FROM public.planning_clients WHERE code=r->>'code';
  IF (r->>'averageValue')::numeric IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Historical average changed';END IF;
  SELECT (summary->>'currentValue')::numeric INTO expected FROM public.planning_clients WHERE code=r->>'code';
  IF (r->>'currentValue')::numeric IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Current revenue changed';END IF;
 END LOOP;
END;$$;
ROLLBACK;
