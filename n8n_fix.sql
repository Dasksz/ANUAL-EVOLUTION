CREATE OR REPLACE FUNCTION public.sp_clientes_sem_venda_rca(p_rca text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_sem_venda JSONB;
    v_texto_pronto TEXT;
    v_lista_clientes TEXT := '';
BEGIN
    WITH ultimas_compras AS (
        SELECT codcli, MAX(dtped) as ultima_compra
        FROM (
            SELECT codcli, dtped FROM data_history WHERE codusur = p_rca
            UNION ALL
            SELECT codcli, dtped FROM data_detailed WHERE codsupervisor = p_rca OR codusur = p_rca
        ) s
        GROUP BY codcli
    ),
    clientes_rca AS (
        SELECT codigo_cliente, razaosocial, bairro, cidade
        FROM data_clients
        WHERE rca1 = p_rca
    )
    SELECT string_agg(
        '🔹 ' || c.codigo_cliente || ' - ' || COALESCE(c.razaosocial, '') || ' - ' || COALESCE(c.bairro, '') || ', ' || COALESCE(c.cidade, '') || ' - Última compra: ' || COALESCE(to_char(u.ultima_compra, 'DD/MM/YYYY'), 'Sem compra'),
        E'\n'
    ) INTO v_lista_clientes
    FROM clientes_rca c
    LEFT JOIN ultimas_compras u ON u.codcli = c.codigo_cliente
    WHERE u.ultima_compra IS NULL OR u.ultima_compra < date_trunc('month', CURRENT_DATE);

    IF v_lista_clientes IS NULL OR v_lista_clientes = '' THEN
        v_lista_clientes := 'Nenhum cliente sem venda encontrado para este RCA.';
    END IF;

    v_texto_pronto := 'Segue lista de clientes sem venda do RCA ' || p_rca || E'\n\n' ||
                      'Mês: ' || to_char(CURRENT_DATE, 'MM/YYYY') || E'\n\n' ||
                      v_lista_clientes;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_sem_venda;

    RETURN v_sem_venda;
END;
$function$;

CREATE OR REPLACE FUNCTION public.sp_mix_ideal_cliente(p_cod_cliente text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_mix JSONB;
    v_texto_pronto TEXT;
    v_garantidas TEXT := '';
    v_faltantes TEXT := '';
    v_cliente_fantasia TEXT := '';
    v_cliente_cidade TEXT := '';
    v_cliente_ramo TEXT := '';
BEGIN
    -- Obter os dados básicos do cliente. Usa '08' como fallback para o ramo se for nulo
    SELECT fantasia, cidade, COALESCE(ramo, '08') INTO v_cliente_fantasia, v_cliente_cidade, v_cliente_ramo
    FROM data_clients
    WHERE codigo_cliente = p_cod_cliente LIMIT 1;

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
        (SELECT string_agg(DISTINCT '- *' || nome_categoria || '*', E'\n') FROM cruzamento WHERE comprado_mes_atual = TRUE),
        (SELECT string_agg(
            CASE
                WHEN p.codigo IS NOT NULL AND p.estoque_filial_num > 0 THEN
                    '- *' || cruzamento.nome_categoria || ':* (Sugira *' || p.descricao || '* - Cód. ' || p.codigo || ')'
                ELSE NULL
            END, E'\n'
        )
        FROM cruzamento
        LEFT JOIN LATERAL (
            SELECT codigo, descricao,
                   COALESCE((estoque_filial->>v_cliente_ramo)::numeric, 0) as estoque_filial_num
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
    v_texto_pronto := 'Analisando o Mix Ideal do cliente *' || p_cod_cliente || '*:' || E'\n\n' ||
                      '🏢 *Cliente:* ' || COALESCE(v_cliente_fantasia, 'Não Encontrado') || E'\n' ||
                      '📍 *Localização:* ' || COALESCE(v_cliente_cidade, 'Não Encontrada') || E'\n\n' ||
                      '*Meta do Pedido:* 18 produtos diferentes no total.' || E'\n' ||
                      '*Regra de Ouro:* Ter pelo menos 1 produto de CADA categoria obrigatória.' || E'\n\n' ||
                      '*CATEGORIAS GARANTIDAS✅:*' || E'\n' ||
                      v_garantidas || E'\n\n' ||
                      '*OPORTUNIDADES DE MIX (Faltantes)🚨:*' || E'\n' ||
                      v_faltantes;

    SELECT jsonb_build_object(
        'texto_pronto_para_enviar', v_texto_pronto
    ) INTO v_mix;

    RETURN v_mix;
END;
$function$;
