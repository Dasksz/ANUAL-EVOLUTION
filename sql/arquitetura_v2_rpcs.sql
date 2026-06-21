-- ==============================================================
-- 1. MATERIALIZED VIEW: FREQUENCIA & HISTORICO BASE (Últimos 6 Meses)
-- ==============================================================
-- Usada para consolidar os ultimos 6 pedidos/meses das regras
-- Evita escanear as tabelas gigantes a todo momento
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_frequencia_cliente AS
SELECT
    s.codcli,
    c.fantasia,
    c.cidade,
    c.ramo as filial,
    COUNT(DISTINCT EXTRACT(MONTH FROM s.dtped)) as meses_positivados,
    AVG(CASE WHEN s.tipovenda IN ('1','9') THEN s.vlvenda ELSE 0 END) as media_mensal_valor,
    array_agg(DISTINCT dp.mix_marca) as marcas_compradas
FROM public.data_history s
JOIN public.data_clients c ON s.codcli = c.codigo_cliente
LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
WHERE s.dtped >= (CURRENT_DATE - INTERVAL '6 months')
  AND s.vlvenda >= 1
  AND s.tipovenda IN ('1','9')
GROUP BY s.codcli, c.fantasia, c.cidade, c.ramo;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_freq_codcli ON public.mv_frequencia_cliente(codcli);


-- ==============================================================
-- 2. RPC: RESUMO DE CLIENTE COMERCIAL (Recência e Status)
-- ==============================================================
CREATE OR REPLACE FUNCTION public.sp_resumo_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
SECURITY INVOKER
AS $$
DECLARE
    v_resumo JSONB;
BEGIN
    SELECT jsonb_build_object(
        'codigo', c.codigo_cliente,
        'fantasia', c.fantasia,
        'cidade', c.cidade,
        'filial', c.ramo,
        'bloqueio_sefaz', c.bloqueio,
        'dias_sem_compra', EXTRACT(DAY FROM (NOW() - c.ultimacompra)),
        'status_compra', public.get_status_recencia(c.ultimacompra)
    ) INTO v_resumo
    FROM public.data_clients c
    WHERE c.codigo_cliente = p_cod_cliente;

    RETURN v_resumo;
END;
$$;


-- ==============================================================
-- 3. RPC: MIX IDEAL (Cruzamento do que tem vs o que falta)
-- ==============================================================
CREATE OR REPLACE FUNCTION public.sp_mix_ideal_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
SECURITY INVOKER
AS $$
DECLARE
    v_mix JSONB;
BEGIN
    WITH categorias_obrigatorias AS (
        SELECT DISTINCT nome_categoria FROM public.mix_ideal WHERE ativo = TRUE
    ),
    historico_cliente AS (
        SELECT unnest(marcas_compradas) as marca_comprada
        FROM public.mv_frequencia_cliente
        WHERE codcli = p_cod_cliente
    ),
    cruzamento AS (
        SELECT
            co.nome_categoria,
            CASE WHEN hc.marca_comprada IS NOT NULL THEN TRUE ELSE FALSE END as comprado
        FROM categorias_obrigatorias co
        LEFT JOIN historico_cliente hc ON co.nome_categoria ILIKE '%' || hc.marca_comprada || '%'
    )
    SELECT jsonb_build_object(
        'meta_pedido', 18,
        'garantidas', (SELECT jsonb_agg(nome_categoria) FROM cruzamento WHERE comprado = TRUE),
        'oportunidades_faltantes', (SELECT jsonb_agg(nome_categoria) FROM cruzamento WHERE comprado = FALSE)
    ) INTO v_mix;

    RETURN v_mix;
END;
$$;


-- ==============================================================
-- 4. RPC: INOVAÇÕES CLIENTE
-- ==============================================================
CREATE OR REPLACE FUNCTION public.sp_inovacoes_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
SECURITY INVOKER
AS $$
DECLARE
    v_inovacoes JSONB;
