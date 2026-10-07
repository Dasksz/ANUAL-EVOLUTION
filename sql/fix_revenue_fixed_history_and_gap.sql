-- Keep monthly fixed revenue goals independent of imported targets.
-- Estimated revenue redistributes the annual goal less closed-month actuals.
DO $migration$
DECLARE
    original text;
    revised text;
BEGIN
    SELECT pg_get_functiondef('public.get_metas_anuais_chart(integer,text,text,integer,text,text,text)'::regprocedure) INTO original;
    IF position($old_fixed$-- Meta Estimada Fixa: preserva a meta originalmente projetada do mês
            -- mesmo depois que o mês fecha. Só é exposta para meses fechados.
            CASE
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0
                    THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
                WHEN v_percentual IS NULL THEN NULL
                ELSE (t.total_fat * (1 + (v_percentual / 100.0))) * pm.peso_fat
            END as kpi_meta_fixa_fat,$old_fixed$ in original) = 0
       OR position($old_override$                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
$old_override$ in original) = 0 THEN
        RAISE EXCEPTION 'Unexpected annual chart definition; review before applying';
    END IF;
    revised := replace(original, $old_fixed$-- Meta Estimada Fixa: preserva a meta originalmente projetada do mês
            -- mesmo depois que o mês fecha. Só é exposta para meses fechados.
            CASE
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0
                    THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
                WHEN v_percentual IS NULL THEN NULL
                ELSE (t.total_fat * (1 + (v_percentual / 100.0))) * pm.peso_fat
            END as kpi_meta_fixa_fat,$old_fixed$, $new_fixed$-- Meta Fixa de faturamento: histórico mensal + crescimento, em todos os meses.
            CASE
                WHEN v_percentual IS NULL THEN NULL
                ELSE COALESCE(ra.real_fat_geral, 0) * (1 + (v_percentual / 100.0))
            END as kpi_meta_fixa_fat,$new_fixed$);
    revised := replace(revised, $old_override$                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
$old_override$, '');
    EXECUTE revised;
END;
$migration$;
