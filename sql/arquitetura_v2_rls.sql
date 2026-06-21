-- Habilitando RLS para as novas tabelas
ALTER TABLE public.config_comercial ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mix_ideal ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso total para usuários autenticados
-- (Isso resolve a tag "UNRESTRICTED" no Supabase e permite que o App/Front-end funcione normalmente)

CREATE POLICY "Acesso total para autenticados" ON public.config_comercial FOR ALL TO authenticated USING (true);
CREATE POLICY "Acesso total para anon" ON public.config_comercial FOR ALL TO anon USING (true);

CREATE POLICY "Acesso total para autenticados" ON public.import_logs FOR ALL TO authenticated USING (true);
CREATE POLICY "Acesso total para anon" ON public.import_logs FOR ALL TO anon USING (true);


CREATE POLICY "Acesso total para autenticados" ON public.mix_ideal FOR ALL TO authenticated USING (true);
CREATE POLICY "Acesso total para anon" ON public.mix_ideal FOR ALL TO anon USING (true);

-- Nota: Views materializadas (como mv_frequencia_cliente) não suportam RLS no PostgreSQL.
-- A marcação "UNRESTRICTED" no Supabase é padrão para views sem RLS (o que é normal).
