-- =========================================================================================
-- VIEW: n8n_agent_view (SUPER VIEW POR PEDIDO E ITENS)
-- DESCRIÇÃO: "Super View" para consulta do histórico de vendas pelo agente n8n.
-- Retorna uma linha para CADA PEDIDO realizado pelo cliente, detalhando os produtos em JSON,
-- além de trazer se o cliente bateu as metas de mix naquele mesmo mês.
-- =========================================================================================

-- IMPORTANTE: DROP necessário pois alteramos a estrutura das colunas em relação à versão anterior
DROP VIEW IF EXISTS public.n8n_agent_view CASCADE;

CREATE VIEW public.n8n_agent_view WITH (security_invoker = true) AS
WITH itens_brutos AS (
    -- Busca todos os itens, diferenciando vlvenda e vlbonific na origem bruta
    SELECT
        EXTRACT(YEAR FROM s.dtped)::int as ano,
        EXTRACT(MONTH FROM s.dtped)::int as mes,
        s.codcli,
        s.pedido,
        s.dtped::date as data_pedido,
        s.tipovenda,
        s.filial,
        s.codusur as vendedor_cod,
        s.codsupervisor as supervisor_cod,
        dp.descricao as produto,
        s.qtvenda as quantidade,
        -- Se for bonificação(11) ou perda(5), o valor na origem bruta está em vlbonific.
        -- Se for venda normal, usa vlvenda.
        CASE WHEN s.tipovenda IN ('5', '11') THEN s.vlbonific ELSE s.vlvenda END as valor_total_item,
        (CASE WHEN s.tipovenda IN ('5', '11') THEN s.vlbonific ELSE s.vlvenda END / NULLIF(s.qtvenda, 0)) as preco_unitario
    FROM public.data_detailed s
    LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    UNION ALL
    SELECT
        EXTRACT(YEAR FROM s.dtped)::int as ano,
        EXTRACT(MONTH FROM s.dtped)::int as mes,
        s.codcli,
        s.pedido,
        s.dtped::date as data_pedido,
        s.tipovenda,
        s.filial,
        s.codusur as vendedor_cod,
        s.codsupervisor as supervisor_cod,
        dp.descricao as produto,
        s.qtvenda as quantidade,
        CASE WHEN s.tipovenda IN ('5', '11') THEN s.vlbonific ELSE s.vlvenda END as valor_total_item,
        (CASE WHEN s.tipovenda IN ('5', '11') THEN s.vlbonific ELSE s.vlvenda END / NULLIF(s.qtvenda, 0)) as preco_unitario
    FROM public.data_history s
    LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
),
pedidos_agrupados AS (
    -- Agrupa os itens de forma que cada linha represente 1 PEDIDO único
    SELECT
        ano,
        mes,
        codcli,
        pedido,
        MAX(data_pedido) as data_do_pedido,
        MAX(tipovenda) as tipo_venda,
        MAX(filial) as filial_pedido,
        MAX(vendedor_cod) as vendedor_cod,
        MAX(supervisor_cod) as supervisor_cod,
        -- Soma o total do pedido
        SUM(valor_total_item) as valor_total_pedido,
        -- Monta a lista JSON apenas com os produtos Deste pedido
        jsonb_agg(
            jsonb_build_object(
                'produto', produto,
                'quantidade', quantidade,
                'valor_total_R$', valor_total_item,
                'preco_unitario_R$', ROUND(preco_unitario::numeric, 2)
            )
        ) as lista_itens_comprados
    FROM itens_brutos
    GROUP BY ano, mes, codcli, pedido
),
mix_mensal AS (
    -- Busca se no mês daquele pedido o cliente bateu a meta de mix (para referência da IA)
    SELECT
        codcli,
        ano,
        mes,
        MAX(CASE WHEN categorias ? 'CHEETOS' THEN 1 ELSE 0 END) as has_cheetos,
        MAX(CASE WHEN categorias ? 'DORITOS' THEN 1 ELSE 0 END) as has_doritos,
        MAX(CASE WHEN categorias ? 'FANDANGOS' THEN 1 ELSE 0 END) as has_fandangos,
        MAX(CASE WHEN categorias ? 'RUFFLES' THEN 1 ELSE 0 END) as has_ruffles,
        MAX(CASE WHEN categorias ? 'TORCIDA' THEN 1 ELSE 0 END) as has_torcida,
        MAX(CASE WHEN categorias ? 'TODDYNHO' THEN 1 ELSE 0 END) as has_toddynho,
        MAX(CASE WHEN categorias ? 'TODDY' THEN 1 ELSE 0 END) as has_toddy,
        MAX(CASE WHEN categorias ? 'QUAKER' THEN 1 ELSE 0 END) as has_quaker,
        MAX(CASE WHEN categorias ? 'KEROCOCO' THEN 1 ELSE 0 END) as has_kerococo
    FROM public.data_summary_frequency
    GROUP BY codcli, ano, mes
)
SELECT
    c.codigo_cliente,
    c.cnpj,
    c.razaosocial,
    c.fantasia,
    c.nomecliente as responsavel,
    c.cidade,
    c.bairro,
    c.ramo as rede_ou_ramo,
    c.bloqueio,
    c.ultimacompra,

    -- Dados Exatos do Pedido
    pa.pedido as numero_pedido,
    TO_CHAR(pa.data_do_pedido, 'DD/MM/YYYY') as data_pedido,
    pa.tipo_venda as tipo_venda_pedido,
    pa.valor_total_pedido,

    -- Indicadores de Mix (se naquele mês ele bateu a meta)
    CASE WHEN mm.has_cheetos=1 AND mm.has_doritos=1 AND mm.has_fandangos=1 AND mm.has_ruffles=1 AND mm.has_torcida=1 THEN 'SIM' ELSE 'NAO' END as mes_atingiu_mix_salty,
    CASE WHEN mm.has_toddynho=1 AND mm.has_toddy=1 AND mm.has_quaker=1 AND mm.has_kerococo=1 THEN 'SIM' ELSE 'NAO' END as mes_atingiu_mix_foods,

    -- Profissionais responsáveis por este pedido exato
    v.nome as vendedor_responsavel_pedido,
    s.nome as supervisor_responsavel_pedido,
    pa.filial_pedido as filial,

    -- Super Coluna JSON com os Produtos (Itens) exclusivos DESTE Pedido
    pa.lista_itens_comprados

FROM public.data_clients c
-- JOIN pelas vendas consolidadas por pedido. Um cliente terá várias linhas, uma para cada pedido que fez.
JOIN pedidos_agrupados pa ON c.codigo_cliente = pa.codcli
LEFT JOIN mix_mensal mm ON pa.codcli = mm.codcli AND pa.ano = mm.ano AND pa.mes = mm.mes
LEFT JOIN public.dim_vendedores v ON pa.vendedor_cod = v.codigo
LEFT JOIN public.dim_supervisores s ON pa.supervisor_cod = s.codigo;

GRANT SELECT ON public.n8n_agent_view TO authenticated, anon;
