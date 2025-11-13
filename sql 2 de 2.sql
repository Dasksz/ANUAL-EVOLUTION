-- =================================================================
-- SCRIPT V13.1-B (APENAS O ÍNDICE)
-- OBJETIVO: Criar o índice de performance.
-- =================================================================

create index concurrently IF NOT exists 
  profiles_id_idx on public.profiles (id);
