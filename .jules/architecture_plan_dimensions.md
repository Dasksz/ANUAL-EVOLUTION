## Arquitetura de Dimensões (Slowly Changing Dimensions)

**Objetivo:** Permitir retribuição histórica automática de vendedores e supervisores sem reprocessamento massivo das tabelas de vendas/resumo.
**Método:** Criar uma tabela de relacionamento mestre que dite a carteira atual de cada cliente.

### A Estrutura de Inativos:
Como mapear os 'INATIVOS' e 'AMERICANAS' que não necessariamente têm um cliente fixo 1:1, mas precisam existir no banco de dados para que os relatórios batam?

1. **A Tabela de Ligações (Carteira Ativa):**
Criaremos ou adaptaremos `data_clients` (ou uma `relacao_cliente_vendedor`) para guardar:
- `codigo_cliente` (Chave)
- `codigo_vendedor_atual`
- `codigo_supervisor_atual`

2. **Como lidar com os Inativos e Genéricos:**
Para vendas que não têm um cliente rastreável amarrado a um vendedor (exemplo: uma venda direta em balcão que foi amarrada ao código Vendedor INATIVO 9999), o script de relatório precisa usar a função `COALESCE`:
- Se o `codigo_cliente` existe na tabela de ligação, puxa o Vendedor da tabela.
- Se não existe (ou se a regra do negócio diz que INATIVO não muda de dono retroativamente), ele usa o código de vendedor que *veio gravado originalmente* na linha da venda bruta (`data_detailed`).

Isso garante que: clientes reais mudam de dono (Demitiram o João, entrou o Pedro, o histórico do cliente X agora é do Pedro). Mas vendas órfãs amarradas a códigos de 'SISTEMA/INATIVO' ficam presas no INATIVO sem bugar o balanço financeiro total.

### Impacto:
- Alterar funções `get_main_dashboard_data`, `get_boxes_dashboard_data` e derivadas para fazer `LEFT JOIN relacao_cliente_vendedor`.
- O Uploader de Clientes/Vendas precisará fazer um `UPSERT` (Update se existir, Insert se for novo) nessa tabela de relações para manter ela sempre fresca.

**Adendo:** A tabela `data_clients` JÁ cumpre o papel de Carteira Atual. Como ela possui o `codigo_vendedor` e `codigo_supervisor` (para a maioria dos clientes, exceto inativos), não é necessário criar uma nova tabela.
- Na refatoração das RPCs (Dashboards), faremos um `LEFT JOIN data_clients dc ON s.codcli = dc.codigo_cliente`.
- Para definir de quem é a venda na query em tempo real: `COALESCE(dc.codigo_vendedor, s.codusur) as vendedor_final`.
- Para os inativos/genéricos, o `LEFT JOIN` ou trará nulo (pois o cliente pode não estar mapeado em `data_clients`), fazendo o `COALESCE` recorrer ao `s.codusur` original (o Inativo), o que garante a coesão.

**Adendo 2 - Uploader & Supervisor:**
- A tabela `data_clients` precisa de uma nova coluna `codsupervisor`.
- **Ação JS (Uploader):** Quando a planilha de clientes (ou vendas) for enviada, a mesma lógica que hoje descobre e amarra o Supervisor ao Vendedor deve ser usada para escrever a coluna `codsupervisor` diretamente dentro de `data_clients`.
- **Ação JS (Inativos):** A mesma rotina de identificação dos INATIVOS, que já é usada no worker/uploader, pode ser executada para popular e mapear a tabela corretamente antes do upsert final.
- Com isso, `data_clients` centralizará 100% da verdade sobre carteiras (Cliente -> Vendedor -> Supervisor).

**Adendo 3 - Inativos e Balcão (Regras Confirmadas):**
- A lógica do `worker.js` atual já atende com perfeição a separação entre Balcão Genuíno (Lista de exceções/Americanas) e Clientes Inativos (Vendedor 53 que não está nas exceções).
- **O que será feito:** Manter intacta a lógica de inteligência de roteamento de inativos atual. Apenas **redirecionar a saída de dados**.
- Em vez de aplicar a lógica apenas na tabela de VENDAS (`data_detailed`), aplicaremos essa lógica também no loop que sobe os CLIENTES para o Supabase, garantindo que o `codsupervisor` gerado por essa inteligência seja gravado diretamente na linha do cliente na `data_clients`, selando assim a arquitetura.

**Adendo 4 - Upsert Fantasma (Orphan Clients):**
- **Problema:** Um cliente pode existir na planilha de Vendas (upload do usuário), mas NÃO existir na planilha de Clientes (seja por esquecimento, atraso de extração ou balcão temporário).
- **Solução no Uploader (JS/SQL):**
Ao fazer o upload de *Vendas* (`data_detailed` ou `data_history`), o `worker.js` montará uma lista de todos os `codcli` únicos daquela remessa de vendas.
O sistema fará um `UPSERT` (INSERT ON CONFLICT DO NOTHING) de clientes 'fantasmas' na `data_clients` apenas com os dados essenciais extraídos da própria linha de venda (ex: `codigo_cliente`, `nome`, `codvendedor` e o `codsupervisor` deduzido).
- Assim, o `LEFT JOIN` na view nunca falhará e a retribuição histórica continua 100% precisa, cobrindo buracos operacionais no Excel.

**Adendo 5 - Enriquecimento do Upsert Fantasma (Dados da Venda):**
Quando o cliente órfão for inserido na `data_clients` durante um upload de VENDAS (como fallback), as seguintes colunas estarão disponíveis para preenchimento a partir da própria linha de venda:
- `codigo_cliente`: (CODCLI)
- `nomeCliente` / `razaosocial`: (CLIENTE / NOMECLIENTE)
- `cidade`: Obtida pelo código IBGE da coluna (MUNICIPIO) cruzado com a lógica existente no worker.
- `filial`: (FILIAL)
- `codigo_vendedor`: (CODUSUR / INAT_...)
- `codsupervisor`: (SUPERV / Deduzido pela lógica de inativos)
- `ultimacompra`: Será atualizada com o MAX(DTPED) daquele cliente na remessa atual que está subindo.
