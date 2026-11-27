REVOKE ALL ON FUNCTION public.elma_recovery_filtered_stats(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.elma_recovery_filtered_stats(jsonb) TO authenticated;
