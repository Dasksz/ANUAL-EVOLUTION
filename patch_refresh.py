import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# We need to add the population logic for dat_summary_frequency inside both refresh_summary_year and refresh_summary_month

freq_year_logic = """
    -- Refresh Frequency Summary for the year
    DELETE FROM public.dat_summary_frequency WHERE ano = p_year;

    INSERT INTO public.dat_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,
        SUM(vlvenda) as vlvenda,
        SUM(totpesoliq) as peso,
        jsonb_agg(DISTINCT produto) as produtos,
        jsonb_agg(DISTINCT categoria_produto) as categorias,
        MAX(ramo) as rede
    FROM augmented_data
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;
"""

freq_month_logic = """
    -- Refresh Frequency Summary for the month
    DELETE FROM public.dat_summary_frequency WHERE ano = p_year AND mes = p_month;

    INSERT INTO public.dat_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,
        SUM(vlvenda) as vlvenda,
        SUM(totpesoliq) as peso,
        jsonb_agg(DISTINCT produto) as produtos,
        jsonb_agg(DISTINCT categoria_produto) as categorias,
        MAX(ramo) as rede
    FROM augmented_data
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;
"""


# Add pedido to augmented_data in both places
content = content.replace("SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda", "SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido")
content = content.replace("s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda, dp.qtde_embalagem_master,", "s.pedido, s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda, dp.qtde_embalagem_master,")

content = content.replace("FROM client_agg;\n    \n    -- ANALYZE public.data_summary;\nEND;\n$$;", "FROM client_agg;\n    " + freq_year_logic + "\n    -- ANALYZE public.data_summary;\nEND;\n$$;")

content = content.replace("FROM client_agg;\n    \n    -- No internal ANALYZE to keep chunks fast\nEND;\n$$;", "FROM client_agg;\n    " + freq_month_logic + "\n    -- No internal ANALYZE to keep chunks fast\nEND;\n$$;")

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)

print("Patched.")
