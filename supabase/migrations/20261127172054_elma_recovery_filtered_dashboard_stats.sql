CREATE OR REPLACE FUNCTION public.elma_recovery_filtered_stats(p_payload jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  export_result jsonb;
  rows_data jsonb;
  today_start timestamptz;
  tomorrow_start timestamptz;
  result jsonb;
BEGIN
  IF auth.uid() IS NULL OR coalesce(public.elma_management_access()->'allowed','false'::jsonb)<>'true'::jsonb THEN
    RAISE EXCEPTION 'Acesso exclusivo do administrador master' USING ERRCODE='42501';
  END IF;
  IF coalesce(jsonb_typeof(p_payload),'null')<>'object' THEN
    RAISE EXCEPTION 'Os parâmetros devem ser um objeto' USING ERRCODE='22023';
  END IF;

  export_result:=public.elma_recovery_management('export',p_payload);
  IF coalesce((export_result->>'truncated')::boolean,false) THEN
    RAISE EXCEPTION 'A lista filtrada excede o limite de indicadores. Selecione uma equipe ou responsável.' USING ERRCODE='22023';
  END IF;
  rows_data:=coalesce(export_result->'rows','[]'::jsonb);
  today_start:=(date_trunc('day',now() AT TIME ZONE 'America/Sao_Paulo')) AT TIME ZONE 'America/Sao_Paulo';
  tomorrow_start:=today_start+interval '1 day';

  WITH filtered_clients AS (
    SELECT DISTINCT row_data->>'codigo_cliente' AS codigo_cliente
    FROM jsonb_array_elements(rows_data) AS item(row_data)
    WHERE nullif(row_data->>'codigo_cliente','') IS NOT NULL
  )
  SELECT jsonb_build_object(
    'today_count',(
      SELECT count(*)
      FROM elma_recovery.attempts AS attempt
      JOIN filtered_clients AS client USING(codigo_cliente)
      WHERE attempt.created_at>=today_start AND attempt.created_at<tomorrow_start
        AND coalesce(attempt.is_test,false)=false
    ),
    'active_conversations',(
      SELECT count(*)
      FROM elma_recovery.attempts AS attempt
      JOIN filtered_clients AS client USING(codigo_cliente)
      WHERE attempt.closed_at IS NULL
        AND attempt.status IN ('sending','awaiting_identity','active','awaiting_consent')
        AND coalesce(attempt.is_test,false)=false
    ),
    'pending_verifications',(
      SELECT count(*)
      FROM jsonb_array_elements(rows_data) AS item(row_data)
      WHERE row_data->>'situacao_verificacao'='pending'
    )
  ) INTO result;

  RETURN result;
END
$function$;

REVOKE ALL ON FUNCTION public.elma_recovery_filtered_stats(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.elma_recovery_filtered_stats(jsonb) TO authenticated;
