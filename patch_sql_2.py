import re

with open('sql/full_system_v1.sql', 'r') as f:
    sql = f.read()

# get_branch_comparison_data uses `v_where`.
sql = sql.replace("""    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where_base := v_where_base || format(' AND codcli = %L ', p_codcli);
    END IF;""", """    IF p_codcli IS NOT NULL AND p_codcli <> '' THEN
        v_where := v_where || format(' AND codcli = %L ', p_codcli);
    END IF;""")

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(sql)
