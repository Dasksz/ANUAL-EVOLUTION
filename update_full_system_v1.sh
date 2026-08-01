#!/bin/bash
# Apply fixes for QueryTuner memory/Bolt agent
cp /app/sql/full_system_v1.sql /app/sql/full_system_v1_backup.sql

# In FAST PATH - Prod Raw: Remove JOIN and use subquery for categories
sed -i 's/LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo//g' /app/sql/full_system_v1.sql

# In SLOW PATH - Base Data: Remove JOIN with dim_produtos to shrink materialized CTE cardinality drastically
sed -i 's/LEFT JOIN public\.dim_produtos dp ON s\.produto = dp\.codigo//g' /app/sql/full_system_v1.sql

# In PROD_AGG - Add the JOIN back against grouped product rows (only a few hundred rather than millions)
# Already exists in FAST PATH! "LEFT JOIN public.dim_produtos dp ON p.produto = dp.codigo" in prod_agg CTE.
# Also exists in SLOW PATH! "LEFT JOIN public.dim_produtos dp ON p.produto = dp.codigo" in prod_agg CTE.

# Now we need to make sure the column `qtde_embalagem_master` isn't selected in base_data, since it's from dim_produtos
sed -i 's/s\.dtped, s\.vlvenda, s\.totpesoliq, s\.qtvenda, s\.produto, dp\.descricao, dp\.qtde_embalagem_master, s\.codcli, s\.tipovenda, s\.vlbonific, s\.codfor/s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, s.codcli, s.tipovenda, s.vlbonific, s.codfor/g' /app/sql/full_system_v1.sql

# For SLOW PATH: kpi_curr, kpi_prev, kpi_tri and chart_agg use caixas calculations directly from base_data which used `qtde_embalagem_master`.
# We need to change that to calculate caixas without dim_produtos if we remove the JOIN from base_data.
# But `data_summary` has `caixas`, while `data_detailed` requires `qtvenda / qtde_embalagem_master`.
# So to calculate `caixas` accurately on slow path, we MUST either join `dim_produtos` AFTER aggregation, or join it inside base_data.
