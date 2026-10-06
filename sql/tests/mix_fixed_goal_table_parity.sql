-- Read-only parity checks against the table's per-seller Mix calculation.
WITH cases(label, mes, filial, fornecedor, supervisor, vendedor) AS (
    VALUES ('agosto',8,'Todas','Todos',NULL::text,NULL::text),
           ('setembro',9,'Todas','Todos',NULL::text,NULL::text),
           ('supervisor',8,'Todas','Todos','12',NULL::text),
           ('vendedor',8,'Todas','Todos',NULL::text,'284'),
           ('filial',8,'05','Todos',NULL::text,NULL::text),
           ('foods',8,'Todas','1119',NULL::text,NULL::text)
), results AS MATERIALIZED (
    SELECT c.*,
        public.get_metas_anuais_chart(2026,supervisor,vendedor,mes,'Todos',filial,fornecedor) chart,
        public.get_metas_base_comparativo_filtered(2026,mes,filial,fornecedor,supervisor,vendedor,'Todos') base
    FROM cases c
), totals AS (
    SELECT r.label,r.mes,r.chart,
        COALESCE(SUM(FLOOR(COALESCE(m.valor_ajuste,(s.value->>'sum_mix_foods')::numeric/3,0)+0.5)),0) expected
    FROM results r
    LEFT JOIN LATERAL jsonb_array_elements(r.base->'sellers') s(value) ON true
    LEFT JOIN public.metas_sv m ON m.ano=2026 AND m.mes=r.mes
        AND m.categoria='mix_foods' AND m.metrica='MIX'
        AND r.fornecedor='Todos'
        AND UPPER(TRIM(m.vendedor_nome))=UPPER(TRIM(s.value->>'vendedor_nome'))
    GROUP BY r.label,r.mes,r.chart
)
SELECT label, expected AS tabela, (p.value->>'kpi_meta_fixa_foods')::numeric AS grafico,
       expected=(p.value->>'kpi_meta_fixa_foods')::numeric AS passou
FROM totals t, LATERAL jsonb_array_elements(t.chart->'chart_data') p(value)
WHERE (p.value->>'mes')::integer=t.mes;
