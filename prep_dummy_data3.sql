INSERT INTO public.dim_produtos (codigo, descricao) VALUES ('0001', 'Produto Teste');
INSERT INTO public.data_summary (ano, mes, codcli, filial, codfor, tipovenda, vlvenda, peso, caixas)
VALUES (2024, 1, 'CLI1', '1', '707', '1', 100, 10, 5);
INSERT INTO public.data_detailed (dtped, vlvenda, totpesoliq, qtvenda, produto, codcli, filial, tipovenda, codfor)
VALUES ('2024-01-01', 100, 10, 50, '0001', 'CLI1', '1', '1', '707');
