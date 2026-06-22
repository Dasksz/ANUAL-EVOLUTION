DROP FUNCTION IF EXISTS public.sp_inovacoes_cliente(text) CASCADE;
DROP FUNCTION IF EXISTS public.sp_sugestao_pedido(text) CASCADE;
DROP VIEW IF EXISTS public.n8n_agent_view_v2 CASCADE;

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
        SELECT i.codigo as cod_produto, p.descricao as nome_produto, i.inovacoes as categoria_inovacao
        FROM public.data_innovations i
        JOIN public.dim_produtos p ON p.codigo = i.codigo
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
        SELECT i.codigo as cod_produto, p.descricao as nome_produto, i.inovacoes as categoria_inovacao
        FROM public.data_innovations i
        JOIN public.dim_produtos p ON p.codigo = i.codigo
        WHERE NOT EXISTS (
            SELECT 1 FROM public.data_detailed s
            WHERE s.produto = i.codigo AND s.codcli = p_cod_cliente AND s.dtped >= date_trunc('month', CURRENT_DATE)
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


CREATE VIEW public.n8n_agent_view_v2 WITH (security_invoker = true) AS
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
        bool_or(dp.mix_categoria = 'SALTY') as has_salty_mix,
        bool_or(dp.mix_categoria = 'FOODS') as has_foods_mix
    FROM (SELECT pedido, codcli, tipovenda, dtped, vlvenda, produto FROM data_history UNION ALL SELECT pedido, codcli, tipovenda, dtped, vlvenda, produto FROM data_detailed) s
    LEFT JOIN dim_produtos dp ON dp.codigo = s.produto
    GROUP BY s.pedido
) v

UNION ALL

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

GRANT SELECT ON public.n8n_agent_view_v2 TO service_role;
