-- Performance Optimization: Filter-Specific Indexes
-- The default date-based index is inefficient when filtering by a specific Supervisor or Vendor
-- because it must scan the entire date range and then filter.
-- These indexes allow the DB to jump directly to the relevant subset of data.

-- Detailed Data
CREATE INDEX IF NOT EXISTS idx_detailed_superv_dtped_inc
ON public.data_detailed (superv, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

CREATE INDEX IF NOT EXISTS idx_detailed_nome_dtped_inc
ON public.data_detailed (nome, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

CREATE INDEX IF NOT EXISTS idx_detailed_codcli_dtped_inc
ON public.data_detailed (codcli, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codusur, tipovenda);

-- History Data
CREATE INDEX IF NOT EXISTS idx_history_superv_dtped_inc
ON public.data_history (superv, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

CREATE INDEX IF NOT EXISTS idx_history_nome_dtped_inc
ON public.data_history (nome, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

CREATE INDEX IF NOT EXISTS idx_history_codcli_dtped_inc
ON public.data_history (codcli, dtped)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codusur, tipovenda);
