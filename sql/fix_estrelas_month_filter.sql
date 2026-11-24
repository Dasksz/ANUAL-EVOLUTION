-- The Estrelas page sends 01 through 12; use the selected month for both sales and goals.
DO $migration$
DECLARE
  definition text;
  old_line constant text := 'v_target_month := p_mes::int + 1;';
  new_line constant text := 'v_target_month := p_mes::int;';
BEGIN
  definition := pg_get_functiondef('public.get_estrelas_kpis_data(text[],text[],text[],text[],text[],text,text,text[],text[],text[])'::regprocedure);
  IF strpos(definition, new_line) > 0 AND strpos(definition, old_line) = 0 THEN
    RETURN;
  END IF;
  IF length(definition) - length(replace(definition, old_line, '')) <> length(old_line) THEN
    RAISE EXCEPTION 'Unexpected Estrelas month filter definition';
  END IF;
  EXECUTE replace(definition, old_line, new_line);
END
$migration$;
