# Documentação de Novas Tabelas: Inovações e Notas Involves

Com a recente atualização do uploader no Dashboard de Vendas, três novas tabelas opcionais foram introduzidas no banco de dados para suportar a ingestão de informações oriundas do projeto **DASHBOARD-PROMOTORES** (Loja Perfeita e Inovações). 

Essas informações são extraídas através dos campos **Inovações** e **Notas Involves** (campo de seleção múltipla) na interface de "Atualizar Base de Dados".

Abaixo, detalhamos o propósito de cada tabela, sua estrutura e como podemos utilizar esses dados no painel para criar as visões avançadas.

---

## 1. Tabela: `data_innovations` (Inovações)

**Para que serve:**
A tabela de inovações mapeia quais produtos estão classificados como "Inovação" no ciclo atual. Muitas vezes, lançamentos recebem bonificações de meta ou tracking especial pela diretoria (Ex: Quantos pontos de venda compraram pelo menos uma "Inovação").

**De onde vem:**
Da planilha "Inovações" enviada no uploader, extraindo unicamente a relação de código do produto (`codigo`) com a respectiva classificação (`inovacoes`).

**Como podemos utilizar no projeto:**
*   **KPI de Positivação de Inovação:** Fazer um `INNER JOIN` (ou um `.filter()` no frontend) das vendas do mês atual (`data_detailed`) com `data_innovations` usando a coluna `codigo` (produto).
*   **Acompanhamento de Metas:** Contar a quantidade de clientes únicos distintos (CNPJs) que compraram pelo menos um SKU listado nessa tabela.
*   *Nota:* O nome e a marca do produto não são salvos aqui para evitar redundância. O painel deve cruzar esse `codigo` com a dimensão global de produtos (`dim_produtos`) para buscar descrições e subcategorias.

---

## 2. Tabela: `data_nota_perfeita` (Loja Perfeita / Involves)

**Para que serve:**
Registra as notas médias atribuídas aos pontos de vendas a partir das auditorias de execução de loja (conhecido como projeto "Loja Perfeita"). Isso mensura não o que o cliente *comprou* via sistema de faturamento, mas como o produto está *exposto* e a *qualidade* do PDV auditado.

**De onde vem:**
Através das planilhas de "Notas Involves". Como frequentemente o sistema "Involves Stage" gera dados muito grandes e os exporta particionados, o uploader foi modificado para permitir anexar **dois arquivos simultâneos**. 
O código processa (faz o "merge") desses arquivos, mapeando o CNPJ para o `codigo_cliente` interno e guardando a maior nota ou consolidando as auditorias do mês vigente por CNPJ e pesquisador.

**Como podemos utilizar no projeto:**
*   **Visão de Execução vs Venda:** Montar gráficos cruzando o eixo X (Nota do Involves de 0 a 100) com o eixo Y (Faturamento Mês). Pontos com Nota Baixa e Faturamento Alto são prioridades de correção de gôndola.
*   **Ranqueamento de Execução:** Em uma nova tela (ou na tela de Vendedores), mostrar a "Média de Nota Perfeita" ponderando o total de `auditorias` vs `auditorias_perfeitas` para cada `pesquisador`.

---

## 3. Tabela: `relacao_rota_involves`

**Para que serve:**
Estabelece a ponte (o *De-Para*) entre o vendedor faturista (RCA / código do sistema de vendas) e o auditor/promotor no sistema Involves (Código Involves).

**De onde vem:**
A tabela foi provisionada no banco para ser **alimentada posteriormente pelo administrador** (ou através de futuros updates de cadastro). 

**Como podemos utilizar no projeto:**
*   **Junção de Dados Heterogêneos:** As planilhas do Involves (`data_nota_perfeita`) costumam referenciar as rotas e lojas de acordo com o `involves_code` (ou `pesquisador`). Já o sistema ERP agrupa tudo pelo `seller_code` (Vendedor de Distribuição).
*   **Visão do Vendedor (RCA):** Para construir uma tabela na tela de um Vendedor ("RCA 500") mostrando as Notas de Loja Perfeita dos clientes da carteira dele, o SQL utilizará esta tabela:
    ```sql
    -- Exemplo de Relacionamento (Conceitual)
    SELECT n.nota_media, c.nomecliente 
    FROM data_nota_perfeita n
    JOIN relacao_rota_involves r ON r.involves_code = n.pesquisador
    JOIN data_clients c ON c.codigo_cliente = n.codigo_cliente
    WHERE r.seller_code = '500';
    ```

---

### Resumo do Fluxo de Upload

1. O Administrador vai em "Atualizar Base de Dados".
2. Seleciona `Vendas Mês Atual` e `Cadastro de Clientes` (Obrigatórios).
3. Expande "Planilhas Opcionais".
4. Seleciona a planilha de **Inovações**.
5. Em **Notas Involves**, seleciona os **dois arquivos CSV/Excel** extraídos do portal de auditoria.
6. Clica em Gerar. O painel apaga as versões antigas dessas 3 tabelas e insere os novos dados consolidados, prontos para uso nos próximos componentes visuais ou relatórios do Supabase.