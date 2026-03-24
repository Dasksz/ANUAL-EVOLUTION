const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const oldProfileAdd = `DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'name') THEN
        ALTER TABLE public.profiles ADD COLUMN name text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'phone') THEN
        ALTER TABLE public.profiles ADD COLUMN phone text;
    END IF;
END $$;`;

const newProfileAdd = `ALTER TABLE IF EXISTS public.profiles ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE IF EXISTS public.profiles ADD COLUMN IF NOT EXISTS phone text;`;

if (content.includes(oldProfileAdd)) {
    content = content.replace(oldProfileAdd, newProfileAdd);
    console.log("Patched Profiles successfully!");
} else {
    console.log("oldProfileAdd not found!");
}

const oldProdAdd = `DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'codfor') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN codfor text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'mix_marca') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN mix_marca text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'mix_categoria') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN mix_categoria text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'categoria_produto') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN categoria_produto text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'estoque_filial') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN estoque_filial jsonb DEFAULT '{}'::jsonb;
    END IF;
END $$;`;

const newProdAdd = `ALTER TABLE IF EXISTS public.dim_produtos ADD COLUMN IF NOT EXISTS codfor text;
ALTER TABLE IF EXISTS public.dim_produtos ADD COLUMN IF NOT EXISTS mix_marca text;
ALTER TABLE IF EXISTS public.dim_produtos ADD COLUMN IF NOT EXISTS mix_categoria text;
ALTER TABLE IF EXISTS public.dim_produtos ADD COLUMN IF NOT EXISTS categoria_produto text;
ALTER TABLE IF EXISTS public.dim_produtos ADD COLUMN IF NOT EXISTS estoque_filial jsonb DEFAULT '{}'::jsonb;`;

if (content.includes(oldProdAdd)) {
    content = content.replace(oldProdAdd, newProdAdd);
    console.log("Patched dim_produtos successfully!");
} else {
    console.log("oldProdAdd not found!");
}

const oldHashDrop = `DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'row_hash') THEN
        ALTER TABLE public.data_detailed DROP COLUMN row_hash;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'row_hash') THEN
        ALTER TABLE public.data_history DROP COLUMN row_hash;
    END IF;
END $$;`;

const newHashDrop = `ALTER TABLE IF EXISTS public.data_detailed DROP COLUMN IF EXISTS row_hash CASCADE;
ALTER TABLE IF EXISTS public.data_history DROP COLUMN IF EXISTS row_hash CASCADE;`;

if (content.includes(oldHashDrop)) {
    content = content.replace(oldHashDrop, newHashDrop);
    console.log("Patched Hash Drops successfully!");
} else {
    console.log("oldHashDrop not found!");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
