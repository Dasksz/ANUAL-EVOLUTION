
-- Função para listar clientes de um RCA que não têm vendas no mês atual (para o Agente Elma)
CREATE OR REPLACE FUNCTION get_clientes_sem_vendas_por_rca(p_rca text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_vendedor_nome text;
    v_result json;
BEGIN
    -- Busca o nome do RCA
    SELECT nome INTO v_vendedor_nome
    FROM dim_vendedores
    WHERE codigo = p_rca
    LIMIT 1;

    -- Se não achar o RCA, retorna null ou uma mensagem
    IF v_vendedor_nome IS NULL THEN
        RETURN json_build_object(
            'erro', 'RCA não localizado.'
        );
    END IF;

    -- Monta o resultado
    SELECT json_build_object(
        'codigo_rca', p_rca,
        'nome_rca', v_vendedor_nome,
        'mes_atual', to_char(CURRENT_DATE, 'MM/YYYY'),
        'clientes', COALESCE(
            json_agg(
                json_build_object(
                    'codigo_cliente', c.codigo_cliente,
                    'razao_social', c.razaosocial,
                    'nome_fantasia', c.nomecliente,
                    'cidade', c.cidade,
                    'bairro', c.bairro,
                    'ultima_compra', to_char(c.ultimacompra, 'DD/MM/YYYY')
                ) ORDER BY c.cidade, c.bairro, c.razaosocial
            ),
            '[]'::json
        )
    ) INTO v_result
    FROM data_clients c
    WHERE c.rca1 = p_rca
      AND c.bloqueio ILIKE 'NÃO%'
      AND (c.ultimacompra IS NULL OR c.ultimacompra < date_trunc('month', CURRENT_DATE));

    RETURN v_result;
END;
$$;
