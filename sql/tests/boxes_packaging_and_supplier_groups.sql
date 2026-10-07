-- Run after fix_boxes_current_packaging_and_supplier_groups.sql.
-- Read-only regression checks; service claims are transaction-local.
BEGIN;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);
DO $test$
DECLARE r jsonb; c jsonb; expected numeric; actual numeric; fat numeric;
BEGIN
    r := public.get_boxes_dashboard_data(
        p_filial => ARRAY['08'], p_supervisor => ARRAY['TIAGO JOSÉ DE S'],
        p_fornecedor => ARRAY['1119_QUAKER'], p_ano => '2026', p_mes => '8')::jsonb;
    SELECT SUM(s.qtvenda / COALESCE(NULLIF(dp.qtde_embalagem_master,0),1)),
           SUM(CASE WHEN s.tipovenda IN ('5','11') THEN s.vlbonific ELSE s.vlvenda END)
    INTO expected, fat
    FROM (
        SELECT * FROM public.data_detailed WHERE dtped >= '2026-09-01' AND dtped < '2026-10-01'
        UNION ALL
        SELECT * FROM public.data_history WHERE dtped >= '2026-09-01' AND dtped < '2026-10-01'
    ) s
    JOIN public.dim_produtos dp ON dp.codigo=s.produto
    WHERE s.filial='08' AND s.codsupervisor='12' AND s.codfor='1119' AND dp.categoria_produto='QUAKER';
    ASSERT ABS(COALESCE((r->'kpi_current'->>'caixas')::numeric,0)-COALESCE(expected,0)) < 0.00001,
        'Month KPI must use current packaging and September only';
    ASSERT ABS(COALESCE((r->'kpi_current'->>'fat')::numeric,0)-COALESCE(fat,0)) < 0.01,
        'Revenue must agree with September raw sales';
    SELECT SUM((p->>'caixas')::numeric) INTO actual FROM jsonb_array_elements(r->'products_table') p;
    ASSERT ABS(COALESCE(actual,0)-COALESCE(expected,0)) < 0.00001,
        'Grouped supplier products must reconcile with KPI';
    c := public.get_boxes_dashboard_data(
        p_filial => ARRAY['08'], p_supervisor => ARRAY['TIAGO JOSÉ DE S'],
        p_categoria => ARRAY['QUAKER'], p_ano => '2026', p_mes => '8')::jsonb;
    ASSERT c->'kpi_current' = r->'kpi_current', 'Category and supplier filters must agree';
    ASSERT c->'products_table' = r->'products_table', 'Both filters must show the same products';
END;
$test$;
ROLLBACK;
