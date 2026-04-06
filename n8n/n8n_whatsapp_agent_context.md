# Contexto do Workflow n8n: Atendimento WhatsApp com AI Agent

## 🎯 Objetivo Principal
O objetivo deste workflow é criar um assistente virtual inteligente (Dori) para a PRIME Distribuição no WhatsApp. 
Ele deve ser capaz de realizar uma triagem inicial identificando se o usuário é "Cliente" ou "Colaborador", validar as credenciais do usuário diretamente no banco de dados (Supabase) usando ferramentas do n8n (Tools), e então prosseguir com o atendimento especializado com base no perfil.

## 🏗️ Arquitetura
1. **Webhook (WAHA):** Recebe as mensagens recebidas do WhatsApp.
2. **AI Agent (n8n):** O cérebro do fluxo. Utiliza um LLM (Gemini) atuando sob um System Prompt rígido. 
   - Ele controla todo o fluxo conversacional.
   - Ele possui acesso a ferramentas (Tools) como a integração com Supabase.
3. **Tools (Supabase):** O Agente usa a ferramenta `Validar_RCA` para checar no banco se um colaborador existe e extrair seu nome com base no CPF.
4. **Envio (WAHA):** O fluxo envia as respostas de texto limpo geradas pela IA de volta para o WhatsApp do usuário.

## 🐛 Histórico de Problemas e Soluções

### 1. Botões Meta x WAHA Gratuito
Inicialmente o sistema tentava usar botões interativos do WhatsApp (Meta). O WAHA GOWS gratuito não suporta templates/botões, resultando em falhas.
**Solução:** Substituído por um menu de texto puramente numérico (1️⃣ Sou Cliente, 2️⃣ Sou Colaborador). A IA foi orientada a ler e interpretar o número digitado.

### 2. Agente de IA "Apressado" (Alucinação de Tool Execution)
Quando o usuário selecionava a opção 2 (Colaborador), o Agente executava a ferramenta de validação de CPF imediatamente com os parâmetros vazios ou incorretos (ao invés de aguardar e pedir o CPF primeiro). Isso fazia o agente retornar respostas vazias como `"Olá, ! 👋 CPF confirmado..."`.
**Solução:** Foi aplicado um isolamento em "Etapas" no System Prompt do Agente. Foi dado um comando explícito para ele *parar de gerar respostas/ações* após pedir o CPF, aguardando o próximo input do webhook.

### 3. Falha Silenciosa de Execução do Nó (No Output Data)
Ao buscar um CPF na tabela `dim_vendedores` e não encontrar, o nó do Supabase do n8n parava a execução do workflow inteiro silenciosamente (erro *No output data returned*). Isso deixava a IA sem resposta.
**Solução:** O nó do Supabase foi configurado com a opção **"Always Output Data" (Settings)**. Isso garante que a IA receba um array vazio `[]` quando a busca falha, permitindo que ela lide com o erro e avise o usuário adequadamente.

### 4. Caracteres Invisíveis Sujando o Banco de Dados (CRLF \r\n)
Mesmo com o fluxo fluindo perfeitamente, CPFs corretos como `01873357532` não estavam sendo encontrados.
**Descoberta (Via MCP):** O banco de dados do Supabase foi verificado. A coluna `cpf` na tabela `dim_vendedores` possui caracteres de quebra de linha invisíveis (CRLF `\r\n`) concatenados no final dos registros!
*Exemplo no banco:* `"01873357532\r\n"`
*Input do n8n:* `"01873357532"`
Como a ferramenta do n8n usa a operação padrão (que gera uma query de igualdade exata `=` na API do PostgREST), o CPF digitado nunca dava *match* com o do banco devido à sujeira do "\r\n".

**Soluções aplicáveis no n8n (sem alterar o banco):**
Para contornar o problema de sujeira no banco (`\r\n`) diretamente no nó do Supabase, temos algumas opções:
- Mudar a operação na aba Parameters de "Get Many" para usar uma Custom Query ou ajustar o Filter para usar "Contains" (LIKE) ao invés de igualdade, caso a ferramenta permita.
- Reinstruir a IA para sempre tentar enviar a formatação com `\r\n` (Gambiarra, não recomendado).
- Melhor cenário: **Limpar a base de dados** ou **Criar uma View no Supabase** que faz o `TRIM(cpf)` e conectar a ferramenta do n8n nesta View.

**Ação Tomada:** O JSON do workflow do n8n foi atualizado. Na ferramenta `Validar_RCA`, o filtro do CPF teve sua condição alterada de `eq` (igual) para `contains` (contém), de forma a contornar o problema dos sufixos ocultos sem que a IA precise fazer ginásticas para adivinhar a quebra de linha. Adicionalmente, a opção `Always Output Data` foi aplicada ao nó, evitando que o workflow falhe silenciosamente caso nenhuma linha seja retornada.

---
*Este documento foi gerado pelo assistente MCP para servir de contexto aos próximos passos.*
