import re

with open('sql/full_system_v1.sql', 'r') as f:
    sql = f.read()

# I see the error is around line 2801, which is inside `get_boxes_dashboard_data` (starts at 2685)
# In get_boxes_dashboard_data, the variables are `v_where_raw` and `v_where_summary`.
# `v_where_base` and `v_where_kpi` DO NOT EXIST in `get_boxes_dashboard_data`.

block_to_replace = """    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where_base := v_where_base || format(' AND d.codcli = %L ', p_codcli);
        v_where_kpi := v_where_kpi || format(' AND d.codcli = %L ', p_codcli);
    END IF;"""

new_block = """    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where_raw := v_where_raw || format(' AND codcli = %L ', p_codcli);
        v_where_summary := v_where_summary || format(' AND codcli = %L ', p_codcli);
    END IF;"""

sql = sql.replace(block_to_replace, new_block)

# Let's double check if my `inject_logic` injected `v_where_base` anywhere else it shouldn't have.
# get_branch_comparison_data starts at 3085. Let's see its variables.
