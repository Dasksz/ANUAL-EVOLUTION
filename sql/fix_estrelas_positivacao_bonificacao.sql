-- Faz bonificações (tipovenda 5 e 11) contarem para positivação no painel de Estrelas.
-- O faturamento/sell-out continua usando os valores/pesos originais; somente o sinal de
-- positivação passa a reconhecer a existência da operação bonificada mesmo com vlvenda = 0.

DO $do$
DECLARE
    v_name text;
    v_oid oid;
    v_def text;
    v_old_salty text := 'SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as salty_venda,';
    v_old_foods text := 'SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as foods_venda,';
    v_old_total text := 'SUM(s.vlvenda) as total_venda';
    v_new_salty text := 'SUM(CASE WHEN %s THEN CASE WHEN s.tipovenda IN (''''5'''',''''11'''') THEN 1 ELSE COALESCE(s.vlvenda,0) END ELSE 0 END) as salty_venda,';
    v_new_foods text := 'SUM(CASE WHEN %s THEN CASE WHEN s.tipovenda IN (''''5'''',''''11'''') THEN 1 ELSE COALESCE(s.vlvenda,0) END ELSE 0 END) as foods_venda,';
    v_new_total text := 'SUM(CASE WHEN s.tipovenda IN (''''5'''',''''11'''') THEN 1 ELSE COALESCE(s.vlvenda,0) END) as total_venda';
BEGIN
    FOREACH v_name IN ARRAY ARRAY['get_estrelas_kpis_data','get_estrelas_malha_kpis_data']
    LOOP
        SELECT p.oid
          INTO v_oid
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname='public'
           AND p.proname=v_name
         LIMIT 1;

        IF v_oid IS NULL THEN
            RAISE EXCEPTION 'Função % não encontrada', v_name;
        END IF;

        v_def := pg_get_functiondef(v_oid);

        IF position(v_old_salty in v_def) = 0
           OR position(v_old_foods in v_def) = 0
           OR position(v_old_total in v_def) = 0 THEN
            RAISE EXCEPTION 'Trecho de positivação esperado não encontrado em %', v_name;
        END IF;

        v_def := replace(v_def, v_old_salty, v_new_salty);
        v_def := replace(v_def, v_old_foods, v_new_foods);
        v_def := replace(v_def, v_old_total, v_new_total);

        EXECUTE v_def;
    END LOOP;
END
$do$;
