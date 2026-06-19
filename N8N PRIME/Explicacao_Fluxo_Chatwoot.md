# N8N PRIME - Fluxo de Transferência Chatwoot

Este diretório contém a versão mais recente e corrigida do seu fluxo de atendimento (n8n + Chatwoot + WhatsApp).
As mudanças a seguir foram implementadas no arquivo `AGENT_ELMA.json` para sanar erros antigos e otimizar o atendimento.

## Problemas Resolvidos

### 1. Todas as mensagens iam para o Chatwoot gerando conversas diferentes
**O Problema Anterior:** Toda mensagem de um cliente (seja um 'oi' ou uma resposta à IA) passava pelo nó inicial e era instantaneamente encaminhada para o nó de `Sync 1: Contato Chatwoot`, criando tickets no painel indiscriminadamente.
**A Solução:** O fluxo foi alterado para que as mensagens **fiquem apenas entre o cliente e o Agente de IA** no WhatsApp. As mensagens só serão enviadas para o Chatwoot quando a IA efetivamente decidir fazer a transferência (usando as tags `[TRANSFERIR_COMERCIAL]` ou `[TRANSFERIR_FINANCEIRO]`).

### 2. Erro 404 (Resource could not be found) na transferência
**O Problema Anterior:** O fluxo usava nós de busca nativos da API do Chatwoot (Buscar Contato -> Buscar Conversa) e tentava atribuir um atendente. Quando o contato era novo (ou a conversa havia sido fechada), o chatwoot retornava 404 porque não encontrava a conversa ativa, abortando o fluxo.
**A Solução:** O sistema agora possui um bloco robusto unificado:
- **Garantir Contato:** Executa a API pública que atua como um `Upsert` (busca pelo telefone ou cria se não existir).
- **Obter Conversas & Verificação:** Busca todas as conversas e verifica se existe uma em aberto.
- **Criar ou Reaproveitar:** Se já existir uma conversa, o n8n utiliza o ID dela. Se não existir, ele cria uma NOVA conversa. Isso impede o erro 404 e agrupa tudo no mesmo "ticket" dentro do Chatwoot.

### 3. Erro "Node Unexecuted" e Ramificação Limpa
**O Problema Anterior:** Quando importávamos nós que já existiam, o n8n criava sufixos (ex: `Definir Financeiro1`). As expressões estavam quebrando ao tentar ler propriedades de nós que não executaram (porque tomaram outra rota).
**A Solução:** Removemos variáveis difíceis de rastrear. O nó de `Switch Atribuição Final` agora não depende de "Set nodes" temporários. Ele lê diretamente a saída que a própria IA gerou (`$('AI Agent').item.json.output`), verificando se ela contém a instrução de `TRANSFERIR_COMERCIAL` ou `TRANSFERIR_FINANCEIRO`. Isso é à prova de falhas porque a IA executa em 100% dos casos antes de transferir.

### 4. Limite de Ações do Agente AI (Max Iterations Reached)
**O Problema Anterior:** O limite padrão do nó do agente (10 passos) era ultrapassado porque a instrução do prompt é muito detalhada e utiliza as ferramentas do Supabase múltiplas vezes de forma sequencial (validar perfil, buscar estoque, etc).
**A Solução:** A propriedade interna `maxIterations` da IA foi subida manualmente no JSON para 15, dando tempo/margem de sobra para a IA analisar, buscar dados e processar todo o comando sem o sistema do n8n matar a execução precocemente.

---

### Como utilizar
Basta acessar o seu projeto no n8n, limpar seu canvas (ou abrir um novo workflow limpo) e fazer a **importação** deste arquivo `AGENT_ELMA.json`.

Todos os IDs do seu Chatwoot (como contas, URLs) e credenciais de APIs (OpenAI, Supabase, WAHA, Redis) estão mantidas da versão original. Nenhuma configuração base ou lógica de negócios do Agente AI foi alterada.
