# PRIME - Evolução Anual

Sistema de acompanhamento de evolução anual.

## Configuração

Este projeto utiliza o [Supabase](https://supabase.com/) como backend. As chaves de API estão configuradas no arquivo `src/js/supabase.js`.

**Atenção:** Como o projeto é executado inteiramente no navegador do cliente (GitHub Pages), a Anon Key e URL do Supabase são públicas e incluídas no código fonte. Por conta disso, a segurança dos dados DEVE ser tratada no banco de dados, configurando rigorosamente as políticas RLS (Row Level Security) do Supabase para prevenir acesso não autorizado aos dados.

## Desenvolvimento

Para rodar o projeto localmente, basta abrir o arquivo `index.html` em seu navegador ou utilizar um servidor local (ex: Live Server do VS Code).

## Licença

© 2026 Prime Distribuição
