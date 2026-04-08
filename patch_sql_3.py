import re

with open('sql/full_system_v1.sql', 'r') as f:
    sql = f.read()

# Fix get_boxes_dashboard_data error: at line 2800
bad_block = """    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where_base := v_where_base || format(' AND d.codcli = %L ', p_codcli);
        v_where_kpi := v_where_kpi || format(' AND d.codcli = %L ', p_codcli);
    END IF;"""

new_block = """    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where_raw := v_where_raw || format(' AND codcli = %L ', p_codcli);
        v_where_summary := v_where_summary || format(' AND codcli = %L ', p_codcli);
    END IF;"""

sql = sql.replace(bad_block, new_block)

# Fix get_mix_salty_foods_data (there are two, one around 4429)
# wait, line 4429 I patched to `v_where := v_where || format(' AND codcli = %L ', p_codcli);` but get_mix_salty_foods_data uses v_where_chart and v_where_rede? Let's check.
