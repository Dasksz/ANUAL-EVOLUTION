const fs = require('fs');

let fileContent = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

let originalEstq = `                (
                    SELECT SUM(COALESCE(sub_qtvenda, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1))
                    FROM (
                        SELECT qtvenda as sub_qtvenda FROM public.data_detailed sd WHERE sd.produto = (p->>'produto') AND sd.dtped >= (v_max_sale_date - interval '6 months')::date AND sd.dtped <= (v_max_sale_date)::date AND sd.tipovenda IN ('1', '9')
                        UNION ALL
                        SELECT qtvenda as sub_qtvenda FROM public.data_history sh WHERE sh.produto = (p->>'produto') AND sh.dtped >= (v_max_sale_date - interval '6 months')::date AND sh.dtped <= (v_max_sale_date)::date AND sh.tipovenda IN ('1', '9')
                    ) as hist
                ) as total_caixas_6m`;

let optimizedEstq = `                (
                    SELECT SUM(sub_qtvenda) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)
                    FROM (
                        SELECT SUM(qtvenda) as sub_qtvenda FROM public.data_detailed sd WHERE sd.produto = (p->>'produto') AND sd.dtped >= (v_max_sale_date - interval '6 months')::date AND sd.dtped <= (v_max_sale_date)::date AND sd.tipovenda IN ('1', '9')
                        UNION ALL
                        SELECT SUM(qtvenda) as sub_qtvenda FROM public.data_history sh WHERE sh.produto = (p->>'produto') AND sh.dtped >= (v_max_sale_date - interval '6 months')::date AND sh.dtped <= (v_max_sale_date)::date AND sh.tipovenda IN ('1', '9')
                    ) as hist
                ) as total_caixas_6m`;

fileContent = fileContent.replace(originalEstq, optimizedEstq);
fs.writeFileSync('sql/full_system_v1.sql', fileContent);
