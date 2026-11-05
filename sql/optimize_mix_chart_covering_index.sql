-- Cover the annual mix aggregation without reading wide JSON/array order rows.
-- Preserves the existing RPC, current-portfolio view, filters and mix flags.
CREATE INDEX IF NOT EXISTS idx_frequency_mix_flags_cover
 ON public.data_summary_frequency(ano,mes,codcli)
 INCLUDE(has_cheetos,has_doritos,has_fandangos,has_ruffles,has_torcida,
         has_toddynho,has_toddy,has_quaker,has_kerococo)
 WHERE tipovenda NOT IN('5','11');
-- After applying, run outside a transaction:
-- VACUUM (ANALYZE) public.data_summary_frequency;
