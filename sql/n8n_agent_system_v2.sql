-- =========================================================================================
-- FUNÇÕES DE CONSULTA VIA AGENTE (V2) - OTIMIZADAS PARA O N8N
-- As funções abaixo agora são "STABLE" em vez de voltarem valores por padrão sem cash.
-- Isso previne chamadas duplicadas por linha na View de Agente e melhora performance.
-- =========================================================================================

-- Função 1: Resumo Cliente
CREATE OR REPLACE FUNCTION public.sp_resumo_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
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

-- Função 2: Mix Ideal
CREATE OR REPLACE FUNCTION public.sp_mix_ideal_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
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

-- Função 3: Inovações
CREATE OR REPLACE FUNCTION public.sp_inovacoes_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_inovacoes JSONB;
BEGIN
    WITH inovacoes_mes_atual AS (
        SELECT DISTINCT s.produto
        FROM public.data_detailed s
        WHERE s.codcli = p_cod_cliente
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
          AND s.vlvenda >= 1
    ),
    catalogo_inovacoes AS (
        SELECT cod_produto, nome_produto, categoria_inovacao
        FROM public.inovacoes WHERE ativo = TRUE
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

-- Função 4: Sugestão de Pedido
CREATE OR REPLACE FUNCTION public.sp_sugestao_pedido(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_sugestao JSONB;
    v_media NUMERIC;
    v_filial TEXT;
BEGIN
    SELECT media_mensal_valor, filial INTO v_media, v_filial
    FROM public.mv_frequencia_cliente WHERE codcli = p_cod_cliente;

    WITH produtos_estoque AS (
        SELECT codigo, nome, mix_marca
        FROM public.dim_produtos
    ),
    mix_ideal_falta AS (
        SELECT nome_categoria FROM public.mix_ideal WHERE ativo = TRUE
        EXCEPT
        SELECT unnest(marcas_compradas) FROM public.mv_frequencia_cliente WHERE codcli = p_cod_cliente
    ),
    cobertura_mix AS (
        SELECT pe.codigo, pe.nome, pe.mix_marca
        FROM produtos_estoque pe
        JOIN mix_ideal_falta mi ON pe.mix_marca ILIKE '%' || mi.nome_categoria || '%'
        LIMIT 5
    ),
    inovacoes_falta AS (
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


-- =========================================================================================
-- VIEW: n8n_agent_view_v2 (SUPER VIEW CONSOLIDADA PARA O AGENTE ELMA V2)
-- DESCRIÇÃO: "Super View" para consulta unificada por opção.
-- =========================================================================================

DROP VIEW IF EXISTS public.n8n_agent_view_v2 CASCADE;

CREATE VIEW public.n8n_agent_view_v2 WITH (security_invoker = true) AS
-- OPCAO 1: Cadastro de Cliente
SELECT '1'::text AS opcao,
       NULL::text AS cpf,
       c.codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       jsonb_build_object(
           'fantasia', c.fantasia,
           'razaosocial', c.razaosocial,
           'cnpj', c.cnpj,
           'bloqueio', c.bloqueio,
           'bairro', c.bairro,
           'cidade', c.cidade,
           'filial', c.ramo
       ) AS dados
FROM data_clients c

UNION ALL

-- OPCAO 2: Historico de Pedidos (Agrupado)
SELECT '2'::text AS opcao,
       NULL::text AS cpf,
       v.codcli AS codigo_cliente,
       NULL::text AS setor_transferencia,
       v.tipo_venda AS tipo_venda_pedido,
       v.pedido AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       jsonb_build_object(
           'numero_pedido', v.pedido,
           'data_pedido', v.data_pedido,
           'valor_total', v.valor_total,
           'tipo', v.tipo_venda,
           'contagem_de_itens', v.contagem_de_itens,
           'mes_atingiu_mix_salty', CASE WHEN v.has_salty_mix THEN 'SIM' ELSE 'NAO' END,
           'mes_atingiu_mix_foods', CASE WHEN v.has_foods_mix THEN 'SIM' ELSE 'NAO' END
       ) AS dados
FROM (
    SELECT
        s.pedido,
        MAX(s.codcli) as codcli,
        MAX(s.tipovenda) as tipo_venda,
        MAX(s.dtped) as data_pedido,
        SUM(s.vlvenda) as valor_total,
        COUNT(s.produto) as contagem_de_itens,
        MAX(CASE WHEN dp.mix_categoria = 'SALTY' THEN TRUE ELSE FALSE END) as has_salty_mix,
        MAX(CASE WHEN dp.mix_categoria = 'FOODS' THEN TRUE ELSE FALSE END) as has_foods_mix
    FROM (SELECT pedido, codcli, tipovenda, dtped, vlvenda, produto FROM data_history UNION ALL SELECT pedido, codcli, tipovenda, dtped, vlvenda, produto FROM data_detailed) s
    LEFT JOIN dim_produtos dp ON dp.codigo = s.produto
    GROUP BY s.pedido
) v

UNION ALL

-- OPCAO 3: Detalhamento de Pedido Específico (Agrupado por Produto)
SELECT '3'::text AS opcao,
       NULL::text AS cpf,
       v.codcli AS codigo_cliente,
       NULL::text AS setor_transferencia,
       v.tipo_venda AS tipo_venda_pedido,
       v.pedido AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       jsonb_build_object(
           'numero_pedido', v.pedido,
           'data_pedido', v.data_pedido,
           'valor_total', v.valor_total,
           'tipo', v.tipo_venda,
           'lista_itens_comprados', v.itens
       ) AS dados
FROM (
    SELECT
        s.pedido,
        MAX(s.codcli) as codcli,
        MAX(s.tipovenda) as tipo_venda,
        MAX(s.dtped) as data_pedido,
        SUM(s.vlvenda) as valor_total,
        jsonb_agg(
            jsonb_build_object(
                'produto', s.produto,
                'nome_do_produto', COALESCE(dp.descricao, s.produto),
                'quantidade', s.qtvenda,
                'valor_total_R$', s.vlvenda,
                'preco_unitario_R$', CASE WHEN s.qtvenda > 0 THEN ROUND((s.vlvenda / s.qtvenda)::numeric, 2) ELSE 0 END
            )
        ) as itens
    FROM (SELECT pedido, codcli, tipovenda, dtped, vlvenda, qtvenda, produto FROM data_history UNION ALL SELECT pedido, codcli, tipovenda, dtped, vlvenda, qtvenda, produto FROM data_detailed) s
    LEFT JOIN dim_produtos dp ON dp.codigo = s.produto
    GROUP BY s.pedido
) v

UNION ALL

-- OPCAO 4: Inovacoes
SELECT '4'::text AS opcao,
       NULL::text AS cpf,
       c.codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       public.sp_inovacoes_cliente(c.codigo_cliente) AS dados
FROM data_clients c

UNION ALL

-- OPCAO 5: Mix Ideal
SELECT '5'::text AS opcao,
       NULL::text AS cpf,
       c.codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       public.sp_mix_ideal_cliente(c.codigo_cliente) AS dados
FROM data_clients c

UNION ALL

-- OPCAO 6: Sugestao de Pedido
SELECT '6'::text AS opcao,
       NULL::text AS cpf,
       c.codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       public.sp_sugestao_pedido(c.codigo_cliente) AS dados
FROM data_clients c

UNION ALL

-- OPCAO 7: Consulta Estoque
SELECT '7'::text AS opcao,
       NULL::text AS cpf,
       NULL::text AS codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       dp.codigo AS codigo_produto,
       dp.mix_marca AS termo_busca,
       jsonb_build_object(
           'nome_do_produto', dp.descricao,
           'codigo_produto', dp.codigo,
           'estoque_filial', dp.estoque_filial,
           'marca', dp.mix_marca
       ) AS dados
FROM dim_produtos dp

UNION ALL

-- OPCAO 8: Transferir Atendimento
SELECT '8'::text AS opcao,
       NULL::text AS cpf,
       NULL::text AS codigo_cliente,
       'Suporte'::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       jsonb_build_object('mensagem', 'Atendimento será transferido para Suporte', 'setor', 'Suporte') AS dados;

REVOKE ALL ON public.n8n_agent_view_v2 FROM anon, authenticated;
GRANT SELECT ON public.n8n_agent_view_v2 TO service_role;
