-- Run on EVOLUTION after provisioning the dedicated read-only bridge token in Vault.
CREATE OR REPLACE FUNCTION private.planning_financial_fetch_v1(p_month text,p_codes text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE config jsonb;response extensions.http_response;result jsonb;old_timeout text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501';END IF;
 IF cardinality(p_codes)>2500 THEN RAISE EXCEPTION 'Carteira inválida';END IF;
 SELECT decrypted_secret::jsonb INTO config FROM vault.decrypted_secrets WHERE name='planning_financial_bridge';
 IF config IS NULL THEN RAISE EXCEPTION 'Consulta financeira não configurada';END IF;
 SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','10000');
 SELECT * INTO response FROM extensions.http(ROW('POST','https://dldsocponbjthqxhmttj.supabase.co/rest/v1/rpc/planning_financial_source_v1',
 ARRAY[extensions.http_header('apikey',config->>'anon'),extensions.http_header('Authorization','Bearer '||(config->>'anon'))],
 'application/json',jsonb_build_object('p_month',p_month,'p_codes',p_codes,'p_token',config->>'token')::text)::extensions.http_request);
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
 IF response.status<>200 THEN RAISE EXCEPTION 'Não foi possível consultar metas e inadimplência (HTTP %). Tente novamente.',response.status;END IF;
 result:=response.content::jsonb;
 IF result->>'month' IS DISTINCT FROM p_month OR jsonb_typeof(result->'clients') IS DISTINCT FROM 'object'
 OR EXISTS(SELECT 1 FROM unnest(p_codes)c WHERE NOT(result->'clients' ? c) OR jsonb_typeof(result->'clients'->c->'overdue') IS DISTINCT FROM 'boolean') THEN RAISE EXCEPTION 'Retorno financeiro incompleto';END IF;
 RETURN result;
EXCEPTION WHEN OTHERS THEN
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));RAISE;
END;$$;
REVOKE ALL ON FUNCTION private.planning_financial_fetch_v1(text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.planning_financial_fetch_v1(text,text[]) TO authenticated;
