-- Cleanup script to remove products from disallowed suppliers
-- Allows only: 707 (Extrusados), 708 (Nao Extrusados), 752 (Torcida), 1119 (Foods)

DELETE FROM public.dim_produtos
WHERE codfor NOT IN ('707', '708', '752', '1119');
