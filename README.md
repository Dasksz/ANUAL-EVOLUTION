# PRIME - Evolução Anual

Sistema de acompanhamento de evolução anual.

## Configuração

Este projeto utiliza o [Supabase](https://supabase.com/) como backend. Para configurar as chaves de API necessárias:

1. Localize o arquivo `src/js/config.example.js`.
2. Faça uma cópia deste arquivo e renomeie-a para `src/js/config.js`.
3. Abra `src/js/config.js` e substitua os valores de `SUPABASE_URL` e `SUPABASE_KEY` pelas credenciais do seu projeto no painel do Supabase (Configurações > API).

**Importante:** O arquivo `src/js/config.js` é ignorado pelo Git para garantir que suas chaves de API não sejam expostas publicamente.

## Desenvolvimento

Para rodar o projeto localmente, basta abrir o arquivo `index.html` em seu navegador ou utilizar um servidor local (ex: Live Server do VS Code).

## Licença

© 2026 Prime Distribuição
