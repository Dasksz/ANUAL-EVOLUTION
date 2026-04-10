import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

# Oh, I see! `data_summary` table already calculates `pos_calc` (mapped to `pre_positivacao_val`) per `codcli`, `codfor`, `tipovenda`, `categoria_produto`.
# In `get_boxes_dashboard_data`:
# ```sql
# SUM(CASE WHEN %s THEN pre_positivacao_val ELSE 0 END) as clientes
# ```
# Where `%s` is `v_tipovenda_client_cond`.
# So it simply does a SUM(pre_positivacao_val) across all rows in `data_summary` matching the filters.
# BUT! `data_summary` has rows grouped by `(ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto)`.
# Since a single `codcli` might have bought MULTIPLE `codfor` or MULTIPLE `categoria_produto` in the same month, there are MULTIPLE rows for the same `codcli` in `data_summary`!
# Doing `SUM(pre_positivacao_val)` will count the same client multiple times if they bought from multiple suppliers or categories!
# That's why the KPI "clientes atendidos" in the coverage analysis page shows an inflated number! It should do a `COUNT(DISTINCT codcli)`!

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)
boxes_code = sql[boxes_idx:end_idx]

print(boxes_code[boxes_code.find("kpi_curr AS ("):boxes_code.find("kpi_tri AS (")])
