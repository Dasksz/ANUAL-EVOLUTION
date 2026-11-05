# Timeout no gráfico de Mix Salty e Foods — 05/11/2026

Os logs de PostgREST registraram SQLSTATE 57014 no agrupamento anual da RPC `get_mix_salty_foods_data`. A agregação de 2026 percorria 69.210 pedidos elegíveis usando páginas largas da tabela de frequência. O plano medido antes da correção levou 4.583 ms, com 4.307 páginas lidas do armazenamento, além das páginas já em memória; sob concorrência a chamada do painel expirava.

Aplicada `sql/optimize_mix_chart_covering_index.sql` e executado `VACUUM (ANALYZE) public.data_summary_frequency`. O índice parcial cobre ano, mês, cliente e os nove sinalizadores de mix, excluindo os mesmos tipos 5 e 11 que a consulta já excluía. Nenhuma função, carteira, filtro, regra de mix ou dado comercial foi alterado.

O plano passou a usar Index Only Scan com zero Heap Fetches: 644 páginas em memória e 42,75 ms para o agrupamento. `sql/tests/mix_api_performance.sql` reproduz o envelope JSON preparado do PostgREST sob papel authenticated e limite de 8 segundos; a chamada completa respondeu em 356,38 ms com os 11 meses disponíveis de 2026.

`sql/tests/mix_covering_index_parity.sql` compara a resposta com índices desabilitados e habilitados. Sete casos foram idênticos: anos 2026/2025, supervisor, vendedor, múltiplas filiais/fornecedores/tipos, produtos/categoria e cidade/rede. A mudança já está ativa no banco; o frontend não requer nova versão para usá-la. Os avisos de listener assíncrono exibidos junto ao erro na captura não foram usados como causa do timeout SQL.
