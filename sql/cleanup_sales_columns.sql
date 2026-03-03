-- Script de Limpeza: Remove a coluna 'qtvenda_embalagem_master' das tabelas de vendas
-- Esta informação passará a residir apenas na tabela dim_produtos

ALTER TABLE IF EXISTS data_detailed DROP COLUMN IF EXISTS qtvenda_embalagem_master CASCADE;
ALTER TABLE IF EXISTS data_history DROP COLUMN IF EXISTS qtvenda_embalagem_master CASCADE;

-- Fim do script
