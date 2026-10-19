-- Keep the three-month historical allocation semantics while allowing the
-- existing (ano, mes) indexes on data_summary to serve filtered goal reads.
DO $patch$
DECLARE
  definition text;
  old_predicate text := 'WHERE d.ano*12+d.mes BETWEEN y*12+mo-3 AND y*12+mo-1 AND d.ano BETWEEN y-1 AND y';
  new_predicate text := 'WHERE ((d.ano = y AND d.mes BETWEEN greatest(mo-3, 1) AND mo-1) OR (mo <= 3 AND d.ano = y-1 AND d.mes BETWEEN mo+9 AND 12))';
BEGIN
  SELECT pg_get_functiondef('private.evolution_dashboard_targets_official(integer,integer,jsonb)'::regprocedure)
    INTO definition;

  IF position(new_predicate IN definition) > 0 THEN
    RETURN;
  END IF;

  IF position(old_predicate IN definition) = 0 THEN
    RAISE EXCEPTION 'Expected date predicate not found in evolution_dashboard_targets_official';
  END IF;

  definition := replace(definition, old_predicate, new_predicate);
  EXECUTE definition;
END
$patch$;
