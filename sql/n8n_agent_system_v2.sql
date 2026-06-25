-- Drop the existing view since it references the function we want to recreate
DROP VIEW IF EXISTS public.n8n_agent_view_v2 CASCADE;
DROP FUNCTION IF EXISTS public.sp_mix_ideal_cliente(text) CASCADE;

CREATE OR REPLACE FUNCTION public.sp_mix_ideal_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_mix JSONB;
BEGIN
    WITH categorias_obrigatorias AS (
        SELECT DISTINCT nome_categoria, produto_obrigatorio 
        FROM public.mix_ideal 
        WHERE ativo = TRUE
    ),
    historico_cliente_mes_atual AS (
        SELECT DISTINCT p.mix_marca as marca_comprada 
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente 
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    historico_cliente_3_meses AS (
        SELECT DISTINCT p.mix_marca as marca_comprada 
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente 
          AND s.dtped >= date_trunc('month', CURRENT_DATE - INTERVAL '3 months')
          AND s.tipovenda IN ('1','9')
    ),
    cruzamento AS (
        SELECT 
            co.nome_categoria,
            co.produto_obrigatorio,
            CASE WHEN hc.marca_comprada IS NOT NULL THEN TRUE ELSE FALSE END as comprado_mes_atual,
            CASE WHEN h3.marca_comprada IS NOT NULL THEN TRUE ELSE FALSE END as comprado_ultimos_3_meses
        FROM categorias_obrigatorias co
        LEFT JOIN historico_cliente_mes_atual hc ON hc.marca_comprada ILIKE '%' || co.nome_categoria || '%'
        LEFT JOIN historico_cliente_3_meses h3 ON h3.marca_comprada ILIKE '%' || co.nome_categoria || '%'
    )
    SELECT jsonb_build_object(
        'meta_pedido', 18,
        'categorias_garantidas_este_mes', (SELECT jsonb_agg(nome_categoria) FROM cruzamento WHERE comprado_mes_atual = TRUE),
        'oportunidades_faltantes_este_mes_mas_compradas_antes', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'categoria', nome_categoria,
                    'produto_sugerido_codigo', p.codigo,
                    'produto_sugerido_nome', p.descricao,
                    'estoque_filial', p.estoque_filial
                )
            )
            FROM cruzamento
            LEFT JOIN LATERAL (
                SELECT codigo, descricao, estoque_filial
                FROM public.dim_produtos dp
                WHERE dp.mix_marca ILIKE '%' || cruzamento.nome_categoria || '%'
                  AND (cruzamento.produto_obrigatorio IS NULL OR cruzamento.produto_obrigatorio = '' OR dp.codigo = cruzamento.produto_obrigatorio)
                ORDER BY dp.codigo
                LIMIT 1
            ) p ON true
            WHERE comprado_mes_atual = FALSE AND comprado_ultimos_3_meses = TRUE
        ),
        'oportunidades_faltantes_nunca_compradas', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'categoria', nome_categoria,
                    'produto_sugerido_codigo', p.codigo,
                    'produto_sugerido_nome', p.descricao,
                    'estoque_filial', p.estoque_filial
                )
            )
            FROM cruzamento
            LEFT JOIN LATERAL (
                SELECT codigo, descricao, estoque_filial
                FROM public.dim_produtos dp
                WHERE dp.mix_marca ILIKE '%' || cruzamento.nome_categoria || '%'
                  AND (cruzamento.produto_obrigatorio IS NULL OR cruzamento.produto_obrigatorio = '' OR dp.codigo = cruzamento.produto_obrigatorio)
                ORDER BY dp.codigo
                LIMIT 1
            ) p ON true
            WHERE comprado_mes_atual = FALSE AND comprado_ultimos_3_meses = FALSE
        )
    ) INTO v_mix;

    RETURN v_mix;
