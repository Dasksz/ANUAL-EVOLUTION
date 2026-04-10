import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

# Let's double check what I wrote:
# v_active_client_cond := format('tipovenda = ANY(%L) AND tipovenda NOT IN (''5'', ''11'') AND pre_positivacao_val >= 1', p_tipovenda);
# Wait! pre_positivacao_val is an INTEGER in data_summary (0 or 1).
# So `pre_positivacao_val >= 1` is valid syntax.
# AND the fast path does:
# `COUNT(DISTINCT CASE WHEN %s THEN codcli END)`
# And `%s` receives `v_active_client_cond`.
# So it becomes `COUNT(DISTINCT CASE WHEN tipovenda = ANY(...) AND tipovenda NOT IN ('5', '11') AND pre_positivacao_val >= 1 THEN codcli END)`.
# This perfectly deduplicates!
# And it restricts to rows where they were active.

# BUT wait! Does this handle the case where they bought MULTIPLE things, and only ONE thing was >= 1?
# Yes, because ANY row having `pre_positivacao_val >= 1` will pass the CASE WHEN condition, and thus the client's `codcli` is returned and COUNT(DISTINCT) will count it EXACTLY ONCE!
# This is mathematically perfect.

# Is there anything missing? The user says:
# "ainda está vindo com essa contagem sendo que na pagina visão geral... temos aproximadamente 2000 positivados"
# They say this AFTER I submitted my FIRST PR. My first PR only fixed `get_mix_salty_foods_data`. It DID NOT fix `get_boxes_dashboard_data` which I only modified IN THIS WORKSPACE but never committed or submitted.
