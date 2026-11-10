CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC,anon,authenticated;
-- Run on PROMOTORES. Dedicated, read-only Evolution bridge; no service-role key is shared.
CREATE TABLE IF NOT EXISTS private.planning_financial_bridge_config(
 id boolean PRIMARY KEY DEFAULT true CHECK(id),token_hash text NOT NULL CHECK(token_hash~'^[0-9a-f]{64}$')
);
ALTER TABLE private.planning_financial_bridge_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.planning_financial_bridge_config FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION private.planning_revenue_goal_v1(g jsonb)
RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT CASE WHEN g IS NULL OR g='null'::jsonb THEN NULL ELSE
 CASE WHEN g ?| ARRAY['707','708','752'] THEN coalesce((g#>>'{707,fat}')::numeric,0)+coalesce((g#>>'{708,fat}')::numeric,0)+coalesce((g#>>'{752,fat}')::numeric,0)
 ELSE coalesce((g#>>'{total_elma,fat}')::numeric,0) END
 +CASE WHEN g ?| ARRAY['1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO'] THEN
 coalesce((g#>>'{1119_TODDY,fat}')::numeric,0)+coalesce((g#>>'{1119_TODDYNHO,fat}')::numeric,0)+coalesce((g#>>'{1119_QUAKER_KEROCOCO,fat}')::numeric,0)
 ELSE coalesce((g#>>'{total_foods,fat}')::numeric,(g#>>'{FOODS_ALL,fat}')::numeric,(g#>>'{1119,fat}')::numeric,0) END END
$$;
REVOKE ALL ON FUNCTION private.planning_revenue_goal_v1(jsonb) FROM PUBLIC,anon,authenticated;
-- Same current-month default used by Promotores calculateGoalsMetrics().
CREATE OR REPLACE FUNCTION private.planning_live_revenue_goals_v1(p_month text,p_codes text[])
RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 WITH codes AS(SELECT DISTINCT c code FROM unnest(p_codes)c), totals AS(
 SELECT coalesce(nullif(ltrim(h.codcli,'0'),''),'0') code,sum(h.vlvenda) revenue
 FROM public.data_history h LEFT JOIN public.dim_produtos p ON p.codigo=h.produto
 WHERE h.dtped>=(to_date(p_month||'-01','YYYY-MM-DD')-interval '1 month')::date
 AND h.dtped<to_date(p_month||'-01','YYYY-MM-DD')
 AND h.tipovenda IN('1','9')
 AND coalesce(nullif(ltrim(h.codcli,'0'),''),'0')=ANY(p_codes)
 AND NOT(coalesce(nullif(ltrim(h.codcli,'0'),''),'0')='9569' AND coalesce(nullif(ltrim(btrim(h.codusur),'0'),''),'0')='53')
 AND(h.codfor IN('707','708','752') OR (h.codfor='1119' AND upper(coalesce(p.descricao,'')) SIMILAR TO '%(TODDYNHO|TODDY|QUAKER|KEROCOCO)%'))
 AND EXISTS(SELECT 1 FROM public.data_clients c WHERE coalesce(nullif(ltrim(c.codigo_cliente,'0'),''),'0')=coalesce(nullif(ltrim(h.codcli,'0'),''),'0'))
 GROUP BY 1)
 SELECT coalesce(jsonb_object_agg(c.code,coalesce(t.revenue,0)),'{}'::jsonb) FROM codes c LEFT JOIN totals t ON t.code=c.code
$$;
REVOKE ALL ON FUNCTION private.planning_live_revenue_goals_v1(text,text[]) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.planning_financial_source_v1(p_month text,p_codes text[],p_token text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE payload jsonb;result jsonb;updated timestamptz;live_month boolean;defaults jsonb;
BEGIN
 IF p_token IS NULL OR length(p_token)<>64 OR
 (SELECT token_hash FROM private.planning_financial_bridge_config WHERE id=true) IS DISTINCT FROM encode(sha256(convert_to(p_token,'UTF8')),'hex')
 THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501';END IF;
 IF p_month IS NULL OR p_month!~'^[0-9]{4}-(0[1-9]|1[0-2])$' OR p_codes IS NULL OR cardinality(p_codes)>2500
 OR EXISTS(SELECT 1 FROM unnest(p_codes)c WHERE c IS NULL OR c!~'^[0-9]{1,20}$') THEN RAISE EXCEPTION 'Parâmetros inválidos' USING ERRCODE='22023';END IF;
 SELECT goals_data,updated_at INTO payload,updated FROM public.goals_distribution WHERE month_key=p_month AND supplier='ALL' AND brand='GENERAL';
 live_month:=p_month=to_char((now() AT TIME ZONE 'America/Bahia')::date,'YYYY-MM')
  AND p_month=(SELECT to_char(max(dtped) AT TIME ZONE 'UTC','YYYY-MM') FROM public.data_detailed);
 IF payload IS NULL AND live_month THEN defaults:=private.planning_live_revenue_goals_v1(p_month,p_codes);END IF;
 WITH codes AS(SELECT DISTINCT c code FROM unnest(p_codes)c), goals AS(
 SELECT coalesce(nullif(ltrim(key,'0'),''),'0') code,value FROM jsonb_each(coalesce(payload->'clients','{}'::jsonb))
 ), overdue AS(
 SELECT DISTINCT coalesce(nullif(ltrim(regexp_replace(btrim(cod_cliente::text),'[.]0+$',''),'0'),''),'0') code
 FROM public.data_titulos WHERE vl_receber>0 AND dt_vencimento::date<(now() AT TIME ZONE 'America/Bahia')::date
 ) SELECT coalesce(jsonb_object_agg(c.code,jsonb_build_object('revenueGoal',CASE WHEN payload IS NOT NULL THEN coalesce(private.planning_revenue_goal_v1(g.value),0) WHEN live_month THEN (defaults->>c.code)::numeric ELSE NULL END,'overdue',o.code IS NOT NULL)),'{}'::jsonb)
 INTO result FROM codes c LEFT JOIN goals g ON g.code=c.code LEFT JOIN overdue o ON o.code=c.code;
 RETURN jsonb_build_object('clients',result,'month',p_month,'goalsAvailable',payload IS NOT NULL OR coalesce(live_month,false),'goalsSource',CASE WHEN payload IS NOT NULL THEN 'saved' WHEN live_month THEN 'previous-month-default' ELSE 'unavailable' END,'goalsUpdatedAt',updated,'readAt',clock_timestamp());
END;$$;
REVOKE ALL ON FUNCTION public.planning_financial_source_v1(text,text[],text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.planning_financial_source_v1(text,text[],text) TO anon,authenticated;
-- Provision one random 256-bit token out of band: store only its SHA-256 here.
-- Store the matching token + public API key in Evolution Vault, never in browser code.

NOTIFY pgrst, 'reload schema';
