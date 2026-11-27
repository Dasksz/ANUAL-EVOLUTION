CREATE OR REPLACE FUNCTION public.elma_recovery_filtered_stats(p_payload jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  export_result jsonb;
  rows_data jsonb;
  filters jsonb;
  selection_kind text;
  selection_scope text;
  selection_team text;
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
  filters:=elma_recovery.management_filters();
  selection_kind:=coalesce(p_payload->>'kind','all');
  selection_scope:=coalesce(nullif(btrim(p_payload->>'scope'),''),'*');
  selection_team:=nullif(btrim(p_payload->>'team'),'');
  IF selection_kind='seller' THEN
    selection_scope:=CASE WHEN selection_scope='*' THEN '*' ELSE elma_recovery.seller_code(selection_scope) END;
  END IF;

  today_start:=(date_trunc('day',now() AT TIME ZONE 'America/Sao_Paulo')) AT TIME ZONE 'America/Sao_Paulo';
  tomorrow_start:=today_start+interval '1 day';

  WITH current_clients AS (
    SELECT DISTINCT ON (c.codigo_cliente) c.codigo_cliente,c.rca1
    FROM public.data_clients c
    ORDER BY c.codigo_cliente,c.created_at DESC,c.id DESC
  ), cached_assignments AS (
    SELECT DISTINCT x->>'codigo' AS client_code,x->>'promotor' AS promoter_code
    FROM elma_reports.promoter_sync s
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(s.payload->'clients','[]'::jsonb)) x
    WHERE s.id AND nullif(x->>'codigo','') IS NOT NULL AND nullif(x->>'promotor','') IS NOT NULL
  ), selected_clients AS (
    SELECT DISTINCT c.codigo_cliente
    FROM current_clients c
    LEFT JOIN LATERAL (
      SELECT item AS owner
      FROM jsonb_array_elements(coalesce(filters->'sellers','[]'::jsonb)) AS items(item)
      WHERE item->>'code'=elma_recovery.seller_code(c.rca1)
      LIMIT 1
    ) seller ON true
    WHERE NOT elma_recovery.is_employee_client(c.codigo_cliente)
      AND CASE selection_kind
        WHEN 'seller' THEN
          (selection_scope='*' OR elma_recovery.seller_code(c.rca1)=selection_scope)
          AND (selection_team IS NULL OR seller.owner->>'team'=selection_team)
        WHEN 'promoter' THEN EXISTS(
          SELECT 1
          FROM cached_assignments a
          CROSS JOIN LATERAL jsonb_array_elements(coalesce(filters->'promoters','[]'::jsonb)) AS items(item)
          WHERE a.client_code=c.codigo_cliente AND item->>'code'=a.promoter_code
            AND (selection_scope='*' OR a.promoter_code=selection_scope)
            AND (selection_team IS NULL OR item->>'team'=selection_team)
        )
        ELSE selection_team IS NULL
          OR seller.owner->>'team'=selection_team
          OR EXISTS(
            SELECT 1
            FROM cached_assignments a
            CROSS JOIN LATERAL jsonb_array_elements(coalesce(filters->'promoters','[]'::jsonb)) AS items(item)
            WHERE a.client_code=c.codigo_cliente AND item->>'code'=a.promoter_code
              AND item->>'team'=selection_team
          )
      END
  )
  SELECT jsonb_build_object(
    'today_count',(
      SELECT count(*)
      FROM elma_recovery.attempts AS attempt
      JOIN selected_clients AS client USING(codigo_cliente)
      WHERE attempt.created_at>=today_start AND attempt.created_at<tomorrow_start
        AND coalesce(attempt.is_test,false)=false
    ),
    'active_conversations',(
      SELECT count(*)
      FROM elma_recovery.attempts AS attempt
      JOIN selected_clients AS client USING(codigo_cliente)
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
