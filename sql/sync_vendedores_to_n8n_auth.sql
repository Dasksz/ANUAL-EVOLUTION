-- Keep the WhatsApp collaborator lookup synchronized with the seller dimension.
-- Applied to EVOLUÇÃO ANUAL as migration sync_vendedores_to_n8n_auth.
-- Existing code/CPF conflicts are intentionally left unchanged for manual review.

CREATE UNIQUE INDEX IF NOT EXISTS n8n_auth_colaboradores_codigo_numerico_key
  ON public.n8n_auth_colaboradores (btrim(codigo))
  WHERE btrim(codigo) ~ '^[0-9]+$';

CREATE UNIQUE INDEX IF NOT EXISTS n8n_auth_colaboradores_cpf_normalizado_key
  ON public.n8n_auth_colaboradores (
    (NULLIF(regexp_replace(COALESCE(cpf, ''), '[^0-9]', '', 'g'), ''))
  )
  WHERE cpf IS NOT NULL
    AND NULLIF(regexp_replace(COALESCE(cpf, ''), '[^0-9]', '', 'g'), '') IS NOT NULL;

CREATE OR REPLACE FUNCTION private.sync_n8n_auth_colaboradores_from_dim_vendedores()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  v_codigo text := NULLIF(btrim(NEW.codigo), '');
  v_nome text := NULLIF(btrim(NEW.nome), '');
  v_cpf text := NULLIF(regexp_replace(COALESCE(NEW.cpf, ''), '[^0-9]', '', 'g'), '');
  v_existing_id bigint;
  v_existing_cpf text;
BEGIN
  IF v_codigo IS NULL THEN
    RETURN NEW;
  END IF;

  -- dim_vendedores.cpf may contain an accidental formatting error.
  -- Only copy 11-digit CPF values; keep the collaborator row without CPF otherwise.
  IF v_cpf IS NOT NULL AND length(v_cpf) <> 11 THEN
    v_cpf := NULL;
  END IF;

  SELECT
    a.id,
    NULLIF(regexp_replace(COALESCE(a.cpf, ''), '[^0-9]', '', 'g'), '')
  INTO v_existing_id, v_existing_cpf
  FROM public.n8n_auth_colaboradores AS a
  WHERE
    (v_cpf IS NOT NULL
      AND NULLIF(regexp_replace(COALESCE(a.cpf, ''), '[^0-9]', '', 'g'), '') = v_cpf)
    OR btrim(COALESCE(a.codigo, '')) = v_codigo
  ORDER BY CASE
    WHEN v_cpf IS NOT NULL
      AND NULLIF(regexp_replace(COALESCE(a.cpf, ''), '[^0-9]', '', 'g'), '') = v_cpf
    THEN 0
    ELSE 1
  END
  LIMIT 1
  FOR UPDATE;

  IF v_existing_id IS NOT NULL THEN
    -- Never reassign an existing code to a different CPF. Leave the record for review.
    IF v_existing_cpf IS NOT NULL
       AND v_cpf IS NOT NULL
       AND v_existing_cpf <> v_cpf THEN
      RETURN NEW;
    END IF;

    UPDATE public.n8n_auth_colaboradores
    SET
      nome = COALESCE(v_nome, nome),
      cpf = CASE WHEN v_existing_cpf IS NULL THEN v_cpf ELSE cpf END
    WHERE id = v_existing_id;

    RETURN NEW;
  END IF;

  INSERT INTO public.n8n_auth_colaboradores (codigo, nome, cpf)
  VALUES (v_codigo, v_nome, v_cpf)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.sync_n8n_auth_colaboradores_from_dim_vendedores() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.sync_n8n_auth_colaboradores_from_dim_vendedores() TO authenticated, service_role;

DROP TRIGGER IF EXISTS sync_n8n_auth_colaboradores_from_dim_vendedores
  ON public.dim_vendedores;

CREATE TRIGGER sync_n8n_auth_colaboradores_from_dim_vendedores
AFTER INSERT OR UPDATE ON public.dim_vendedores
FOR EACH ROW
EXECUTE FUNCTION private.sync_n8n_auth_colaboradores_from_dim_vendedores();

-- Backfill existing seller rows through the same trigger logic.
UPDATE public.dim_vendedores
SET nome = nome;
