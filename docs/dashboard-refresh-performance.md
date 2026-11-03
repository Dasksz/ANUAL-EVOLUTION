# Atualização dos resumos: fila sem espera de um minuto

Aplicar `sql/dashboard_refresh_queue_performance.sql` após `sql/dashboard_goal_refresh_periods.sql`.

O processamento anterior consumia uma tarefa por minuto, mesmo quando ela terminava em poucos segundos. As duas últimas cargas completas registradas em 03/11/2026 tinham 45 tarefas e duraram aproximadamente 45 minutos. Resumos levaram em média 7,86 s; atribuições de metas, 53,99 s. Parte relevante da demora era o intervalo ocioso entre tarefas.

O mesmo job passa a verificar a fila a cada 5 segundos. O pg_cron executa apenas uma instância desse job por vez: tarefas demoradas não criam vários consumidores simultâneos. Cada tarefa continua com sua própria transação, prazo de reserva, bloqueio por período e tratamento de erro. A fila vazia não recalcula dados. O consumidor HTTP permanece desativado conforme a configuração existente do banco.

Dentro da carga mais antiga pendente, os meses mais recentes têm prioridade. Todos os resumos da carga precedem as atribuições de metas, pois estas dependem do histórico resumido. Dentro de cada fase, os meses mais recentes têm prioridade. Nenhuma tarefa histórica é descartada. As funções de cálculo, os filtros, os fornecedores e as regras de atribuição não foram alterados.

Estimativa com as durações anteriores: cerca de 14–18 minutos para a mesma carga de 45 tarefas, em vez de 45 minutos. Não é uma garantia: depende do volume e da concorrência. O mês atual fica disponível antes do histórico. Confirmado na fila real: o resumo de novembro passou à frente dos meses antigos e concluiu em 0,2 s após ser iniciado.

Reversão do agendamento: `cron.alter_job(job_id, schedule := '* * * * *')`, localizando `job_id` pelo nome `dashboard-goal-refresh-worker`. Para restaurar também a ordem antiga, reaplicar a definição do consumidor em `sql/dashboard_goal_refresh_periods.sql`.

## Invalidar apenas quando os dados realmente mudam

A partir de `src/js/dimension-sync.mjs`, o uploader compara as dimensões recebidas com o banco antes de gravar. Listas idênticas vindas do arquivo de vendas não provocam mais reconstrução histórica. Produtos novos, mudança de embalagem/classificação ou mudança real de nomes continuam invalidando o histórico conservadoramente.

O cadastro completo dos clientes continua sendo sincronizado, incluindo última compra e contato. Para a reconstrução dos resumos são comparados códigos, inclusão/exclusão, RCA, supervisor, cidade e ramo. Correções desses atributos mantêm a reconstrução completa. Alterar apenas última compra ou telefone não a dispara.

Uma carga diária de vendas de novembro com cadastros idênticos agenda só o mês alterado (e eventuais atribuições de metas dependentes que existirem), em vez de todos os 35 meses de resumos e 10 atribuições. O tempo de envio do arquivo e o processamento efetivo continuam dependendo do volume. Não há tempo fixo garantido.

Validação: 160 testes Node, incluindo cadastros idênticos, novos códigos, renomeações, embalagem alterada, representações numéricas/datas da API, mais de 1.000 registros, mudanças de carteira, mudanças só de última compra/contato, falha de acesso e deduplicação dos meses enviados. Uma falha na comparação interrompe a importação; nunca é interpretada como ausência de mudanças.
