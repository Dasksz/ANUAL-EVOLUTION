-- PROMOTORES: read only client-to-coordinator associations through the existing private bridge.
CREATE OR REPLACE FUNCTION public.loja_perfeita_coordinators_source_v1(p_codes text[],p_token text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF p_token IS NULL OR length(p_token)<>64 OR
 (SELECT token_hash FROM private.planning_financial_bridge_config WHERE id=true)
 IS DISTINCT FROM encode(sha256(convert_to(p_token,'UTF8')),'hex')
 THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 IF p_codes IS NULL OR cardinality(p_codes)>2500 OR EXISTS(SELECT 1 FROM unnest(p_codes) c WHERE c IS NULL OR c!~'^[0-9]{1,20}$')
 THEN RAISE EXCEPTION 'Clientes inválidos' USING ERRCODE='22023'; END IF;
 WITH assignments AS (
   SELECT DISTINCT coalesce(nullif(ltrim(btrim(p.client_code),'0'),''),'0') code, upper(btrim(h.nome_coord)) coordinator
   FROM public.data_client_promoters p
   JOIN public.data_hierarchy h ON upper(btrim(p.promoter_code))=upper(btrim(h.cod_promotor))
   WHERE nullif(btrim(h.nome_coord),'') IS NOT NULL
 ), clients AS (
   SELECT code,jsonb_agg(coordinator ORDER BY coordinator) names
   FROM assignments WHERE code=ANY(p_codes) GROUP BY code
 )
 SELECT coalesce(jsonb_object_agg(code,names),'{}'::jsonb) INTO result FROM clients;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.loja_perfeita_coordinators_source_v1(text[],text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.loja_perfeita_coordinators_source_v1(text[],text) TO anon,authenticated;
NOTIFY pgrst, 'reload schema';
