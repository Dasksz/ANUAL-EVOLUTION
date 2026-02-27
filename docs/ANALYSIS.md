# Relatório de Análise Técnica: DASHBOARD-PROMOTORES

## 1. Visão Geral
O projeto, identificado como "Evolução Anual - PRIME", é um Dashboard de Business Intelligence (BI) focado na análise de desempenho de vendas. Ele permite a visualização de KPIs (Faturamento, Tonelagem, Positivação) segmentados por Filial, Cidade, Supervisor, Vendedor e Produto.

## 2. Arquitetura do Sistema

### Frontend (SPA)
- **Tecnologia:** Vanilla JavaScript (ES Modules), HTML5, Tailwind CSS.
- **Estrutura:** Single Page Application (SPA) controlada pelo arquivo monolítico `src/js/app.js`.
- **Visualização:** Utiliza `Chart.js` para gráficos e tabelas dinâmicas para relatórios.
- **Gerenciamento de Estado:** Baseado em variáveis globais e manipulação direta do DOM.

### Backend (BaaS - Supabase)
- **Banco de Dados:** PostgreSQL hospedado no Supabase.
- **API:** Não há backend tradicional (Node/Python). A comunicação é feita via Client Library do Supabase chamando funções RPC (Remote Procedure Calls) no banco de dados.
- **Autenticação:** Supabase Auth (Provedor Google) integrado com uma tabela personalizada `profiles` para controle de acesso ("Gatekeeper Pattern").

### Processamento de Dados (Client-Side ETL)
- **Web Worker:** O arquivo `src/js/worker.js` atua como um motor de ETL (Extract, Transform, Load) rodando no navegador.
- **Função:**
    1.  Parseia arquivos Excel/CSV (SheetJS).
    2.  Limpa dados (Filtro Pepsico).
    3.  Aplica regras de negócio (Mapeamento de Filiais, Lógica de Inativos).
    4.  Gera hashes SHA-256 para controle de duplicidade.
    5.  Prepara payloads JSON para envio ao Supabase.

## 3. Fluxo de Dados e Lógica de Negócio

### Mapeamento de Filiais ("Strict Force")
Conforme documentado, o sistema prioriza a configuração do banco de dados sobre o arquivo:
1.  Verifica a cidade da venda.
2.  Consulta a tabela `config_city_branches`.
3.  Se houver mapeamento, **sobrescreve** a filial original do arquivo.
4.  Novas cidades são detectadas e inseridas automaticamente com filial `NULL` para revisão.

### Gestão de Clientes Inativos
O `worker.js` implementa uma heurística para vendas sem vendedor definido ou de clientes inativos:
- Identifica o supervisor predominante na cidade da venda (baseado no volume de vendas do mês atual).
- Reatribui a venda para este supervisor, marcando o vendedor como "INATIVOS [SUPERVISOR]".

### Performance e Cache
- **IndexedDB:** O frontend utiliza a biblioteca `idb` para cachear respostas de RPCs (`PrimeDashboardDB`).
- **Tabelas de Resumo:** O banco mantém uma tabela `data_summary` e `cache_filters` que são regeradas periodicamente para evitar queries pesadas nas tabelas de fatos (`data_detailed`, `data_history`).
- **Prefetching:** O `app.js` utiliza `requestIdleCallback` para carregar filtros e visões secundárias em segundo plano.

## 4. Segurança (RLS)
O banco de dados utiliza **Row Level Security (RLS)** estrito:
- **Leitura:** Apenas usuários com status 'aprovado' na tabela `profiles`.
- **Escrita:** Apenas usuários com role 'adm' (Administradores).
- **Funções de Segurança:** Funções RPC como `truncate_table` e `handle_new_user` são definidas como `SECURITY DEFINER` para controlar privilégios.

## 5. Pontos de Atenção e Melhorias Sugeridas

1.  **Monólito `app.js`:**
    - O arquivo `app.js` possui alta complexidade (~2000 linhas). Recomenda-se refatorar dividindo em módulos (ex: `auth.js`, `ui.js`, `charts.js`).
2.  **Dependência de Hardware do Cliente:**
    - O processamento de grandes arquivos Excel no navegador pode causar travamentos em máquinas com pouca memória RAM. Uma solução de processamento em nuvem (Edge Functions) seria mais robusta a longo prazo.
3.  **Manutenção de SQL:**
    - A lógica de negócio está dividida entre o `worker.js` (regras de inativos) e o PostgreSQL (RPCs de agregação). Isso pode gerar inconsistências se não documentado rigorosamente.

## 6. Conclusão
O projeto apresenta uma arquitetura eficiente em custos (Serverless) e performance de leitura (uso intensivo de índices e cache), ideal para dashboards analíticos com volume de dados médio-alto. A complexidade principal reside na sincronização da lógica de negócios entre o Cliente (Worker) e o Banco (RPCs).
