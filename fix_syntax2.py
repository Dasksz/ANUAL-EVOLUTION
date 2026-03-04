import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# I also noticed we need to include `produto` in augmented_data so jsonb_agg(DISTINCT produto) works
content = content.replace("s.pedido, s.vlvenda, s.totpesoliq, dp.categoria_produto,", "s.pedido, s.vlvenda, s.totpesoliq, s.produto, dp.categoria_produto,")

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)

print("Fixed syntax in refresh_summary_year and refresh_summary_month")
