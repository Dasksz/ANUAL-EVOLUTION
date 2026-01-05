-- Optimization: Add 'tipovenda' to covering indexes to enable Index Only Scans
-- The dashboard aggregation queries heavily rely on 'tipovenda' for conditional summing.
-- Without this in the index, Postgres must perform heap fetches for every row in the date range.

-- Drop old indexes
DROP INDEX IF EXISTS idx_detailed_dtped_composite;
DROP INDEX IF EXISTS idx_history_dtped_composite;

-- Recreate with 'tipovenda' in INCLUDE
CREATE INDEX idx_detailed_dtped_composite
ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

CREATE INDEX idx_history_dtped_composite
ON public.data_history (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);
