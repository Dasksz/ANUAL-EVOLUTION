BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE public.data_history_mix_audit_2098 PARTITION OF public.data_history FOR VALUES FROM ('2098-01-01') TO ('2099-01-01');
DO $verify$
DECLARE monthly_mix integer; yearly_mix integer; split_mix integer; first_amount numeric;
BEGIN
INSERT INTO public.dim_produtos(codigo,descricao,codfor,qtde_embalagem_master) VALUES ('MIX_AUDIT_PRODUCT','AUDIT MIX','999',1);
INSERT INTO public.data_clients(codigo_cliente) VALUES ('MIX_AUDIT_CLIENT');
INSERT INTO public.data_history(dtped,filial,cidade,codsupervisor,codusur,codfor,tipovenda,codcli,vlvenda,totpesoliq,produto,qtvenda,pedido)
VALUES ('2098-01-01','05','AUDIT','18','AUDIT','999','1','MIX_AUDIT_CLIENT',10,1,'MIX_AUDIT_PRODUCT',1,'MIX_ORDER_1'),
('2098-01-05','05','AUDIT','18','AUDIT','999','1','MIX_AUDIT_CLIENT',10,1,'MIX_AUDIT_PRODUCT',1,'MIX_ORDER_2');
PERFORM public.refresh_summary_chunk('2098-01-01','2098-01-03');
PERFORM public.refresh_summary_chunk('2098-01-05','2098-01-07');
SELECT SUM(pre_mix_count) INTO split_mix FROM public.data_summary WHERE ano=2098 AND codcli='MIX_AUDIT_CLIENT';
PERFORM public.refresh_summary_month(2098,1);
SELECT SUM(pre_mix_count),SUM(vlvenda) INTO monthly_mix,first_amount FROM public.data_summary WHERE ano=2098 AND codcli='MIX_AUDIT_CLIENT';
IF split_mix<>2 OR monthly_mix<>1 OR first_amount<>20 THEN RAISE EXCEPTION 'MIX regression split %, monthly %, revenue %',split_mix,monthly_mix,first_amount; END IF;
PERFORM public.refresh_summary_month(2098,1);
IF (SELECT SUM(pre_mix_count) FROM public.data_summary WHERE ano=2098 AND codcli='MIX_AUDIT_CLIENT')<>1 THEN RAISE EXCEPTION 'Retry duplicates'; END IF;
PERFORM public.refresh_summary_year(2098);
SELECT SUM(pre_mix_count) INTO yearly_mix FROM public.data_summary WHERE ano=2098 AND codcli='MIX_AUDIT_CLIENT';
IF yearly_mix<>monthly_mix THEN RAISE EXCEPTION 'Month/year mismatch'; END IF;
END;
$verify$;
ROLLBACK;
SELECT 'PASS: split blocks inflate mix; whole month matches annual refresh and is idempotent' AS result;