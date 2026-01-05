
-- Optimization: Create indices to speed up dashboard queries and avoid timeouts

-- 1. Detailed Table Index (Covers main dashboard queries AND kpi_base_clients)
DROP INDEX IF EXISTS idx_detailed_dtped_composite;
CREATE INDEX idx_detailed_dtped_composite
ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

-- 2. History Table Index (Covers main dashboard queries AND kpi_base_clients)
DROP INDEX IF EXISTS idx_history_dtped_composite;
CREATE INDEX idx_history_dtped_composite
ON public.data_history (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);
