-- TABELA DE LOGS DE SINCRONIZAÇÃO
CREATE TABLE IF NOT EXISTS public.import_logs (
    id BIGSERIAL PRIMARY KEY,
    job_name TEXT NOT NULL,
    status TEXT NOT NULL,
    records_processed INT DEFAULT 0,
    error_message TEXT,
    data_execucao TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- TABELA PARA MIX IDEAL
CREATE TABLE IF NOT EXISTS public.mix_ideal (
    id BIGSERIAL PRIMARY KEY,
    cod_categoria TEXT NOT NULL,
    nome_categoria TEXT NOT NULL,
    produto_obrigatorio TEXT,
    ativo BOOLEAN DEFAULT TRUE,
    data_importacao TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- TABELA PARA INOVAÇÕES

-- TABELA DE CONFIGURAÇÃO DE REGRAS DE NEGÓCIO
CREATE TABLE IF NOT EXISTS public.config_comercial (
    parametro TEXT PRIMARY KEY,
    valor INT NOT NULL,
    descricao TEXT
);

-- INSERIR OS PARÂMETROS COMERCIAIS DEFAULT (REGRAS DO CLIENTE)
INSERT INTO public.config_comercial (parametro, valor, descricao) VALUES
('dias_cliente_ativo', 19, 'Até X dias, cliente está ativo (sem alerta)'),
('dias_atencao', 20, 'Até X dias, entrar em estado de atenção'),
('dias_risco_moderado', 30, 'A partir de X dias, risco moderado'),
('dias_risco_alto', 45, 'A partir de X dias, risco alto'),
('dias_critico', 60, 'A partir de X dias, cliente entra em estado crítico')
ON CONFLICT (parametro) DO UPDATE SET valor = EXCLUDED.valor, descricao = EXCLUDED.descricao;

-- FUNÇÃO UTILITÁRIA PARA LER O STATUS COMERCIAL BASEADO NA ULTIMA COMPRA
CREATE OR REPLACE FUNCTION public.get_status_recencia(p_ultima_compra TIMESTAMP WITH TIME ZONE)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public
SECURITY INVOKER
AS $$
DECLARE
    v_dias INT;
    v_ativo INT;
    v_atencao INT;
    v_risco_mod INT;
    v_risco_alto INT;
    v_critico INT;
BEGIN
    IF p_ultima_compra IS NULL THEN
        RETURN 'NUNCA COMPROU';
    END IF;

    -- Obter dias sem compra
    v_dias := EXTRACT(DAY FROM (NOW() - p_ultima_compra));

    -- Obter os parâmetros (se não existirem, usar fallbacks para não quebrar)
    SELECT COALESCE((SELECT valor FROM public.config_comercial WHERE parametro = 'dias_cliente_ativo'), 19) INTO v_ativo;
    SELECT COALESCE((SELECT valor FROM public.config_comercial WHERE parametro = 'dias_atencao'), 20) INTO v_atencao;
    SELECT COALESCE((SELECT valor FROM public.config_comercial WHERE parametro = 'dias_risco_moderado'), 30) INTO v_risco_mod;
    SELECT COALESCE((SELECT valor FROM public.config_comercial WHERE parametro = 'dias_risco_alto'), 45) INTO v_risco_alto;
    SELECT COALESCE((SELECT valor FROM public.config_comercial WHERE parametro = 'dias_critico'), 60) INTO v_critico;

    -- Aplicar a regra
    IF v_dias <= v_ativo THEN
        RETURN 'ATIVO';
    ELSIF v_dias >= v_atencao AND v_dias < v_risco_mod THEN
        RETURN 'ATENCAO';
    ELSIF v_dias >= v_risco_mod AND v_dias < v_risco_alto THEN
        RETURN 'RISCO MODERADO';
    ELSIF v_dias >= v_risco_alto AND v_dias < v_critico THEN
        RETURN 'RISCO ALTO';
    ELSE
        RETURN 'CRITICO';
    END IF;
END;
$$;
