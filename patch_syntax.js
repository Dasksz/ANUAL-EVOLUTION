const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const oldDropColumns = `-- Migration Helper: Drop columns if they exist (for existing databases)
DO $$
BEGIN
    -- Drop from data_detailed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'cliente_nome') THEN
        ALTER TABLE public.data_detailed DROP COLUMN cliente_nome CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'bairro') THEN
        ALTER TABLE public.data_detailed DROP COLUMN bairro CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'observacaofor') THEN
        ALTER TABLE public.data_detailed DROP COLUMN observacaofor CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'descricao') THEN
        ALTER TABLE public.data_detailed DROP COLUMN descricao CASCADE;
    END IF;

    -- Drop from data_history
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'cliente_nome') THEN
        ALTER TABLE public.data_history DROP COLUMN cliente_nome CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'bairro') THEN
        ALTER TABLE public.data_history DROP COLUMN bairro CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'observacaofor') THEN
        ALTER TABLE public.data_history DROP COLUMN observacaofor CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'descricao') THEN
        ALTER TABLE public.data_history DROP COLUMN descricao CASCADE;
    END IF;
END $$;`;

const newDropColumns = `-- Migration Helper: Drop columns if they exist (for existing databases)
ALTER TABLE IF EXISTS public.data_detailed DROP COLUMN IF EXISTS cliente_nome CASCADE;
ALTER TABLE IF EXISTS public.data_detailed DROP COLUMN IF EXISTS bairro CASCADE;
ALTER TABLE IF EXISTS public.data_detailed DROP COLUMN IF EXISTS observacaofor CASCADE;
ALTER TABLE IF EXISTS public.data_detailed DROP COLUMN IF EXISTS descricao CASCADE;

ALTER TABLE IF EXISTS public.data_history DROP COLUMN IF EXISTS cliente_nome CASCADE;
ALTER TABLE IF EXISTS public.data_history DROP COLUMN IF EXISTS bairro CASCADE;
ALTER TABLE IF EXISTS public.data_history DROP COLUMN IF EXISTS observacaofor CASCADE;
ALTER TABLE IF EXISTS public.data_history DROP COLUMN IF EXISTS descricao CASCADE;`;

if (content.includes(oldDropColumns)) {
    content = content.replace(oldDropColumns, newDropColumns);
    console.log("Patched Drop Columns successfully!");
} else {
    console.log("oldDropColumns not found!");
}

const oldRcaDrop = `-- Remove RCA 2 Column if it exists (for migration support)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_clients' AND column_name = 'rca2') THEN
        ALTER TABLE public.data_clients DROP COLUMN rca2;
    END IF;
END $$;`;

const newRcaDrop = `-- Remove RCA 2 Column if it exists (for migration support)
ALTER TABLE IF EXISTS public.data_clients DROP COLUMN IF EXISTS rca2 CASCADE;`;

if (content.includes(oldRcaDrop)) {
    content = content.replace(oldRcaDrop, newRcaDrop);
    console.log("Patched RCA Drop successfully!");
} else {
    console.log("oldRcaDrop not found!");
}

const oldRamoAdd = `-- Add Ramo column if it does not exist (Schema Migration)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_clients' AND column_name = 'ramo') THEN
        ALTER TABLE public.data_clients ADD COLUMN ramo text;
    END IF;
END $$;`;

const newRamoAdd = `-- Add Ramo column if it does not exist (Schema Migration)
ALTER TABLE IF EXISTS public.data_clients ADD COLUMN IF NOT EXISTS ramo text;`;

if (content.includes(oldRamoAdd)) {
    content = content.replace(oldRamoAdd, newRamoAdd);
    console.log("Patched Ramo Add successfully!");
} else {
    console.log("oldRamoAdd not found!");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
