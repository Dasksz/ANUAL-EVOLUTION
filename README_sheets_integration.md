# Integração Automática: Google Sheets ➜ Supabase

Este documento explica como funciona e como ativar a integração direta e diária de dados do Google Sheets para o nosso banco de dados (Supabase), sem depender do n8n.

## Arquitetura
- **Origem dos Dados:** Planilha pública do Google Sheets (exportada via endpoint de CSV).
- **Processamento:** Uma [Supabase Edge Function](https://supabase.com/docs/guides/functions) (`sync-sheets`) escrita em TypeScript/Deno, que faz o download do CSV, sanitiza os dados (parse de datas brasileiras) e joga para o banco.
- **Banco de Dados:** Tabela `supervisors_routes` com restrição "Upsert" (`UNIQUE(data_rota, supervisor)`). Evita duplicação de dados, então se a planilha mudar, o banco atualiza as mesmas linhas sem gerar lixo.
- **Automação:** Extensão nativa do Postgres `pg_cron` (roda dentro do Supabase e agenda chamadas de HTTP).

---

## 1. Tabela do Banco de Dados

A estrutura da tabela se encontra no arquivo de banco completo `sql/full_system_v1.sql` e já foi preparada com a flag de RLS para o front-end. Ela mapeia os 14 campos da sua planilha de supervisores.

Caso precise executar manualmente para criar a tabela no projeto EVOLUTION, basta rodar a query presente no final do arquivo `sql/full_system_v1.sql`.

---

## 2. A Edge Function (O Motor)

A lógica inteira está na pasta: `supabase/functions/sync-sheets/index.ts`

### Como rodar/testar localmente
1. Instale a [Supabase CLI](https://supabase.com/docs/guides/cli).
2. Na raiz do projeto, inicie o supabase (se ainda não iniciou):
   `supabase start`
3. Rode a function servindo localmente:
   `supabase functions serve sync-sheets --env-file ./supabase/.env.local`
   *(Obs: O `.env.local` precisa ter as variáveis `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` do banco de destino).*
4. Teste usando o navegador, Postman ou curl acessando `http://localhost:54321/functions/v1/sync-sheets`.

### Como Fazer Deploy para Produção (Projeto EVOLUTION)
Quando estiver pronto para aplicar ao banco EVOLUTION, execute:
```bash
# Vincule a CLI ao seu projeto (ele pedirá sua senha/token)
supabase link --project-ref vawrdqreibhlfsfvxbpv

# Faça o deploy da Edge Function
supabase functions deploy sync-sheets --no-verify-jwt
```
*(Nota: A opção `--no-verify-jwt` é necessária para permitir que o banco chame a função automaticamente via pg_cron ou HTTP).*

---

## 3. Agendamento Diário (pg_cron)

Depois que a tabela estiver criada no banco e a Function estiver "deployada", você deve configurar para rodar sozinho.
Rode esta SQL diretamente no painel do Supabase (aba SQL Editor) do seu projeto:

```sql
-- Primeiro ative as extensões (se não estiverem ativas)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Agende a execução para todos os dias as 03:00 da manhã
SELECT cron.schedule(
  'sync-sheets-daily',
  '0 3 * * *',
  $$
  SELECT net.http_post(
      url:='https://vawrdqreibhlfsfvxbpv.supabase.co/functions/v1/sync-sheets',
      headers:='{"Authorization": "Bearer SUA_CHAVE_ANON_AQUI"}'::jsonb
  ) as request_id;
  $$
);
```
*Substitua `SUA_CHAVE_ANON_AQUI` pela sua chave ANON (presente em Configurações > API no Supabase).*

---

## 4. Consumo no Front-end

Na sua página nova, para visualizar esses dados, você só precisa usar o supabase-js nativamente, da mesma forma que outras tabelas:

```javascript
// Exemplo no Javascript do Front-end:
async function carregarRotasSupervisores() {
  const { data, error } = await supabase
    .from('supervisors_routes')
    .select('*')
    .order('data_rota', { ascending: false });

  if (error) {
    console.error("Erro ao carregar:", error);
    return;
  }

  console.log("Dados da planilha:", data);
  // Renderizar na data table ou em um gráfico.
}
```

Dessa forma, o seu front-end não tem sobrecarga. O banco de dados se comunica sozinho com a planilha de madrugada, e o front-end apenas lê do Supabase de forma rápida.
