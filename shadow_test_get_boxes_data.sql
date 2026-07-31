BEGIN;

CREATE TABLE IF NOT EXISTS public.profiles (id uuid, status text);
INSERT INTO public.profiles (id, status) VALUES ('00000000-0000-0000-0000-000000000000', 'aprovado');
ALTER TABLE dim_produtos ADD COLUMN IF NOT EXISTS qtde_embalagem_master numeric;

DO $$
BEGIN
  PERFORM get_boxes_dashboard_data(NULL, NULL, NULL, NULL, NULL, '2024', NULL, NULL, NULL);
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Error occurred: %', SQLERRM;
END $$;

ROLLBACK;
