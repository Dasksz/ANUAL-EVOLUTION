
-- ==============================================================================
-- OPTIMIZATION: FINANCIAL AGGREGATION TABLE ("O Pulo do Gato")
-- ==============================================================================

-- 1. CRIAR A TABELA (Garante que ela exista)
CREATE TABLE IF NOT EXISTS public.data_financials (
    ano int,
    mes int,
    filial text,
    cidade text,
    superv text,
    nome text,       -- Vendedor
    codfor text,     -- Fornecedor
    tipovenda text,
    -- Métricas pré-somadas
    vlvenda numeric,
    peso numeric,
    bonificacao numeric,
    devolucao numeric,
    positivacao_count int -- Contagem de clientes positivados
);

-- 2. CRIAR O ÍNDICE (Para velocidade máxima nos filtros)
CREATE INDEX IF NOT EXISTS idx_fin_filters ON public.data_financials (ano, mes, filial, cidade, superv, nome);

-- 3. DEFINIR A FUNÇÃO DE ATUALIZAÇÃO (Com a correção da coluna pre_positivacao_val)
CREATE OR REPLACE FUNCTION refresh_data_financials()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Limpa a tabela antes de popular
    TRUNCATE TABLE public.data_financials;

    -- Insere os dados agregados
    INSERT INTO public.data_financials (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda,
        vlvenda, peso, bonificacao, devolucao, positivacao_count
    )
    SELECT
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda,
        SUM(vlvenda) as vlvenda,
        SUM(peso) as peso,
        SUM(bonificacao) as bonificacao,
        SUM(devolucao) as devolucao,
        SUM(pre_positivacao_val) as positivacao_count
    FROM public.data_summary
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8;
END;
$$;

-- 4. EXECUTAR A FUNÇÃO AGORA (Para popular os dados)
SELECT refresh_data_financials();
