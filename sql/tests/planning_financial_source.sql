-- Run on PROMOTORES; tests do not change sales, goals or titles.
BEGIN;
DO $$
BEGIN
 IF private.planning_revenue_goal_v1(NULL) IS NOT NULL THEN RAISE EXCEPTION 'Missing goal became zero';END IF;
 IF private.planning_revenue_goal_v1('{"707":{"fat":0}}')<>0 THEN RAISE EXCEPTION 'Zero goal lost';END IF;
 IF private.planning_revenue_goal_v1('{"707":{"fat":100},"708":{"fat":200},"752":{"fat":30},"total_elma":{"fat":330},"1119_TODDY":{"fat":10},"1119_TODDYNHO":{"fat":20},"1119_QUAKER_KEROCOCO":{"fat":30},"total_foods":{"fat":60},"pepsico_all":{"fat":390}}')<>390 THEN RAISE EXCEPTION 'Goal totals double counted';END IF;
 IF private.planning_revenue_goal_v1('{"total_elma":{"fat":100},"total_foods":{"fat":200}}')<>300 THEN RAISE EXCEPTION 'Aggregate legacy goal lost';END IF;
 BEGIN PERFORM public.planning_financial_source_v1('2026-11',ARRAY['27'],repeat('0',64));RAISE EXCEPTION 'Unauthorized financial read accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF has_table_privilege('anon','private.planning_financial_bridge_config','SELECT') OR has_table_privilege('authenticated','private.planning_financial_bridge_config','SELECT') THEN RAISE EXCEPTION 'Bridge configuration exposed';END IF;
END;$$;
ROLLBACK;
