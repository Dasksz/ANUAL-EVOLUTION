-- Optimize Cache Filters Table
-- The cache table is used for dependent filtering. If it lacks indexes on specific columns,
-- queries for specific Supervisors or Vendors might be slow, especially when "Year" is not selected (fetching all years).

CREATE INDEX IF NOT EXISTS idx_cache_filters_superv ON public.cache_filters (superv);
CREATE INDEX IF NOT EXISTS idx_cache_filters_nome ON public.cache_filters (nome);
CREATE INDEX IF NOT EXISTS idx_cache_filters_cidade ON public.cache_filters (cidade);
CREATE INDEX IF NOT EXISTS idx_cache_filters_filial ON public.cache_filters (filial);
CREATE INDEX IF NOT EXISTS idx_cache_filters_fornecedor_col ON public.cache_filters (fornecedor);
CREATE INDEX IF NOT EXISTS idx_cache_filters_codfor ON public.cache_filters (codfor);
