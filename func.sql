  1500	SET search_path = public
  1501	AS $$
  1502	BEGIN
  1503	    DELETE FROM public.data_summary WHERE ano = p_year AND mes = p_month;
  1504	    DELETE FROM public.data_summary_frequency WHERE ano = p_year AND mes = p_month;
  1505	END;
  1506	$$;
  1507
  1508	-- FUNÇÃO ATUALIZADA PARA PROCESSAR UM CHUNK DE DATAS
  1509	CREATE OR REPLACE FUNCTION refresh_summary_chunk(p_start_date date, p_end_date date)
  1510	RETURNS void
  1511	LANGUAGE plpgsql
  1512	SECURITY DEFINER
  1513	SET search_path = public
  1514	AS $$
  1515	DECLARE
  1516	    v_year int;
  1517	    v_month int;
  1518	BEGIN
  1519	    SET LOCAL statement_timeout = '1800s'; -- Increased to 30 mins to avoid immediate API cutoff
  1520	    SET LOCAL work_mem = '128MB'; -- More memory for internal hashing during grouped inserts
  1521
  1522	    v_year := EXTRACT(YEAR FROM p_start_date);
  1523	    v_month := EXTRACT(MONTH FROM p_start_date);
  1524
  1525	    -- STEP A: Create a temporary table for the raw data of the month to avoid massive UNION ALL memory plans
  1526	    CREATE TEMP TABLE tmp_raw_data ON COMMIT DROP AS
  1527	    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
  1528	    FROM public.data_detailed
  1529	    WHERE dtped >= p_start_date AND dtped < p_end_date
  1530	    UNION ALL
  1531	    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
  1532	    FROM public.data_history
  1533	    WHERE dtped >= p_start_date AND dtped < p_end_date;
  1534
  1535	    CREATE INDEX idx_tmp_raw_produto ON tmp_raw_data(produto);
  1536	    CREATE INDEX idx_tmp_raw_codcli ON tmp_raw_data(codcli);
  1537	    CREATE INDEX idx_tmp_raw_pedido ON tmp_raw_data(pedido);
  1538
  1539	    -- STEP B: Insert into data_summary using the temporary table
  1540	    INSERT INTO public.data_summary (
  1541	        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
  1542	        vlvenda, peso, bonificacao, devolucao,
  1543	        pre_mix_count, pre_positivacao_val,
  1544	        ramo, caixas, categoria_produto
  1545	    )
  1546	    WITH dim_prod_enhanced AS (
  1547	        SELECT
  1548	            codigo,
  1549	            categoria_produto,
  1550	            qtde_embalagem_master,
  1551	            CASE
  1552	                WHEN '1119' = '1119' AND descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
  1553	                WHEN '1119' = '1119' AND descricao ILIKE '%TODDY %' THEN '1119_TODDY'
  1554	                WHEN '1119' = '1119' AND descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
  1555	                WHEN '1119' = '1119' AND descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
  1556	                ELSE '1119_OUTROS'
  1557	            END as codfor_enhanced
  1558	        FROM public.dim_produtos
  1559	    ),
  1560	    augmented_data AS (
  1561	        SELECT
  1562	            v_year as ano,
  1563	            v_month as mes,
  1564	            CASE
  1565	                WHEN s.codcli = '11625' AND v_year = 2025 AND v_month = 12 THEN '05'
  1566	                ELSE s.filial
  1567	            END as filial,
  1568	            COALESCE(s.cidade, c.cidade) as cidade,
  1569	            s.codsupervisor,
  1570	            s.codusur,
  1571	            CASE
  1572	                WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
  1573	                ELSE s.codfor
  1574	            END as codfor,
  1575	            s.tipovenda,
  1576	            s.codcli,
  1577	            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda, dp.qtde_embalagem_master,
  1578	            c.ramo,
  1579	            dp.categoria_produto
  1580	        FROM tmp_raw_data s
  1581	        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
  1582	        LEFT JOIN dim_prod_enhanced dp ON s.produto = dp.codigo
  1583	    ),
  1584	    product_agg AS (
  1585	        SELECT
  1586	            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
  1587	            SUM(vlvenda) as prod_val,
  1588	            SUM(totpesoliq) as prod_peso,
  1589	            SUM(vlbonific) as prod_bonific,
  1590	            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
  1591	            SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as prod_caixas
  1592	        FROM augmented_data
  1593	        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
  1594	    ),
  1595	    client_agg AS (
  1596	        SELECT
  1597	            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
  1598	            SUM(pa.prod_val) as total_val,
  1599	            SUM(pa.prod_peso) as total_peso,
  1600	            SUM(pa.prod_bonific) as total_bonific,
  1601	            SUM(pa.prod_devol) as total_devol,
  1602	            SUM(pa.prod_caixas) as total_caixas,
  1603	            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
  1604	        FROM product_agg pa
  1605	        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
  1606	    )
  1607	    SELECT
  1608	        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
  1609	        total_val, total_peso, total_bonific, total_devol,
  1610	        mix_calc,
  1611	        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
  1612	        ramo,
  1613	        total_caixas,
  1614	        categoria_produto
  1615	    FROM client_agg;
  1616
  1617
  1618	    -- STEP C: Insert into data_summary_frequency using the temporary table
  1619	    INSERT INTO public.data_summary_frequency (
  1620	        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede
  1621	    )
  1622	    WITH dim_prod_enhanced AS (
  1623	        SELECT
  1624	            codigo,
  1625	            categoria_produto,
  1626	            CASE
  1627	                WHEN descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
  1628	                WHEN descricao ILIKE '%TODDY %' THEN '1119_TODDY'
  1629	                WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
  1630	                WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
  1631	                ELSE '1119_OUTROS'
  1632	            END as codfor_enhanced
  1633	        FROM public.dim_produtos
  1634	    ),
  1635	    freq_agg_base AS (
  1636	        SELECT
  1637	            v_year as ano,
  1638	            v_month as mes,
  1639	            t.filial,
  1640	            t.cidade,
  1641	            t.codsupervisor,
  1642	            t.codusur,
  1643	            CASE
  1644	                WHEN t.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
  1645	                ELSE t.codfor
  1646	            END as codfor,
  1647	            t.codcli,
  1648	            t.tipovenda,
  1649	            t.pedido,
  1650	            SUM(t.vlvenda) as vlvenda,
  1651	            SUM(t.totpesoliq) as peso,
  1652	            jsonb_agg(DISTINCT t.produto) as produtos,
  1653	            jsonb_agg(DISTINCT dp.categoria_produto) FILTER (WHERE dp.categoria_produto IS NOT NULL) as categorias
  1654	        FROM tmp_raw_data t
  1655	        LEFT JOIN dim_prod_enhanced dp ON t.produto = dp.codigo
  1656	        GROUP BY
  1657	            t.filial,
  1658	            t.cidade,
  1659	            t.codsupervisor,
  1660	            t.codusur,
  1661	            CASE
  1662	                WHEN t.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
  1663	                ELSE t.codfor
  1664	            END,
  1665	            t.codcli,
  1666	            t.tipovenda,
  1667	            t.pedido
  1668	    )
  1669	    SELECT
  1670	        f.ano,
  1671	        f.mes,
  1672	        f.filial,
  1673	        f.cidade,
  1674	        f.codsupervisor,
  1675	        f.codusur,
  1676	        f.codfor,
  1677	        f.codcli,
  1678	        f.tipovenda,
  1679	        f.pedido,
  1680	        f.vlvenda,
  1681	        f.peso,
  1682	        f.produtos,
  1683	        COALESCE(f.categorias, '[]'::jsonb) as categorias,
  1684	        c.ramo as rede
  1685	    FROM freq_agg_base f
  1686	    LEFT JOIN public.data_clients c ON f.codcli = c.codigo_cliente;
  1687
  1688	    -- STEP D: Cleanup
  1689	    DROP TABLE IF EXISTS tmp_raw_data;
  1690	END;
