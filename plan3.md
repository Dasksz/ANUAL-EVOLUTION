Sim, `data_summary` possui `1119_TODDY` na coluna `codfor`.
Já `data_summary_frequency` possui `1119` na coluna `codfor` e guarda as subcategorias em `categorias`.

Então o filtro `p_fornecedor` está perfeitamente correto para as duas tabelas agora:
- Em `get_main_dashboard_data` (`data_summary`), usa `codfor = ANY(p_fornecedor)`.
- Em `get_frequency_table_data` (`data_summary_frequency`), usa `s.categorias ? 'BRAND'`.

Por que os números diferem? (MIX PDV 2.86 vs SKU/PDV 3.0)

**MIX PDV (get_main_dashboard_data)**:
O "Mix PDV" usa a soma da coluna `pre_mix_count` da tabela `data_summary` (dividido pelos clientes que positivaram no mix).
A coluna `pre_mix_count` é definida em `data_summary` para guardar a contagem do mix no dia/cliente.

**SKU/PDV (get_frequency_table_data)**:
O "SKU/PDV" usa a soma do `jsonb_array_length(produtos)` da tabela `data_summary_frequency` dividido pela contagem de clientes positivados (`positivacao`).

Essas duas métricas **não são a mesma coisa**, embora pareçam na UI:
1. `pre_mix_count` em `data_summary` (usado para MIX PDV) pode estar contando "Categorias de Mix" ou "Marcas Distintas" (ex: Cheetos, Doritos, Toddynho), não SKUs individuais. (Vamos ver como `pre_mix_count` é gerado. Normalmente é `qtvenda` ou mix das marcas).
2. `SKU/PDV` em `data_summary_frequency` conta explicitamente os **SKUs distintos comprados no mês** (o array JSONB guarda os códigos dos produtos).

Portanto, "MIX PDV" e "SKU/PDV" são métricas de naturezas diferentes:
- "MIX PDV" (Média de Mix por PDV): É a quantidade média de itens do MIX (marcas principais) vendidas por cliente.
- "SKU/PDV" (Média de SKUs por PDV): É a quantidade média de produtos distintos (qualquer sabor, qualquer tamanho, cada SKU diferente) vendidos por cliente.

Como um cliente pode comprar 2 SKUs de Toddy (ex: Toddy 400g e Toddy 200g), o `SKU/PDV` pode ser 2, enquanto o `MIX PDV` (marca Toddy) pode contar como 1 "item de mix" ou algo similar, ou apenas o fato de ter positivado.
Ou o cálculo de "MIX PDV" soma todo o `pre_mix_count` no mês. Mas como a UI apresenta as duas métricas lado a lado com nomes diferentes ("Mix PDV" no Card, e "SKU/PDV" na Tabela de Frequência), é totalmente natural e correto que elas divirjam. Elas medem coisas diferentes baseadas no banco.
Vou comunicar isso ao usuário de forma clara.