END;
$$;
DROP FUNCTION IF EXISTS public.sp_sugestao_pedido(text) CASCADE;

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

    WITH historico_cliente_mes_atual AS (
        SELECT DISTINCT p.mix_marca as marca_comprada 
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente 
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    mix_ideal_falta AS (
        SELECT nome_categoria, produto_obrigatorio 
        FROM public.mix_ideal WHERE ativo = TRUE
        EXCEPT
        SELECT marca_comprada, NULL FROM historico_cliente_mes_atual
    ),
    produtos_cliente_comprava_3_meses_mix AS (
        SELECT DISTINCT p.codigo, p.descricao as nome, p.mix_marca
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente 
          AND s.dtped >= date_trunc('month', CURRENT_DATE - INTERVAL '3 months')
          AND s.dtped < date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    cobertura_mix_historico AS (
        SELECT DISTINCT pe.codigo, pe.nome, pe.mix_marca
        FROM produtos_cliente_comprava_3_meses_mix pe
        JOIN mix_ideal_falta mi ON pe.mix_marca ILIKE '%' || mi.nome_categoria || '%'
        LIMIT 3
    ),
    cobertura_mix_codigo AS (
        SELECT DISTINCT p.codigo, p.descricao as nome, mi.nome_categoria as mix_marca
        FROM dim_produtos p
        JOIN mix_ideal_falta mi ON p.codigo = mi.produto_obrigatorio
        WHERE mi.produto_obrigatorio IS NOT NULL AND mi.produto_obrigatorio != ''
        LIMIT 3
    ),
    inovacoes_falta AS (
        SELECT i.codigo as cod_produto, p.descricao as nome_produto, i.inovacoes as categoria_inovacao 
        FROM public.data_innovations i
        JOIN public.dim_produtos p ON p.codigo = i.codigo
        WHERE NOT EXISTS (
            SELECT 1 FROM public.data_detailed s 
            WHERE s.produto = i.codigo AND s.codcli = p_cod_cliente AND s.dtped >= date_trunc('month', CURRENT_DATE)
        )
        LIMIT 3
    )
    
    SELECT jsonb_build_object(
        'reposicao_garantida_ja_compradas_este_mes', COALESCE((SELECT jsonb_agg(marca_comprada) FROM (SELECT marca_comprada FROM historico_cliente_mes_atual LIMIT 5) t), '[]'::jsonb),
        'cobertura_mix_sugestao_com_base_no_historico_3m', COALESCE((SELECT jsonb_agg(codigo || ' - ' || nome) FROM (SELECT codigo, nome FROM cobertura_mix_historico UNION SELECT codigo, nome FROM cobertura_mix_codigo LIMIT 3) sub), '[]'::jsonb),
        'inovacoes_sugestao', COALESCE((SELECT jsonb_agg(cod_produto || ' - ' || nome_produto) FROM inovacoes_falta), '[]'::jsonb),
        'dica_venda', CASE 
            WHEN v_media < 1500 THEN 'Ofereça as opções de cobertura de Mix que ele já levou meses anteriores em pacotes menores para garantir giro!'
            ELSE 'O cliente tem bom potencial e faltam poucas categorias para o Mix Ideal. Insira as Inovações junto!'
        END
    ) INTO v_sugestao;

    RETURN v_sugestao;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_inovacoes_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_inovacoes JSONB;
BEGIN
    WITH inovacoes_ativas AS (
        SELECT DISTINCT i.codigo as cod_produto, p.descricao as nome_produto, i.inovacoes as categoria_inovacao, p.mix_marca
        FROM public.data_innovations i
        JOIN public.dim_produtos p ON p.codigo = i.codigo
    ),
    historico_cliente_mes_atual AS (
        SELECT DISTINCT s.produto as produto_comprado
        FROM public.data_detailed s
        WHERE s.codcli = p_cod_cliente
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    cruzamento AS (
        SELECT
            i.categoria_inovacao,
            i.cod_produto,
            i.nome_produto,
            i.mix_marca,
            CASE WHEN hc.produto_comprado IS NOT NULL THEN TRUE ELSE FALSE END as comprado_mes_atual
        FROM inovacoes_ativas i
        LEFT JOIN historico_cliente_mes_atual hc ON hc.produto_comprado = i.cod_produto
    )
    SELECT jsonb_build_object(
        'inovacoes_positivadas_mes_atual', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'categoria_inovacao', categoria_inovacao,
                    'codigo_produto', cod_produto,
                    'nome_produto', nome_produto
                )
            ), '[]'::jsonb)
            FROM cruzamento WHERE comprado_mes_atual = TRUE
        ),
        'oportunidades_sugestoes_inovacoes', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'categoria_inovacao', categoria_inovacao,
                    'codigo_produto', cod_produto,
                    'nome_produto', nome_produto,
                    'justificativa', 'Cliente não comprou esta inovação da marca ' || COALESCE(mix_marca, 'Diversos') || ' neste mês'
                )
            ), '[]'::jsonb)
            FROM (SELECT * FROM cruzamento WHERE comprado_mes_atual = FALSE LIMIT 9) t
        )
    ) INTO v_inovacoes;

    RETURN v_inovacoes;
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
        SUM(COALESCE(s.vlvenda, s.vlbonific, 0)) as valor_total,
        COUNT(s.produto) as contagem_de_itens,
        bool_or(dp.mix_categoria = 'SALTY') as has_salty_mix,
        bool_or(dp.mix_categoria = 'FOODS') as has_foods_mix
    FROM (
        SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, produto FROM data_history 
        UNION ALL 
        SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, produto FROM data_detailed
    ) s
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
        SUM(COALESCE(s.vlvenda, s.vlbonific, 0)) as valor_total,
        jsonb_agg(
            jsonb_build_object(
                'produto', s.produto,
                'nome_do_produto', COALESCE(dp.descricao, s.produto),
                'quantidade', s.qtvenda,
                'valor_total_R$', COALESCE(s.vlvenda, s.vlbonific, 0),
                'preco_unitario_R$', CASE WHEN s.qtvenda > 0 THEN ROUND((COALESCE(s.vlvenda, s.vlbonific, 0) / s.qtvenda)::numeric, 2) ELSE 0 END
            )
        ) as itens
    FROM (
        SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, qtvenda, produto FROM data_history 
        UNION ALL 
        SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, qtvenda, produto FROM data_detailed
    ) s
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
