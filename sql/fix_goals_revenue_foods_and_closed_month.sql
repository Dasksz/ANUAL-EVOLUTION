-- Corrige os dados da aba Metas / Evolução.
-- 1) FAT realizado passa a incluir os fornecedores Foods armazenados como 1119_*.
-- 2) Meta FAT geral passa a somar as categorias de faturamento realmente importadas.
-- 3) Se a última venda pertence a um mês anterior ao mês-calendário atual, esse mês é considerado fechado.

DO $$
DECLARE
    v_oid oid;
    v_def text;
    v_old text;
    v_new text;
BEGIN
    SELECT p.oid
      INTO v_oid
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'get_metas_anuais_chart'
       AND pg_get_function_identity_arguments(p.oid) LIKE '%p_filial%'
     LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Função public.get_metas_anuais_chart não encontrada';
    END IF;

    v_def := pg_get_functiondef(v_oid);

    v_old := 'LTRIM(codfor::text, ''0'') IN (''707'', ''708'', ''752'', ''1119'')';
    v_new := '(LTRIM(codfor::text, ''0'') IN (''707'', ''708'', ''752'', ''1119'') OR LTRIM(codfor::text, ''0'') LIKE ''1119_%'')';
    v_def := replace(v_def, v_old, v_new);

    v_old := '(p_fornecedor = ''Todos'' AND m.categoria IN (''total_elma'', ''total_foods''))';
    v_new := '(p_fornecedor = ''Todos'' AND m.categoria IN (''707'', ''708'', ''752'', ''1119_TODDYNHO'', ''1119_TODDY'', ''1119_QUAKER_KEROCOCO''))';
    IF position(v_old in v_def) > 0 THEN
        v_def := replace(v_def, v_old, v_new);
    END IF;

    v_old := $old$
    IF p_ano < v_last_year THEN
        v_mes_fechado := 12;
    ELSIF p_ano > v_last_year THEN
        v_mes_fechado := 0;
    ELSE
        v_mes_fechado := v_last_month - 1;
    END IF;$old$;

    v_new := $new$
    IF p_ano < v_last_year THEN
        v_mes_fechado := 12;
    ELSIF p_ano > v_last_year THEN
        v_mes_fechado := 0;
    ELSE
        IF v_last_year < EXTRACT(YEAR FROM CURRENT_DATE)
           OR (v_last_year = EXTRACT(YEAR FROM CURRENT_DATE)
               AND v_last_month < EXTRACT(MONTH FROM CURRENT_DATE)) THEN
            v_mes_fechado := v_last_month;
        ELSE
            v_mes_fechado := GREATEST(v_last_month - 1, 0);
        END IF;
    END IF;$new$;

    IF position(v_old in v_def) > 0 THEN
        v_def := replace(v_def, v_old, v_new);
    END IF;

    EXECUTE v_def;
END
$$;
