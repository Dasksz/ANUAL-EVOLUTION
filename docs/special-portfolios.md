# Carteira BH

A aba Carteiras especiais da Gestão permite ao administrador master configurar códigos de clientes e percentuais, com vigência mensal. O vínculo inicial atribui 100% das metas do RCA 53 ao cliente 12034. As fontes originais da planilha permanecem identificadas como 53/BALCAO_SP para auditoria. O recebedor das parcelas é BH, supervisor 8. Americanas permanece em SV_AMERICANAS.

As versões aplicam-se a partir do mês escolhido, até a próxima versão. Alterar uma versão existente corrige explicitamente os meses abrangidos. Os percentuais devem ser positivos, com até duas casas na interface, sem clientes repetidos e com soma exata de 100%. Contagens usam maiores restos; faturamento conserva centavos e volume conserva a precisão anterior.

Os perfis históricos continuam delimitando filial, fornecedor, cidade e categoria. Clientes sem histórico qualificável recebem a parcela explícita, mas recortes sem evidência continuam sinalizados como ausência de base de rateio.

As vendas são reclassificadas no próprio registro, sem cópias, nas tabelas de detalhe, histórico, resumo e frequência. Gatilhos preservam o vínculo em novas cargas e em reconstruções. As partições herdam o gatilho do pai. Remover um cliente de uma versão devolve os registros abrangidos ao RCA do cadastro vigente. O cadastro original de clientes não é alterado. O filtro e o supervisor usam a dimensão BH.

Instalação: aplicar `sql/bh_special_portfolio.sql` uma vez após as migrações de atribuição e resumo compacto. A migração reconcilia períodos anteriores e atualiza os filtros especiais. As novas configurações são transacionais e auditadas. A RPC de Gestão usa prazo de até 240 segundos para reconciliar as cargas; a interface bloqueia envios repetidos enquanto aguarda.
