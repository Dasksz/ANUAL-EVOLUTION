# Metas históricas por carteira atual

O arquivo importado permanece como fonte dos valores de cada mês. A leitura dos vendedores distribui essas metas em parcelas fixas por cliente e perfil de compra. O cadastro atual determina quem recebe cada parcela. Alterar o RCA de um cliente transfere suas parcelas de todos os meses, inclusive para vendedores que não existiam nas planilhas antigas. Retornar o RCA devolve as mesmas parcelas, sem recalcular os pesos ou sobrescrever os arquivos originais.

Faturamento e peso usam o histórico comercial dos três meses anteriores. Positivação e Mix usam perfis de cliente/mês e distribuição por maiores restos. A seleção conjunta de categorias considera a união dos perfis. Filial e categoria precisam corresponder à mesma compra. Contagens permanecem inteiras. Sem histórico qualificável, a distribuição usa os clientes identificados da carteira; filtros que não têm base conhecida mostram ausência de rateio.

As linhas oficiais de supervisor e empresa continuam independentes dos vendedores. Não são adicionadas aos detalhes. PDEV é armazenado quando fornecido e não participa dos indicadores. Células PDEV vazias são opcionais; os 23 indicadores comerciais continuam obrigatórios. A prévia exige uma linha GV e avisa divergências de faturamento/peso em relação aos vendedores, preservando os valores informados.

## Origem das carteiras

Os cadastros mensais arquivados são guardados em tabelas privadas com arquivo, referência mensal, linha e hash. A importação utiliza a carteira do mês de referência quando disponível. Para RCAs aposentados, utiliza o último cadastro anterior em que o RCA aparece. Sem referência anterior, a primeira posterior disponível é identificada como aproximação. Para janeiro de 2026, o cadastro disponível começa em fevereiro; clientes do RCA 314 foram identificados nas vendas originais de janeiro. Essas referências são consultáveis no status, sem apresentar uma aproximação como cadastro exato.

O caso de férias 286/324 e 172/312 foi confirmado pelo responsável. Os vínculos iniciais servem apenas para estabelecer uma carteira quando falta evidência arquivada. A atribuição diária sempre segue o cliente atual. Clientes ausentes, sem RCA ou sem identificação válida mantêm suas parcelas como pendentes, com código e motivo disponíveis na tabela de metas.

Novos arquivos não entram no repositório público. Evidências e cadastros de clientes ficam privados. Correções explícitas de vínculo, distribuição e mudanças de RCA geram eventos de auditoria.

## Instalação

Após as migrações de metas oficiais já existentes, aplicar uma vez nesta ordem:

1. `sql/client_goal_attribution.sql`
2. `sql/client_goal_attribution_readers.sql`
3. `sql/recover_goal_portfolio_evidence.sql`
4. `sql/archived_goal_portfolios.sql`
5. `sql/goal_attribution_status.sql`

As evidências são carregadas separadamente por administrador, sem valores de clientes no código público. Os leitores têm acesso aprovado; as tabelas privadas não oferecem acesso direto a `anon` ou `authenticated`. RLS habilitado sem políticas nessas tabelas significa bloqueio de acesso direto, por desenho.

O cache de vendas e metas é invalidado ao mudar a carteira ou a revisão da distribuição. Entrar no dashboard e na página de metas verifica a revisão. Metas atribuídas são somente leitura: corrigir o valor original exige nova importação, para evitar salvar uma parcela derivada como meta integral.

## Validação

`node --test tests/*.cjs tests/*.mjs` cobre interface, rateio, filtro, leitura de ajustes e invalidação de cache. `sql/tests/client_goal_attribution_rollback.sql` testa transferências parciais/completas, recebedor ausente na planilha, retorno, pendências, sobreposição, contagens e conservação. `sql/tests/current_portfolio_return_rollback.sql` testa o retorno de um cliente real entre Ariana e Valnei em agosto, setembro e outubro, desfazendo todas as mudanças. `tests/dashboard-targets-rollback.sql` mantém a cobertura das metas oficiais.

Os sete modelos históricos foram conferidos no navegador. As importações foram simuladas e revertidas, incluindo conservação de 100% de cada meta. Os arquivos históricos de janeiro a julho não foram importados definitivamente.
