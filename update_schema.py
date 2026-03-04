import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

table_def = """

-- ==============================================================================
-- Frequency Summary Table (Optimized for Fast Counts per Order)
-- ==============================================================================
create table if not exists public.dat_summary_frequency (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    ano int,
    mes int,
    filial text,
    cidade text,
    codsupervisor text,
    codusur text,
    codfor text,
    codcli text,
    tipovenda text,
    pedido text,
    vlvenda numeric,
    peso numeric,
    produtos jsonb,
    categorias jsonb,
    rede text,
    created_at timestamp with time zone default now()
);

CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_ano_mes ON public.dat_summary_frequency(ano, mes);
CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_filial_cidade ON public.dat_summary_frequency(filial, cidade);
CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_vendedor_supervisor ON public.dat_summary_frequency(codusur, codsupervisor);
CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_pedido_cli ON public.dat_summary_frequency(pedido, codcli);
CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_produtos_gin ON public.dat_summary_frequency USING GIN (produtos);
CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_categorias_gin ON public.dat_summary_frequency USING GIN (categorias);

"""

target_marker = "-- Cache Table (For Filter Dropdowns)"
# Clean up any potential previous mistaken additions if they somehow stuck, and then add it cleanly before Cache Table
content = re.sub(r'-- Frequency Summary Table.*?CREATE INDEX IF NOT EXISTS idx_dat_summary_freq_categorias_gin ON public\.dat_summary_frequency USING GIN \(categorias\);\n', '', content, flags=re.DOTALL)


parts = content.split(target_marker)

if len(parts) > 1:
    content = parts[0] + table_def + "\n" + target_marker + parts[1]
    with open('sql/full_system_v1.sql', 'w') as f:
        f.write(content)
    print("Successfully added table definition.")
else:
    print("Marker not found.")
