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
    WITH clientes_rca AS (
        SELECT codigo_cliente, razaosocial, bairro, cidade, ultimacompra
        FROM data_clients
        WHERE rca1 = p_rca
    )
    SELECT string_agg(
        '🔹 ' || c.codigo_cliente || ' - ' || COALESCE(c.razaosocial, '') || ' - ' || COALESCE(c.bairro, '') || ', ' || COALESCE(c.cidade, '') || ' - Última compra: ' || COALESCE(to_char(c.ultimacompra, 'DD/MM/YYYY'), 'Sem compra'),
        E'\n'
    ) INTO v_lista_clientes
    FROM clientes_rca c
    WHERE c.ultimacompra IS NULL OR c.ultimacompra < date_trunc('month', CURRENT_DATE);

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
