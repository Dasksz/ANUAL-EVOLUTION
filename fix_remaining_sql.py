with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# Fix table definitions
content = content.replace('  qtvenda_embalagem_master numeric,\n', '')

# Fix sync_chunk_v2 and append_to_chunk_v2
content = content.replace('estoqueunit, qtvenda_embalagem_master, tipovenda, filial', 'estoqueunit, tipovenda, filial')

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)
