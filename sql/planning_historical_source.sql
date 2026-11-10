-- Include historical months retained in the current upload without double counting.
BEGIN;
SELECT pg_advisory_xact_lock(17890101,415990480);
DO $install$
DECLARE definition text;result jsonb;
BEGIN
 definition:=pg_get_functiondef('private.planning_rebuild(boolean)'::regprocedure);
 IF position('WITH current_months AS MATERIALIZED(' in definition)=0 THEN
  IF position($old$ -- Each month has one authoritative source. No union of overlapping history/current months.
 CREATE TEMP TABLE pl_sales ON COMMIT DROP AS
 SELECT s.*,CASE WHEN codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family
 FROM (
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_history
 WHERE dtped>=(m-interval '3 months') AT TIME ZONE 'UTC' AND dtped<m::timestamp AT TIME ZONE 'UTC'
 UNION ALL
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_detailed
 WHERE dtped>=m::timestamp AT TIME ZONE 'UTC' AND dtped<(today+1)::timestamp AT TIME ZONE 'UTC'
 )s WHERE codfor IN('707','708','752','1119') AND tipovenda IN('1','9');
$old$ in definition)=0 THEN RAISE EXCEPTION 'Unexpected Planning sales source; migration not applied';END IF;
  EXECUTE replace(definition,$old$ -- Each month has one authoritative source. No union of overlapping history/current months.
 CREATE TEMP TABLE pl_sales ON COMMIT DROP AS
 SELECT s.*,CASE WHEN codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family
 FROM (
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_history
 WHERE dtped>=(m-interval '3 months') AT TIME ZONE 'UTC' AND dtped<m::timestamp AT TIME ZONE 'UTC'
 UNION ALL
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_detailed
 WHERE dtped>=m::timestamp AT TIME ZONE 'UTC' AND dtped<(today+1)::timestamp AT TIME ZONE 'UTC'
 )s WHERE codfor IN('707','708','752','1119') AND tipovenda IN('1','9');
$old$,$new$ -- Prefer the current upload for every month it contains, including historical months.
 -- Fall back to data_history only for months absent from the current upload.
 CREATE TEMP TABLE pl_sales ON COMMIT DROP AS
 WITH current_months AS MATERIALIZED(
  SELECT DISTINCT date_trunc('month',dtped AT TIME ZONE 'UTC')::date month_start
  FROM public.data_detailed
  WHERE dtped>=(m-interval '3 months') AT TIME ZONE 'UTC'
    AND dtped<(today+1)::timestamp AT TIME ZONE 'UTC'
 ), source_rows AS(
  SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_detailed
  WHERE dtped>=(m-interval '3 months') AT TIME ZONE 'UTC'
    AND dtped<(today+1)::timestamp AT TIME ZONE 'UTC'
  UNION ALL
  SELECT h.codcli,h.produto,h.codfor,h.dtped,h.tipovenda,h.vlvenda,h.qtvenda FROM public.data_history h
  WHERE h.dtped>=(m-interval '3 months') AT TIME ZONE 'UTC'
    AND h.dtped<m::timestamp AT TIME ZONE 'UTC'
    AND NOT EXISTS(SELECT 1 FROM current_months cm
      WHERE h.dtped>=cm.month_start::timestamp AT TIME ZONE 'UTC'
        AND h.dtped<(cm.month_start+interval '1 month')::timestamp AT TIME ZONE 'UTC')
 )
 SELECT s.*,CASE WHEN codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family
 FROM source_rows s WHERE codfor IN('707','708','752','1119') AND tipovenda IN('1','9');
$new$);
 END IF;
 result:=private.planning_rebuild(false);
 IF result->>'status' IS DISTINCT FROM 'synced' THEN RAISE EXCEPTION 'Planning refresh failed: %',result;END IF;
END $install$;
COMMIT;