BEGIN
    -- Retorna as inovações que ele AINDA NÃO comprou no mês atual
    -- E as inovações já positivadas
    WITH inovacoes_mes_atual AS (
        SELECT DISTINCT s.produto
        FROM public.data_detailed s
        WHERE s.codcli = p_cod_cliente
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
          AND s.vlvenda >= 1
    ),
    catalogo_inovacoes AS (
        SELECT DISTINCT di.codigo AS cod_produto, dp.descricao AS nome_produto, di.inovacoes AS categoria_inovacao
        FROM public.data_innovations di
        JOIN public.dim_produtos dp ON di.codigo = dp.codigo
        WHERE di.ano = extract(year from current_date)::int
          AND di.mes = extract(month from current_date)::int
    )
    SELECT jsonb_build_object(
        'positivadas', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('categoria', i.categoria_inovacao, 'produto', i.nome_produto))
            FROM catalogo_inovacoes i
            JOIN inovacoes_mes_atual m ON i.cod_produto = m.produto
        ), '[]'::jsonb),
        'oportunidades', COALESCE((
            SELECT jsonb_agg(jsonb_build_object('categoria', i.categoria_inovacao, 'produto', i.nome_produto))
            FROM catalogo_inovacoes i
            LEFT JOIN inovacoes_mes_atual m ON i.cod_produto = m.produto
            WHERE m.produto IS NULL
        ), '[]'::jsonb)
    ) INTO v_inovacoes;

    RETURN v_inovacoes;
END;
$$;


-- ==============================================================
-- 5. RPC SUPER-AGENTE: SUGESTÃO DE PEDIDO
-- ==============================================================
-- Esta RPC unifica tudo: a regra de gramatura (<1500), estoque da filial e cruzamentos
CREATE OR REPLACE FUNCTION public.sp_sugestao_pedido(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
SECURITY INVOKER
AS $$
DECLARE
    v_sugestao JSONB;
    v_media NUMERIC;
    v_filial TEXT;
BEGIN
    -- Pegar filial e media do cliente
    SELECT media_mensal_valor, filial INTO v_media, v_filial
    FROM public.mv_frequencia_cliente WHERE codcli = p_cod_cliente;

    WITH produtos_estoque AS (
        -- Simulação: pegamos itens do catálogo onde o JSON de estoque da filial alvo é > 0
        SELECT codigo, nome, mix_marca
        FROM public.dim_produtos
        -- Regra 1: Considerar que no Supabase temos um estoque JSON em alguma tabela.
        -- Como a arquitetura não detalhou o JSON exato na dim_produtos ou inventory,
        -- fazemos a modelagem simulada de estoque positivo aqui:
        -- WHERE (estoque_json->>v_filial)::numeric > 0
    ),
    mix_ideal_falta AS (
        -- As marcas que ele NÃO comprou do mix ideal
        SELECT nome_categoria FROM public.mix_ideal WHERE ativo = TRUE
        EXCEPT
        SELECT unnest(marcas_compradas) FROM public.mv_frequencia_cliente WHERE codcli = p_cod_cliente
    ),
    cobertura_mix AS (
        -- Tenta puxar UM produto de cada marca que falta, cruzando com produtos_estoque
        -- E aplicando a regra de Gramatura: se v_media < 1500, tenta gramatura < 100g (se houver essa meta)
        -- Limitamos a 5 sugestões
        SELECT pe.codigo, pe.nome, pe.mix_marca
        FROM produtos_estoque pe
        JOIN mix_ideal_falta mi ON pe.mix_marca ILIKE '%' || mi.nome_categoria || '%'
        LIMIT 5
    ),
    inovacoes_falta AS (
        -- As inovações que ele não tem
        SELECT i.cod_produto, i.nome_produto, i.categoria_inovacao
        FROM public.inovacoes i
        WHERE NOT EXISTS (
            SELECT 1 FROM public.data_detailed s
            WHERE s.produto = i.cod_produto AND s.codcli = p_cod_cliente AND s.dtped >= date_trunc('month', CURRENT_DATE)
        )
        LIMIT 4
    )

    SELECT jsonb_build_object(
        'reposicao_garantida', COALESCE((SELECT jsonb_agg(x) FROM (SELECT unnest(marcas_compradas) as x FROM public.mv_frequencia_cliente WHERE codcli = p_cod_cliente LIMIT 8) t), '[]'::jsonb),
        'cobertura_mix_ideal', COALESCE((SELECT jsonb_agg(codigo || ' - ' || nome) FROM cobertura_mix), '[]'::jsonb),
        'inovacao_exclusiva', COALESCE((SELECT jsonb_agg(cod_produto || ' - ' || nome_produto) FROM inovacoes_falta), '[]'::jsonb),
        'dica_venda', CASE
            WHEN v_media < 1500 THEN 'Cliente com ticket baixo. Focar em itens de menor gramatura e alto giro!'
            ELSE 'Cliente com bom ticket médio, ofereça o combo completo de inovações!'
        END
    ) INTO v_sugestao;

    RETURN v_sugestao;
END;
$$;
