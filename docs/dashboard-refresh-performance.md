# Atualização dos resumos: fila sem espera de um minuto

Aplicar `sql/dashboard_refresh_queue_performance.sql` após `sql/dashboard_goal_refresh_periods.sql`.

O processamento anterior consumia uma tarefa por minuto, mesmo quando ela terminava em poucos segundos. As duas últimas cargas completas registradas em 03/11/2026 tinham 45 tarefas e duraram aproximadamente 45 minutos. Resumos levaram em média 7,86 s; atribuições de metas, 53,99 s. Parte relevante da demora era o intervalo ocioso entre tarefas.

O mesmo job passa a verificar a fila a cada 5 segundos. O pg_cron executa apenas uma instância desse job por vez: tarefas demoradas não criam vários consumidores simultâneos. Cada tarefa continua com sua própria transação, prazo de reserva, bloqueio por período e tratamento de erro. A fila vazia não recalcula dados. O consumidor HTTP permanece desativado conforme a configuração existente do banco.

Dentro da carga mais antiga pendente, os meses mais recentes têm prioridade. Para o mesmo mês, resumo precede atribuição de metas. Nenhuma tarefa histórica é descartada. As funções de cálculo, os filtros, os fornecedores e as regras de atribuição não foram alterados.

Estimativa com as durações anteriores: cerca de 14–18 minutos para a mesma carga de 45 tarefas, em vez de 45 minutos. Não é uma garantia: depende do volume e da concorrência. O mês atual fica disponível antes do histórico. Confirmado na fila real: o resumo de novembro passou à frente dos meses antigos e concluiu em 0,2 s após ser iniciado.

Reversão do agendamento: `cron.alter_job(job_id, schedule := '* * * * *')`, localizando `job_id` pelo nome `dashboard-goal-refresh-worker`. Para restaurar também a ordem antiga, reaplicar a definição do consumidor em `sql/dashboard_goal_refresh_periods.sql`.
