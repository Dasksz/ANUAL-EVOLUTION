# Foods completo no Planejamento

Aplicar `sql/planning_foods_four_brands.sql` em instalações existentes. A função de enriquecimento passa a exigir Quaker, Toddy, Toddynho e Kerococo, individualmente. O grupo comercial Quaker/Kerococo usado em outros painéis não substitui a presença das duas marcas neste critério.

O mix ideal completo exige as cinco marcas Salty e as quatro marcas Foods. O backend atualiza os indicadores, a contagem de marcas presentes/faltantes, a classificação e os metadados dos SKUs habituais e de segmento. A reconstrução após upload e o processamento agendado reutilizam a mesma função. A aplicação inicial reprocessa o planejamento já publicado sem consultar o Farol e troca atomicamente a versão da carteira para invalidar planos antigos.

O frontend usa o mesmo conjunto de nove marcas na lista, no plano de visita, nas sugestões de pedido e no PDF. Produtos de Quaker e Kerococo entram na etapa de completar o ideal quando houver evidência histórica ou indicação elegível do segmento; sem evidência, ficam explicitamente pendentes. Pedido sugerido não conta como compra realizada. A prioridade por Share, as quantidades históricas, o limite de profundidade e as regras de Salty permanecem inalterados.

Validação: `node --test tests/planning-order.test.mjs tests/planning.test.mjs` cobre as 16 combinações de Foods, classificação, etapas do pedido e exportação. `sql/tests/planning_order.sql` compara a carteira calculada com os nove indicadores de presença e valida a classificação/KPI e os metadados de Quaker/Kerococo. Também foi validada uma reconstrução completa com `private.planning_rebuild(false)` dentro de transação revertida.
