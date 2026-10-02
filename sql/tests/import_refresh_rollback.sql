-- Regression check: always execute the entire file, including ROLLBACK.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE public.data_history_audit_2098 PARTITION OF public.data_history FOR VALUES FROM ('2098-01-01') TO ('2099-01-01');
DO $verify$
DECLARE
    v_count integer;
    v_amount numeric;
    v_flags integer;
    v_fn text;
BEGIN
    INSERT INTO public.dim_vendedores(codigo,nome) VALUES ('AUDIT_RCA_VALID','AUDIT VENDEDOR VALIDO');
    INSERT INTO public.data_clients(codigo_cliente,rca1) VALUES ('AUDIT_CLIENT_VALID','AUDIT_RCA_VALID');
    INSERT INTO public.dim_produtos(codigo,descricao,codfor,qtde_embalagem_master) VALUES
        ('AUDIT_TODYNHO','TODYNHO TESTE','1119',1),
        ('AUDIT_TODDY','TODDY','1119',1),
        ('AUDIT_QUAKER','QUAKER TESTE','1119',1),
        ('AUDIT_KEROCOCO','KEROCOCO TESTE','1119',1);
    SELECT count(*) INTO v_count FROM public.dim_produtos
     WHERE codigo IN ('AUDIT_TODYNHO','AUDIT_TODDY','AUDIT_QUAKER','AUDIT_KEROCOCO')
       AND mix_categoria='FOODS' AND mix_marca IN ('TODDYNHO','TODDY','QUAKER','KEROCOCO');
    IF v_count <> 4 THEN RAISE EXCEPTION 'Product classification regression: %',v_count; END IF;

    INSERT INTO public.data_history(dtped,filial,cidade,codsupervisor,codusur,codfor,tipovenda,codcli,vlvenda,totpesoliq,produto,qtvenda,pedido)
    SELECT '2098-01-01'::date,'05','AUDIT CIDADE','18','INAT_AUDIT','1119','1','AUDIT_CLIENT_VALID',100,1,codigo,1,'AUDIT_ORDER'
      FROM public.dim_produtos WHERE codigo IN ('AUDIT_TODYNHO','AUDIT_TODDY','AUDIT_QUAKER','AUDIT_KEROCOCO');

    FOREACH v_fn IN ARRAY ARRAY['chunk','month','year'] LOOP
        IF v_fn='chunk' THEN
            PERFORM public.clear_summary_month(2098,1);
            PERFORM public.refresh_summary_chunk('2098-01-01','2098-01-03');
        ELSIF v_fn='month' THEN
            PERFORM public.refresh_summary_month(2098,1);
        ELSE
            PERFORM public.refresh_summary_year(2098);
        END IF;
        SELECT SUM(vlvenda), count(*) FILTER (WHERE codusur LIKE 'INAT_%')
          INTO v_amount,v_count FROM public.data_summary WHERE ano=2098 AND codcli='AUDIT_CLIENT_VALID';
        IF v_amount<>400 OR v_count<>0 THEN RAISE EXCEPTION 'Summary regression %: amount %, INAT %',v_fn,v_amount,v_count; END IF;
        SELECT SUM(vlvenda),count(*) FILTER (WHERE codusur LIKE 'INAT_%'),
               MAX(has_toddynho)+MAX(has_toddy)+MAX(has_quaker)+MAX(has_kerococo)
          INTO v_amount,v_count,v_flags FROM public.data_summary_frequency
         WHERE ano=2098 AND codcli='AUDIT_CLIENT_VALID';
        IF v_amount<>400 OR v_count<>0 OR v_flags<>4 THEN RAISE EXCEPTION 'Frequency regression %: amount %, INAT %, flags %',v_fn,v_amount,v_count,v_flags; END IF;
        SELECT count(DISTINCT codfor) INTO v_count FROM public.data_summary_frequency
         WHERE ano=2098 AND codcli='AUDIT_CLIENT_VALID'
           AND codfor IN ('1119_TODDYNHO','1119_TODDY','1119_QUAKER','1119_KEROCOCO');
        IF v_count<>4 THEN RAISE EXCEPTION 'Foods supplier regression %: %',v_fn,v_count; END IF;
    END LOOP;
    PERFORM public.refresh_cache_filters(2098,1);
    SELECT count(*) INTO v_count FROM public.cache_filters WHERE ano=2098 AND superv='RÔMULO AMADO DA' AND nome='AUDIT VENDEDOR VALIDO';
    IF v_count<>4 THEN RAISE EXCEPTION 'Legacy supervisor cache regression: %',v_count; END IF;
END;
$verify$;

ROLLBACK;
SELECT 'PASS: trigger, chunk/month/year refresh, valid RCA, Foods and legacy supervisor cache' AS result;
