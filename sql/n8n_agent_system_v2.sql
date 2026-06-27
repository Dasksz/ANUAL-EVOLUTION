CREATE OR REPLACE FUNCTION public.sp_mix_ideal_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_mix JSONB;
    v_texto_pronto TEXT;
    v_garantidas TEXT := '';
    v_faltantes TEXT := '';
    v_cliente_fantasia TEXT := '';
    v_cliente_cidade TEXT := '';
    v_cliente_bairro TEXT := '';
    v_cliente_filial TEXT := '';
BEGIN
    -- Obter os dados básicos do cliente
    SELECT c.fantasia, c.cidade, c.bairro, b.filial INTO v_cliente_fantasia, v_cliente_cidade, v_cliente_bairro, v_cliente_filial
    FROM data_clients c
    LEFT JOIN config_city_branches b ON c.cidade = b.cidade
    WHERE c.codigo_cliente = p_cod_cliente LIMIT 1;

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
    SELECT 
        (SELECT string_agg(DISTINCT '*' || nome_categoria || '*', ', ') FROM cruzamento WHERE comprado_mes_atual = TRUE),
        (SELECT string_agg(
            CASE 
                WHEN p.codigo IS NOT NULL AND p.estoque_filial_num > 0 THEN 
                    '- ' || p.codigo || ' - ' || p.descricao
                ELSE NULL 
            END, E'\n'
        ) 
        FROM cruzamento 
        LEFT JOIN LATERAL (
            SELECT codigo, descricao, 
                   COALESCE((estoque_filial->>v_cliente_filial)::numeric, 0) as estoque_filial_num
            FROM public.dim_produtos dp
            WHERE dp.mix_marca ILIKE '%' || cruzamento.nome_categoria || '%' 
              AND (cruzamento.produto_obrigatorio IS NULL OR cruzamento.produto_obrigatorio = '' OR dp.codigo = cruzamento.produto_obrigatorio)
            ORDER BY dp.codigo
            LIMIT 1
        ) p ON true
        WHERE comprado_mes_atual = FALSE AND (p.codigo IS NOT NULL AND p.estoque_filial_num > 0))
    INTO v_garantidas, v_faltantes;

    -- Se não houver nada, setar um fallback amigável
    IF v_garantidas IS NULL OR v_garantidas = '' THEN
        v_garantidas := 'Nenhuma categoria garantida ainda neste mês. O cliente precisa construir o mix!';
    END IF;

    IF v_faltantes IS NULL OR v_faltantes = '' THEN
        v_faltantes := 'Sem produtos obrigatórios com estoque disponível no momento ou o Mix já está 100%!';
    END IF;

    -- Construção manual do Layout para poupar tokens do Agente
    v_texto_pronto := 'Analisando o Mix Ideal do cliente ' || p_cod_cliente || ':' || E'\n\n' ||
                      '🏢 Cliente: ' || COALESCE(v_cliente_fantasia, 'Não Encontrado') || ' 📍 ' || E'\n\n' ||
                      'Localização: ' || COALESCE(v_cliente_cidade, 'Não Encontrada') || ', ' || COALESCE(v_cliente_bairro, '') || '.' || E'\n\n' ||
                      'Meta do Pedido: 18 produtos diferentes no total.' || E'\n\n' ||
                      'Regra de Ouro: Ter pelo menos 1 produto de CADA categoria obrigatória.' || E'\n\n' ||
                      'CATEGORIAS GARANTIDAS✅: ' || v_garantidas || E'\n\n' ||
                      'OPORTUNIDADES DE MIX (Faltantes)🚨: ' || E'\n\n' ||
                      'Sugestões de compra' || E'\n\n' ||
                      v_faltantes || E'\n\n\n' ||
                      '"Posso te ajudar em algo mais? Se desejar ver a lista de opções novamente digite ""Menu""."';

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_mix;

    RETURN v_mix;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_inovacoes_cliente(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_inovacoes JSONB;
    v_texto_pronto TEXT;
    v_positivadas TEXT := '';
    v_sugestoes TEXT := '';
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
    SELECT 
        (SELECT string_agg(DISTINCT '- *' || categoria_inovacao || '* - ' || cod_produto || ' - ' || nome_produto, E'\n') FROM cruzamento WHERE comprado_mes_atual = TRUE),
        (SELECT string_agg(DISTINCT '- *' || categoria_inovacao || ':* Sugira o produto ' || nome_produto || ' (Cód. ' || cod_produto || '). Cliente ainda não comprou esta inovação no mês atual.', E'\n') FROM (SELECT * FROM cruzamento WHERE comprado_mes_atual = FALSE LIMIT 9) t)
    INTO v_positivadas, v_sugestoes;

    IF v_positivadas IS NULL OR v_positivadas = '' THEN
        v_positivadas := 'Nenhuma inovação positivada ainda neste mês.';
    END IF;

    IF v_sugestoes IS NULL OR v_sugestoes = '' THEN
        v_sugestoes := 'Nenhuma sugestão de inovação restante ou falta de estoque.';
    END IF;

    v_texto_pronto := 'Analisando a situação de inovações do cliente *' || p_cod_cliente || '* no mês atual, temos:' || E'\n\n' ||
                      '*CATEGORIAS POSITIVADAS✅:*' || E'\n' ||
                      v_positivadas || E'\n\n' ||
                      '*OPORTUNIDADES✨:*' || E'\n' ||
                      'Baseado no histórico do cliente, estas são as sugestões mais certeiras🎯' || E'\n' ||
                      v_sugestoes || E'\n\n' ||
                      '*Dica de Venda:* Aumentar inovações garante exclusividade e diferenciação do PDV frente aos concorrentes!';

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_inovacoes;

    RETURN v_inovacoes;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_cliente_cadastro(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_cadastro JSONB;
    v_texto_pronto TEXT;
    v_fantasia TEXT;
    v_razaosocial TEXT;
    v_cnpj TEXT;
    v_bairro TEXT;
    v_cidade TEXT;
    v_ramo TEXT;
    v_bloqueio TEXT;
BEGIN
    SELECT fantasia, razaosocial, cnpj, bairro, cidade, ramo, bloqueio 
    INTO v_fantasia, v_razaosocial, v_cnpj, v_bairro, v_cidade, v_ramo, v_bloqueio
    FROM data_clients 
    WHERE codigo_cliente = p_cod_cliente LIMIT 1;

    IF v_fantasia IS NULL THEN
        v_texto_pronto := 'Cliente não encontrado.';
    ELSE
        v_texto_pronto := 'Cadastro localizado! ✅' || E'\n\n' ||
                          'Razão social: ' || COALESCE(v_razaosocial, '') || E'\n' ||
                          'Fantasia: ' || COALESCE(v_fantasia, '') || E'\n' ||
                          'CNPJ/CPF: ' || COALESCE(v_cnpj, '') || E'\n' ||
                          'Código do Cliente: ' || p_cod_cliente || E'\n' ||
                          'Bairro: ' || COALESCE(v_bairro, '') || E'\n' ||
                          'Cidade: ' || COALESCE(v_cidade, '') || E'\n' ||
                          'Filial: ' || COALESCE(v_ramo, '') || E'\n' ||
                          'Bloqueio Sefaz: ' || COALESCE(v_bloqueio, '');
    END IF;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_cadastro;

    RETURN v_cadastro;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_historico_pedidos(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_historico JSONB;
    v_texto_pronto TEXT;
    v_pedidos TEXT := '';
    v_fantasia TEXT;
    v_cidade TEXT;
    v_bairro TEXT;
    v_bloqueio TEXT;
BEGIN
    SELECT fantasia, cidade, bairro, bloqueio 
    INTO v_fantasia, v_cidade, v_bairro, v_bloqueio
    FROM data_clients 
    WHERE codigo_cliente = p_cod_cliente LIMIT 1;

    WITH ultimos_pedidos AS (
        SELECT 
            s.pedido,
            MAX(s.dtped) as data_pedido,
            SUM(COALESCE(s.vlvenda, s.vlbonific, 0)) as valor_total,
            MAX(s.tipovenda) as tipo_venda,
            COUNT(s.produto) as contagem_itens,
            bool_or(dp.mix_categoria = 'SALTY') as has_salty,
            bool_or(dp.mix_categoria = 'FOODS') as has_foods
        FROM (
            SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, produto FROM data_history WHERE codcli = p_cod_cliente
            UNION ALL 
            SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, produto FROM data_detailed WHERE codcli = p_cod_cliente
        ) s
        LEFT JOIN dim_produtos dp ON dp.codigo = s.produto
        GROUP BY s.pedido
        ORDER BY MAX(s.dtped) DESC
        LIMIT 5
    )
    SELECT string_agg(
        '📦 Pedido Analisado: Data: ' || to_char(data_pedido, 'DD/MM/YYYY') || E'\n' ||
        'Pedido: ' || pedido || E'\n' ||
        'Valor: R$ ' || round(valor_total, 2) || E'\n' ||
        'Mix: ' || contagem_itens || E'\n' ||
        'Tipo: ' || tipo_venda || ' 11=Bonif / 5=Perda' || E'\n' ||
        'Salty: ' || CASE WHEN has_salty THEN 'SIM' ELSE 'NAO' END || ' | Foods: ' || CASE WHEN has_foods THEN 'SIM' ELSE 'NAO' END,
        E'\n\n'
    ) INTO v_pedidos
    FROM ultimos_pedidos;

    IF v_pedidos IS NULL OR v_pedidos = '' THEN
        v_pedidos := 'Nenhum pedido encontrado no histórico recente.';
    END IF;

    v_texto_pronto := '🏢 Cliente: ' || COALESCE(v_fantasia, 'Não Encontrado') || E'\n' ||
                      '📍 Localização: ' || COALESCE(v_bairro, '') || ', ' || COALESCE(v_cidade, '') || E'\n' ||
                      '🚦 Bloqueio Sefaz: ' || COALESCE(v_bloqueio, '') || E'\n\n' ||
                      v_pedidos;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_historico;

    RETURN v_historico;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_consultar_pedido(p_num_pedido TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_pedido_detalhe JSONB;
    v_texto_pronto TEXT;
    v_itens TEXT := '';
BEGIN
    WITH itens_pedido AS (
        SELECT 
            s.qtvenda,
            COALESCE(dp.descricao, s.produto) as nome_produto,
            CASE WHEN s.qtvenda > 0 THEN ROUND((COALESCE(s.vlvenda, s.vlbonific, 0) / s.qtvenda)::numeric, 2) ELSE 0 END as preco_unitario
        FROM (
            SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, qtvenda, produto FROM data_history WHERE pedido = p_num_pedido
            UNION ALL 
            SELECT pedido, codcli, tipovenda, dtped, vlvenda, vlbonific, qtvenda, produto FROM data_detailed WHERE pedido = p_num_pedido
        ) s
        LEFT JOIN dim_produtos dp ON dp.codigo = s.produto
    )
    SELECT string_agg(
        '🔹 ' || qtvenda || ' x ' || nome_produto || ' un R$ ' || preco_unitario || '.',
        E'\n'
    ) INTO v_itens
    FROM itens_pedido;

    IF v_itens IS NULL OR v_itens = '' THEN
        v_texto_pronto := 'Pedido ' || p_num_pedido || ' não encontrado.';
    ELSE
        v_texto_pronto := '🛒 Itens Comprados no Pedido ' || p_num_pedido || ':' || E'\n\n' || v_itens;
    END IF;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_pedido_detalhe;

    RETURN v_pedido_detalhe;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_consultar_estoque(p_codigo_produto TEXT, p_filial TEXT DEFAULT '01')
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_estoque_json JSONB;
    v_texto_pronto TEXT;
    v_nome TEXT;
    v_estoque_qtd NUMERIC;
BEGIN
    SELECT descricao, COALESCE((estoque_filial->>p_filial)::numeric, 0)
    INTO v_nome, v_estoque_qtd
    FROM dim_produtos
    WHERE codigo = p_codigo_produto;

    IF v_nome IS NULL THEN
        v_texto_pronto := 'Produto não encontrado.';
    ELSE
        v_texto_pronto := '📦 *Consulta de Estoque*' || E'\n' ||
                          '*Produto:* ' || v_nome || ' (' || p_codigo_produto || ')' || E'\n' ||
                          '*Filial Consultada:* ' || p_filial || E'\n' ||
                          '*Estoque Disponível:* ' || v_estoque_qtd || ' Cx.';
    END IF;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_estoque_json;

    RETURN v_estoque_json;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_clientes_sem_venda_rca(p_rca TEXT, p_cidade TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_sem_venda JSONB;
    v_texto_pronto TEXT;
    v_lista_clientes TEXT := '';
BEGIN
    SELECT string_agg(
        '🔹 ' || codigo_cliente || ' - ' || COALESCE(razaosocial, '') || ' - ' || COALESCE(bairro, '') || ', ' || COALESCE(cidade, '') || ' - Última compra: ' || COALESCE(to_char(ultimacompra, 'DD/MM/YYYY'), 'Sem compra'),
        E'\n'
    ) INTO v_lista_clientes
    FROM data_clients
    WHERE rca1 = p_rca 
      AND unaccent(cidade) ILIKE unaccent('%' || p_cidade || '%')
      AND (ultimacompra IS NULL OR ultimacompra < date_trunc('month', CURRENT_DATE));

    IF v_lista_clientes IS NULL OR v_lista_clientes = '' THEN
        v_lista_clientes := 'Nenhum cliente sem venda encontrado para este RCA na cidade informada (' || p_cidade || '). Verifique a grafia da cidade e tente novamente.';
    END IF;

    v_texto_pronto := '📋 Segue lista de clientes sem venda do RCA ' || p_rca || ' em ' || p_cidade || E'\n\n' ||
                      'Mês: ' || to_char(CURRENT_DATE, 'MM/YYYY') || E'\n\n' ||
                      v_lista_clientes;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_sem_venda;

    RETURN v_sem_venda;
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_sugestao_pedido(p_cod_cliente TEXT)
RETURNS JSONB
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_sugestao JSONB;
    v_texto_pronto TEXT;
    v_media NUMERIC;
    v_cobertura TEXT := '';
    v_inovacoes TEXT := '';
    v_mix_ideal TEXT := '';
    v_dica TEXT := '';
    v_cliente_filial TEXT := '';
BEGIN
    -- Determinar filial do cliente
    SELECT b.filial INTO v_cliente_filial
    FROM data_clients c
    LEFT JOIN config_city_branches b ON c.cidade = b.cidade
    WHERE c.codigo_cliente = p_cod_cliente LIMIT 1;

    SELECT COALESCE(AVG(vlvenda), 0) INTO v_media FROM data_history WHERE codcli = p_cod_cliente;

    WITH produtos_comprados_sempre AS (
        SELECT DISTINCT p.codigo, p.descricao as nome
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente 
          AND s.tipovenda IN ('1','9')
    ),
    produtos_comprados_mes_atual AS (
        SELECT DISTINCT s.produto as codigo
        FROM public.data_detailed s
        WHERE s.codcli = p_cod_cliente 
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    cobertura_sugestao AS (
        -- Todos os que ele já comprou na vida, mas que TEM estoque > 1 e NÃO comprou no mês atual
        SELECT p.codigo, p.nome
        FROM produtos_comprados_sempre p
        JOIN public.dim_produtos dp ON dp.codigo = p.codigo
        WHERE p.codigo NOT IN (SELECT codigo FROM produtos_comprados_mes_atual)
          AND COALESCE((dp.estoque_filial->>v_cliente_filial)::numeric, 0) > 1
    ),
    inovacoes_ativas AS (
        SELECT i.codigo as cod_produto, p.descricao as nome_produto,
               COALESCE((p.estoque_filial->>v_cliente_filial)::numeric, 0) as estoque
        FROM public.data_innovations i
        JOIN public.dim_produtos p ON p.codigo = i.codigo
    ),
    inovacoes_sugestao AS (
        SELECT cod_produto, nome_produto
        FROM inovacoes_ativas
        WHERE cod_produto NOT IN (SELECT codigo FROM produtos_comprados_mes_atual)
          AND estoque > 1
        ORDER BY estoque DESC
        LIMIT 3
    ),
    categorias_obrigatorias AS (
        SELECT DISTINCT nome_categoria
        FROM public.mix_ideal
        WHERE ativo = TRUE
    ),
    historico_cliente_mes_atual_mix AS (
        SELECT DISTINCT p.mix_marca as marca_comprada
        FROM public.data_detailed s
        JOIN public.dim_produtos p ON p.codigo = s.produto
        WHERE s.codcli = p_cod_cliente
          AND s.dtped >= date_trunc('month', CURRENT_DATE)
          AND s.tipovenda IN ('1','9')
    ),
    categorias_faltantes AS (
        SELECT co.nome_categoria
        FROM categorias_obrigatorias co
        LEFT JOIN historico_cliente_mes_atual_mix hc ON hc.marca_comprada ILIKE '%' || co.nome_categoria || '%'
        WHERE hc.marca_comprada IS NULL
    ),
    mix_ideal_sugestao_base AS (
        -- Pegar produtos do mix ideal, de categorias faltantes, com estoque > 1 e que não estejam nas outras sugestões
        SELECT DISTINCT ON (cf.nome_categoria) dp.codigo, dp.descricao as nome, COALESCE((dp.estoque_filial->>v_cliente_filial)::numeric, 0) as estoque
        FROM public.dim_produtos dp
        JOIN categorias_faltantes cf ON dp.mix_marca ILIKE '%' || cf.nome_categoria || '%'
        WHERE COALESCE((dp.estoque_filial->>v_cliente_filial)::numeric, 0) > 1
          AND dp.codigo NOT IN (SELECT codigo FROM cobertura_sugestao)
          AND dp.codigo NOT IN (SELECT cod_produto FROM inovacoes_sugestao)
          AND dp.codigo NOT IN (SELECT codigo FROM produtos_comprados_mes_atual)
        ORDER BY cf.nome_categoria, COALESCE((dp.estoque_filial->>v_cliente_filial)::numeric, 0) DESC
    ),
    mix_ideal_sugestao AS (
        SELECT codigo, nome, estoque FROM mix_ideal_sugestao_base
        GROUP BY codigo, nome, estoque
        ORDER BY estoque DESC
        LIMIT 3
    )
    SELECT 
        (SELECT string_agg('🔹 ' || codigo || ' - ' || nome, E'\n') FROM cobertura_sugestao),
        (SELECT string_agg('🔹 ' || cod_produto || ' - ' || nome_produto, E'\n') FROM inovacoes_sugestao),
        (SELECT string_agg('🔹 ' || codigo || ' - ' || nome, E'\n') FROM mix_ideal_sugestao)
    INTO v_cobertura, v_inovacoes, v_mix_ideal;

    IF v_media < 1500 THEN
        v_dica := 'Ofereça as opções de cobertura de Mix que ele já levou meses anteriores em pacotes menores para garantir giro!';
    ELSE
        v_dica := 'O cliente tem bom potencial e faltam poucas categorias para o Mix Ideal. Insira as Inovações junto!';
    END IF;

    IF (v_cobertura IS NULL OR v_cobertura = '') AND
       (v_inovacoes IS NULL OR v_inovacoes = '') AND
       (v_mix_ideal IS NULL OR v_mix_ideal = '') THEN
         v_texto_pronto := 'Realizei a consulta de *Sugestão de Pedido* para o cliente de código *' || p_cod_cliente || '*, mas não foram encontrados dados disponíveis no momento.' || E'\n\n' ||
                           'Isso pode ocorrer porque:' || E'\n' ||
                           '・ O cliente não possui um histórico de compras recente suficiente para gerar uma sugestão;' || E'\n' ||
                           '・ O código do cliente pode estar incorreto.' || E'\n\n' ||
                           'Deseja que eu verifique o *cadastro* ou o *histórico de pedidos* desse cliente para ajudar? Ou posso te auxiliar com algo mais?';
    ELSE
        IF v_cobertura IS NULL OR v_cobertura = '' THEN
             v_cobertura := 'Nenhuma sugestão de cobertura encontrada.';
        END IF;

        IF v_inovacoes IS NULL OR v_inovacoes = '' THEN
             v_inovacoes := 'Nenhuma sugestão de inovações encontrada.';
        END IF;

        IF v_mix_ideal IS NULL OR v_mix_ideal = '' THEN
             v_mix_ideal := 'Nenhum produto de Mix Ideal pendente com estoque encontrado.';
        END IF;

        v_texto_pronto := '💡 *Sugestão de Pedido para o cliente ' || p_cod_cliente || '*:' || E'\n\n' ||
                          '*Sugestões de Cobertura de Mix:*' || E'\n' ||
                          v_cobertura || E'\n\n' ||
                          '*Sugestões de Inovações:*' || E'\n' ||
                          v_inovacoes || E'\n\n' ||
                          '*Sugestões de Mix Ideal:*' || E'\n' ||
                          v_mix_ideal || E'\n\n' ||
                          '*Dica de Venda:* ' || v_dica || E'\n\n\n' ||
                          'Posso te ajudar em algo mais? Se desejar ver a lista de opções novamente digite "Menu".';
    END IF;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_sugestao;

    RETURN v_sugestao;
END;
$$;


DROP VIEW IF EXISTS public.n8n_agent_view_v2;
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
       NULL::text AS rca,
       NULL::text AS filial,
       public.sp_cliente_cadastro(c.codigo_cliente) AS dados
FROM data_clients c

UNION ALL

SELECT '2'::text AS opcao,
       NULL::text AS cpf,
       v.codcli AS codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       NULL::text AS rca,
       NULL::text AS filial,
       public.sp_historico_pedidos(v.codcli) AS dados
FROM (
    SELECT DISTINCT codcli FROM data_detailed
    UNION
    SELECT DISTINCT codcli FROM data_history
) v

UNION ALL

SELECT '3'::text AS opcao,
       NULL::text AS cpf,
       NULL::text AS codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       v.pedido AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       NULL::text AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       NULL::text AS rca,
       NULL::text AS filial,
       public.sp_consultar_pedido(v.pedido) AS dados
FROM (
    SELECT DISTINCT pedido FROM data_detailed
    UNION
    SELECT DISTINCT pedido FROM data_history
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
       NULL::text AS rca,
       NULL::text AS filial,
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
       NULL::text AS rca,
       NULL::text AS filial,
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
       NULL::text AS rca,
       NULL::text AS filial,
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
       NULL::text AS rca,
       f.key AS filial,
       public.sp_consultar_estoque(dp.codigo, f.key) AS dados
FROM dim_produtos dp
CROSS JOIN LATERAL jsonb_each_text(dp.estoque_filial) f

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
       NULL::text AS rca,
       NULL::text AS filial,
       jsonb_build_object('mensagem', 'Atendimento será transferido para Suporte', 'setor', 'Suporte') AS dados

UNION ALL

SELECT '10'::text AS opcao,
       NULL::text AS cpf,
       NULL::text AS codigo_cliente,
       NULL::text AS setor_transferencia,
       NULL::text AS tipo_venda_pedido,
       NULL::text AS numero_pedido,
       NULL::text AS data_inicio,
       NULL::text AS data_fim,
       NULL::text AS lista_produtos,
       ci.cidade AS cidade,
       NULL::text AS codigo_produto,
       NULL::text AS termo_busca,
       c.rca AS rca,
       NULL::text AS filial,
       public.sp_clientes_sem_venda_rca(c.rca, ci.cidade) AS dados
FROM (SELECT DISTINCT rca1 as rca FROM data_clients WHERE rca1 IS NOT NULL) c
CROSS JOIN (SELECT DISTINCT cidade FROM data_clients WHERE cidade IS NOT NULL) ci;

GRANT SELECT ON public.n8n_agent_view_v2 TO service_role;
