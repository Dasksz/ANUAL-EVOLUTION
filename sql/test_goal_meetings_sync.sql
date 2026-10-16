-- Read-only/parser regressions; no change to the source sheet or stored meetings.
DO $test$
DECLARE fixture text:=$csv$Data da reunião,Mês,Participante,Cargo / função,Área / setor
28/09/2026,set.,"Ana, Maria",,"Comercial "
28/09/2026,set.,"Ana, Maria",,"Comercial "
28/09/2026,set.,"Ana, Maria",,Logística
08/06/2026,jun.,O'Connor,,
$csv$; parsed jsonb; invalid text; caught boolean; before_row jsonb; after_row jsonb;
BEGIN
 parsed:=private.goal_meetings_from_csv(fixture);
 IF jsonb_array_length(parsed)<>2 OR parsed->0->>'date'<>'2026-09-28'
 OR jsonb_array_length(parsed->0->'participants')<>2
 OR parsed->0->'participants'->0->>'area'<>'Comercial '
 OR parsed->1->'participants'->0->>'name'<>'O''Connor'
 OR parsed->1->'participants'->0->>'area'<>'Não informada' THEN RAISE EXCEPTION 'Grouping/preservation regression'; END IF;
 IF private.goal_meetings_csv_rows(E'"A""B","C\nD"\r\n')->0->>0<>'A"B'
 OR private.goal_meetings_csv_rows(E'"A""B","C\nD"\r\n')->0->>1<>E'C\nD' THEN RAISE EXCEPTION 'Quoted CSV regression'; END IF;
 SELECT to_jsonb(t) INTO before_row FROM public.goal_meetings_sync t WHERE id=true;
 FOREACH invalid IN ARRAY ARRAY[
 'wrong header',
 E'Data da reunião,Mês,Participante,Cargo / função,Área / setor\n31/02/2026,,Nome,,Área',
 E'Data da reunião,Mês,Participante,Cargo / função,Área / setor\n,,Nome,,Área',
 E'Data da reunião,Mês,Participante,Cargo / função,Área / setor\n28/09/2026,,"Nome',
 E'Data da reunião,Mês,Participante,Cargo / função,Área / setor\n28/09/2026,,"Nome"x,,Área'
 ] LOOP
  caught:=false;
  BEGIN
   UPDATE public.goal_meetings_sync SET meetings=private.goal_meetings_from_csv(invalid),synced_at=clock_timestamp() WHERE id=true;
  EXCEPTION WHEN OTHERS THEN caught:=true;
  END;
  IF NOT caught THEN RAISE EXCEPTION 'Invalid source was accepted'; END IF;
 END LOOP;
 SELECT to_jsonb(t) INTO after_row FROM public.goal_meetings_sync t WHERE id=true;
 IF before_row IS DISTINCT FROM after_row THEN RAISE EXCEPTION 'Invalid source changed data or synced_at'; END IF;
END;$test$;
