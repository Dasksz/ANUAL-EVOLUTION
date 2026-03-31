O problema relatado é que o "MIX PDV" (que dá 2.86) e o "SKU/PDV" (que dá 3.0) deveriam teoricamente bater com o mesmo valor ou ter lógicas consistentes quando os mesmos fornecedores são filtrados. Na imagem percebemos que o "MIX PDV" é um KPI de card e "SKU/PDV" é uma métrica da tabela de diretoria/frequência.

Para entender a discrepância, precisamos ver como cada um é calculado:
1. `MIX PDV` é calculado na função `get_main_dashboard_data` baseada na tabela `data_summary` (ou possivelmente no CTE `agg_data` onde faz `total_mix_sum / mix_client_count`).
2. `SKU/PDV` é calculado na função `get_frequency_table_data` baseada na tabela `data_summary_frequency` (onde fazemos a soma de distinct SKUs dividida pela positivação da tabela base).

Vamos inspecionar a agregação de `mix_pdv` em `get_main_dashboard_data` e a agregação de `sku_pdv` em `get_frequency_table_data`.
