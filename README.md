# PRIME - Evolução Anual

Sistema de acompanhamento de evolução anual.

## Configuração

Este projeto utiliza o [Supabase](https://supabase.com/) como backend. Para garantir a segurança, as credenciais não estão incluídas no código fonte.

### Configuração Local

Para que o projeto funcione localmente:

1. Localize o arquivo `src/js/config.js.example`.
2. Crie uma cópia deste arquivo chamada `src/js/config.js`.
3. Preencha as constantes `SUPABASE_URL` e `SUPABASE_KEY` com suas credenciais do Supabase.

**Observação:** O arquivo `src/js/config.js` é ignorado pelo Git (conforme configurado no `.gitignore`).

### Configuração de Produção (GitHub Pages)

A implantação é automatizada via GitHub Actions. Para que o site funcione após o deploy:

1. No seu repositório GitHub, vá em **Settings > Secrets and variables > Actions**.
2. Adicione os seguintes **Repository secrets**:
   - `SUPABASE_URL`: A URL do seu projeto Supabase.
   - `SUPABASE_KEY`: A Anon/Public Key do seu projeto Supabase.
3. O workflow definido em `.github/workflows/deploy.yml` injetará automaticamente estas chaves no arquivo `config.js` durante o processo de build/deploy.

**Atenção:** Embora as chaves sejam externalizadas do código fonte, elas ainda são transmitidas ao navegador do cliente para permitir a comunicação com o Supabase. Portanto, a segurança dos dados deve ser implementada via **Policies (RLS)** no banco de dados.

## Desenvolvimento

Para rodar o projeto localmente, basta abrir o arquivo `index.html` em seu navegador ou utilizar um servidor local (ex: Live Server do VS Code).

## Licença

© 2026 Prime Distribuição
