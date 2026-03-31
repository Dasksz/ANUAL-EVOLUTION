-- =========================================================================================
-- VIEW: n8n_agent_view
-- DESCRIÇÃO: "Super View" para consulta direta pelo agente n8n.
-- Combina dados cadastrais (data_clients), informações do último vendedor/supervisor
-- e um resumo rápido das compras recentes.
-- =========================================================================================
CREATE OR REPLACE VIEW public.n8n_agent_view AS
WITH ultimas_vendas AS (
    -- Pega apenas a venda mais recente de cada cliente para identificar o vendedor/supervisor atual
    SELECT
        codcli,
        codusur,
        codsupervisor,
        filial,
        ROW_NUMBER() OVER(PARTITION BY codcli ORDER BY ano DESC, mes DESC, created_at DESC) as rn
    FROM public.data_summary_frequency
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
    v.nome as vendedor_atual,
    s.nome as supervisor_atual,
    uv.filial
FROM public.data_clients c
LEFT JOIN ultimas_vendas uv ON c.codigo_cliente = uv.codcli AND uv.rn = 1
LEFT JOIN public.dim_vendedores v ON uv.codusur = v.codigo
LEFT JOIN public.dim_supervisores s ON uv.codsupervisor = s.codigo;

-- Configura permissões para garantir que o agente (via API anônima ou autenticada) consiga ler
GRANT SELECT ON public.n8n_agent_view TO authenticated, anon;
