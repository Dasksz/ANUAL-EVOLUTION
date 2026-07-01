DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_summary_frequency' AND column_name = 'cnpj') THEN
        ALTER TABLE public.data_summary_frequency ADD COLUMN cnpj text;
    END IF;
END $$;
