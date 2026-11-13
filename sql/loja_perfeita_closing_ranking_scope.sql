-- Restrict the ranking population before aggregation and LIMIT, without changing the other cards.
DO $migration$
DECLARE
    fn regprocedure := 'public.get_loja_perfeita_closing_data(text[],text[],text[],text[],text[],text,integer,integer,text[],text[])'::regprocedure;
    def text := pg_get_functiondef(fn);
BEGIN
    IF strpos(def, 'ranking_scope_v1') > 0 THEN RETURN; END IF;
    IF md5(def) <> 'd1427fb5f342a160f48534b7c4eca4a3' THEN RAISE EXCEPTION 'Loja Perfeita closing reader changed'; END IF;
    def := replace(def, $old$                CASE WHEN rri.tipo = ''rca'' THEN rri.cod_system END as researcher_vendor_code,$old$, $new$                CASE WHEN rri.tipo = ''rca'' THEN rri.cod_system END as researcher_vendor_code,
                rri.tipo as researcher_role,$new$);
    def := replace(def, $old$            GROUP BY researcher, codcli
        ),
        researcher_ranking$old$, $new$              AND ( -- ranking_scope_v1
                   (coalesce(cardinality($4),0)=0 AND coalesce(cardinality($5),0)=0)
                   OR (coalesce(cardinality($5),0)>0 AND researcher_role=''promotor'')
                   OR (coalesce(cardinality($4),0)>0 AND researcher_role=''rca'' AND EXISTS (
                       SELECT 1 FROM private.current_seller_supervisors team
                       JOIN public.dim_supervisores supervisor_dim ON supervisor_dim.codigo=team.codsupervisor
                       WHERE team.codusur=ltrim(btrim(researcher_vendor_code),''0'')
                         AND supervisor_dim.nome=ANY($4)
                   ))
              )
            GROUP BY researcher, codcli
        ),
        researcher_ranking$new$);
    def := replace(def, 'USING p_ano, p_mes, v_coordinators;', 'USING p_ano, p_mes, v_coordinators, p_supervisor, p_coordenador;');
    IF strpos(def, 'ranking_scope_v1') = 0 OR strpos(def,'rri.tipo as researcher_role')=0 OR strpos(def,'v_coordinators, p_supervisor, p_coordenador;')=0 THEN
      RAISE EXCEPTION 'Ranking scope patch did not apply';
    END IF;
    EXECUTE def;
END
$migration$;
