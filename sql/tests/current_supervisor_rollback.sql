BEGIN;
CREATE TEMP TABLE totals_before AS SELECT ano,mes,count(*) n,sum(vlvenda) fat,sum(peso) peso FROM public.data_summary_current GROUP BY ano,mes;
-- A newly identified current assignment must invalidate historical dropdowns too.
UPDATE private.current_seller_supervisors SET codsupervisor='8' WHERE codusur='190';
SELECT public.refresh_cache_filters(2026,11);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.data_summary_current WHERE codusur IN ('190','286','313','318') AND codsupervisor='8') THEN RAISE EXCEPTION 'Historical supervisor leaked'; END IF;
 IF EXISTS(SELECT 1 FROM public.cache_filters WHERE superv='BALCAO' AND nome NOT IN ('BALCAO','BH')) THEN RAISE EXCEPTION 'Historical dropdown remained stale'; END IF;
 IF EXISTS(SELECT 1 FROM totals_before b FULL JOIN (SELECT ano,mes,count(*) n,sum(vlvenda) fat,sum(peso) peso FROM public.data_summary_current GROUP BY ano,mes) a USING(ano,mes) WHERE a.n IS DISTINCT FROM b.n OR a.fat IS DISTINCT FROM b.fat OR a.peso IS DISTINCT FROM b.peso) THEN RAISE EXCEPTION 'Company totals changed'; END IF;
END $$;
ROLLBACK;
