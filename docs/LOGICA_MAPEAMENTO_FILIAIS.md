# Lógica de Mapeamento de Filiais

Este documento descreve como o sistema determina a filial de uma venda, priorizando a configuração do banco de dados sobre os dados do arquivo original.

## 1. Fonte da Verdade: Tabela `config_city_branches`

A tabela `config_city_branches` no Supabase é a referência principal para o mapeamento de **Cidade -> Filial**.

**Estrutura da Tabela:**
- `id`: UUID (Chave Primária)
- `cidade`: Nome da cidade (Único)
- `filial`: Código da filial (Texto, ex: '01', '05')

## 2. Lógica de "Força Bruta" (Strict Branch Force)

Durante o processamento dos arquivos de vendas (no `src/js/worker.js`), o sistema aplica a seguinte regra:

1.  Para cada linha de venda, o sistema identifica a cidade (`MUNICIPIO`).
2.  Verifica se essa cidade existe na tabela `config_city_branches`.
3.  **Se existir e tiver uma filial configurada**: O sistema **sobrescreve** a filial original do arquivo com a filial configurada no banco.
4.  **Se não existir ou não tiver filial configurada**: O sistema mantém a filial original do arquivo (ou define como '00' se vazia).

**Exemplo:**
- Se o arquivo diz que uma venda em "SÃO PAULO" é da Filial '99'.
- Mas no banco (`config_city_branches`), "SÃO PAULO" está configurado como Filial '01'.
- O sistema processará a venda como sendo da Filial '01'.

## 3. Tratamento de Novas Cidades

Se o sistema encontrar uma cidade no arquivo que **não existe** na tabela `config_city_branches`:

1.  A cidade é identificada como uma "Nova Cidade".
2.  Ao final do processamento (no `src/js/app.js`), essas novas cidades são inseridas automaticamente na tabela `config_city_branches`.
3.  A coluna `filial` é inserida como `NULL` (vazia).

Isso permite que o sistema capture novas cidades automaticamente, aguardando apenas a configuração manual da filial correta.

## 4. Notificações e Alertas

Para garantir que todas as cidades tenham filiais configuradas:

- O sistema verifica (`checkMissingBranches` em `app.js`) se existem registros na tabela `config_city_branches` onde a coluna `filial` é nula ou vazia.
- Se encontrar, exibe uma notificação ("Filiais Pendentes" ou similar) para o administrador no painel de upload.

## Resumo do Fluxo

1.  **Upload**: Admin envia arquivos.
2.  **Worker**: Processa vendas, aplica `config_city_branches` (sobrescreve filial), identifica novas cidades.
3.  **App**: Recebe dados do Worker.
4.  **App**: Insere novas cidades no banco (com filial NULL).
5.  **App**: Carrega dados processados no banco (`data_detailed`, `data_history`).
6.  **App**: Verifica filiais pendentes e alerta o admin.
