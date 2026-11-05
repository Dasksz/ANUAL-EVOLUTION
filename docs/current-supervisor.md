# Atribuição histórica ao supervisor atual

A importação combina os arquivos fornecidos antes de reatribuir as vendas. O cadastro atual identifica o vendedor do cliente; a evidência de venda com data mais recente identifica o supervisor desse vendedor. Reimportar um arquivo antigo não torna sua supervisão antiga a atual. A regra especial do vendedor 190 continua em vigor no importador.

BH, Balcão e Americanas conservam suas regras específicas. Clientes sem cadastro, sem RCA, com RCA 53 fora das exceções ou com identificação de inativos seguem a lógica existente de inativos por cidades do último vendedor e predominância atual. Sem evidência de supervisor, o resultado é SEM_SUPERVISOR, sem herdar o código histórico da venda.

`sql/dynamic_current_supervisor.sql` separa as views de evidência das views de leitura, evitando resolver a supervisão usando o próprio resultado já reatribuído. O mapa privado é atualizado automaticamente por `refresh_cache_filters`, chamado nas tarefas de resumo após cada importação. As views de detalhe, histórico, resumo, frequência e metas leem esse mesmo mapa. Uma mudança no mapa reconstrói os filtros de todos os períodos, mesmo quando o refresh foi solicitado para apenas um mês. O cadastro de clientes continua determinando o vendedor nas leituras.

Os arquivos originais e os valores das vendas não são modificados por essa projeção. Dados sem evidência suficiente não são apresentados como supervisão atual confirmada. O teste `sql/tests/current_supervisor_rollback.sql` verifica atualização do mapa, filtros históricos e conservação de contagens, faturamento e peso. Os testes do importador cobrem múltiplos arquivos, troca de carteira e inativos sem supervisão.
