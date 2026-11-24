DO $migration$
DECLARE
  definition text;
  start_pos integer;
  end_pos integer;
  old_default constant text := $old$v_fornecedor_foods_cond text := 's.codfor = ''1119''';$old$;
  new_default constant text := $new$v_fornecedor_foods_cond text := 's.codfor IN (''1119'', ''1119_TODDY'', ''1119_TODDYNHO'', ''1119_QUAKER'', ''1119_KEROCOCO'', ''1119_OUTROS'')';$new$;
  new_cases constant text := $cases$ELSIF v_code = '1119' THEN
                        v_foods_conds := array_append(v_foods_conds, v_fornecedor_foods_cond);
                    ELSIF v_code IN ('1119_TODDY', '1119_TODDYNHO', '1119_QUAKER', '1119_KEROCOCO') THEN
                        v_foods_conds := array_append(v_foods_conds, format(
                            '(s.codfor = %L OR (s.codfor = ''1119'' AND s.categorias ? %L))',
                            v_code, substring(v_code from 6)));
                    ELSIF v_code = '1119_QUAKER_KEROCOCO' THEN
                        v_foods_conds := array_append(v_foods_conds, '(s.codfor IN (''1119_QUAKER'', ''1119_KEROCOCO'') OR (s.codfor = ''1119'' AND s.categorias ?| ARRAY[''QUAKER'', ''KEROCOCO'']))');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_foods_conds := array_append(v_foods_conds, '(s.codfor = ''1119_OUTROS'' OR (s.codfor = ''1119'' AND NOT COALESCE(s.categorias ?| ARRAY[''TODDY'', ''TODDYNHO'', ''QUAKER'', ''KEROCOCO''], false)))');
                    $cases$;
BEGIN
  definition := pg_get_functiondef('public.get_estrelas_kpis_data(text[],text[],text[],text[],text[],text,text,text[],text[],text[])'::regprocedure);
  IF strpos(definition, new_default) > 0 THEN RETURN; END IF;
  start_pos := strpos(definition, 'ELSIF v_code = ''1119_TODDYNHO'' THEN');
  end_pos := strpos(definition, 'END IF;' || chr(13) || chr(10) || '                END LOOP;');
  IF end_pos = 0 THEN
    end_pos := strpos(definition, 'END IF;' || chr(10) || '                END LOOP;');
  END IF;
  IF strpos(definition, old_default) = 0 OR start_pos = 0 OR end_pos <= start_pos THEN
    RAISE EXCEPTION 'Unexpected Estrelas Foods definition';
  END IF;
  definition := overlay(definition placing new_cases from start_pos for end_pos-start_pos);
  EXECUTE replace(definition, old_default, new_default);
END
$migration$;
