# Metas da planilha no dashboard

A planilha passa a ser a fonte das metas importadas. O Farol mantém seu orçamento independente.

## Importação

- O modelo tem 24 indicadores por entidade, incluindo auditoria PDEV.
- Ajuste preenchido tem prioridade, inclusive zero; ajuste vazio recorre à Meta/Volume. GERAL usa suas três metas diretamente.
- As linhas são identificadas por período, nível, código, categoria e métrica. Carteiras repetidas do vendedor são agregadas antes de salvar.
- O subtotal imediatamente seguinte identifica o supervisor das carteiras. A linha GV identifica a empresa.
- Cada importação substitui integralmente o período, em uma transação. Um arquivo incompleto não apaga as metas existentes.
- `private.metas_import_batches` conserva o conteúdo importado e sua versão. `private.metas_planilha` conserva códigos, hierarquia e células de origem. `public.metas_sv` mantém somente os vendedores para compatibilidade.
- PDEV é armazenado e excluído dos cálculos e da exibição dos indicadores.

## Leitura e rateio

Sem filtro de equipe, utiliza-se a meta explícita da empresa. Um supervisor completo utiliza sua própria linha; vendedores selecionados utilizam suas linhas. Esses níveis nunca são adicionados entre si. Importações antigas, ainda sem hierarquia, utilizam os registros de vendedores disponíveis.

O rateio usa os três meses anteriores. Faturamento e peso usam participação no respectivo valor. Positivação usa perfis de cliente/mês e distribui cotas inteiras pelo método dos maiores restos antes de aplicar os filtros. Seleções sobrepostas de categorias contam a mesma cota uma vez; filial e categoria precisam ocorrer na mesma compra. Cidade é uma partição exclusiva do perfil. O histórico é lido do cadastro comercial vigente, como os demais relatórios; alterações de cadastro ou histórico podem recalcular a distribuição.

Positivação permite um grupo de fornecedor por vez, ou o geral sem filtro de fornecedor. Quaker/Kerococo é um grupo comercial. Mix exige o conjunto completo de marcas; recortes incompatíveis não recebem uma meta de mix parcial.

O dashboard distingue meta importada e estimativa. A estimativa mantém a regra anual de crescimento existente nos meses abertos sem importação; recortes por cidade/rede sem base importada ficam sem linha estimada. Ausência de histórico para distribuir uma meta é exibida como lacuna, não como zero. Toneladas são convertidas de kg tanto no realizado quanto na meta.

## Verificação

- `node --test tests/*.cjs tests/*.mjs` cobre importação, hierarquia, zeros, séries e proteção contra respostas antigas, além das regressões existentes.
- `tests/dashboard-targets-rollback.sql` testa sobreposição, maiores restos, cruzamento filial/categoria, cidades, faturamento, elegibilidade de mix e restrição de fornecedores. Todos os dados de teste são revertidos.
- A planilha real de outubro foi validada em uma transação revertida: 528 registros de vendedores, 72 de supervisores e 24 da empresa. Faturamento geral 3.769.213,28; positivação 2.198; Salty 1.381; Foods 299; auditoria 1.686.
- O navegador foi testado com respostas controladas e metas consultadas do banco: três modos do gráfico, cinco séries de mix, leitura do Excel real, prévia de 624 registros e uma única chamada de gravação. A gravação do navegador foi simulada.

## Aplicação das alterações SQL

Ordem: `official_spreadsheet_targets.sql`, `dashboard_official_targets.sql`, `unify_official_goal_readers.sql`. Os arquivos registram o estado final das migrações aplicadas no projeto Evolution. Os leitores públicos exigem usuário aprovado; as tabelas internas não são expostas à API.

A reimportação definitiva de outubro fica a cargo do usuário.
