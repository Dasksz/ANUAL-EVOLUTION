BEGIN;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
DO $test$
DECLARE v_boxes numeric; v_before numeric; v_after numeric; v_failed boolean := false;
BEGIN
    SELECT SUM(caixas) INTO v_before FROM public.data_summary
    WHERE ano=2026 AND mes=9 AND filial='08' AND codsupervisor='12' AND codfor='1119_QUAKER';
    INSERT INTO public.dim_produtos(codigo,descricao,codfor,qtde_embalagem_master)
    VALUES ('__packaging_regression_a__','TESTE EMBALAGEM A','707',2),
           ('__packaging_regression_b__','TESTE EMBALAGEM B','707',4);
    INSERT INTO public.data_detailed(dtped,filial,codsupervisor,codusur,codfor,tipovenda,codcli,produto,qtvenda,vlvenda,totpesoliq,vlbonific,vldevolucao,pedido)
    VALUES ('2026-09-10','08','12','__packaging_test__','707','1','__packaging_test__','__packaging_regression_a__',10,100,1,0,0,'__packaging_test_a__'),
           ('2026-09-10','08','12','__packaging_test__','707','1','__packaging_test__','__packaging_regression_b__',20,200,2,0,0,'__packaging_test_b__');
    PERFORM public.refresh_summary_month(2026,9);
    UPDATE public.dim_produtos SET qtde_embalagem_master =
        CASE codigo WHEN '__packaging_regression_a__' THEN 5 ELSE 10 END
    WHERE codigo IN ('__packaging_regression_a__','__packaging_regression_b__');
    SELECT SUM(caixas) INTO v_boxes FROM public.data_summary
    WHERE ano=2026 AND mes=9 AND codcli='__packaging_test__';
    ASSERT ABS(v_boxes-4) < 0.00001, 'Packaging update must rebuild summary automatically for both products';
    SELECT SUM(caixas) INTO v_after FROM public.data_summary
    WHERE ano=2026 AND mes=9 AND filial='08' AND codsupervisor='12' AND codfor='1119_QUAKER';
    ASSERT ABS(v_after-v_before) < 0.00001, 'Existing corrected Quaker result must be preserved';
    BEGIN
        UPDATE public.dim_produtos SET qtde_embalagem_master=0 WHERE codigo='__packaging_regression_a__';
    EXCEPTION WHEN check_violation THEN v_failed := true;
    END;
    ASSERT v_failed, 'Invalid packaging must be rejected atomically';
    INSERT INTO public.data_detailed(dtped,produto,qtvenda)
    VALUES ('2026-09-10','__packaging_missing__',10);
    v_failed := false;
    BEGIN
        PERFORM public.refresh_summary_month(2026,9);
    EXCEPTION WHEN SQLSTATE '22023' THEN v_failed := true;
    END;
    ASSERT v_failed, 'Unknown packaging must not become boxes with a divisor of one';
    v_failed := false;
    BEGIN
        PERFORM public.get_boxes_dashboard_data(p_ano=>'2026',p_mes=>'8',p_produto=>ARRAY['__packaging_missing__']);
    EXCEPTION WHEN SQLSTATE '22023' THEN v_failed := true;
    END;
    ASSERT v_failed, 'Coverage must reject unknown packaging even after an interrupted import';
    ASSERT private.evolution_product_boxes(10,1,'real_single_unit')=10,
        'A genuinely registered single-unit package remains valid';
    SELECT SUM(caixas) INTO v_boxes FROM public.data_summary
    WHERE ano=2026 AND mes=9 AND codcli='__packaging_test__';
    ASSERT ABS(v_boxes-4) < 0.00001, 'Failed rebuild must preserve the previous summary';
END;
$test$;
ROLLBACK;

