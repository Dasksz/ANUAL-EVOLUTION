import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = request.headers.get("authorization");
  const apiKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!authorization?.startsWith("Bearer ") || !apiKey || !supabaseUrl) {
    return json({ error: "authentication_required" }, 401);
  }

  let body: { job_id?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const jobId = typeof body.job_id === "string" ? body.job_id : "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(jobId)) {
    return json({ error: "invalid_job_id" }, 400);
  }

  const rpc = async (name: string, args: Record<string, unknown>) => {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        authorization,
        apikey: apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(125_000),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`${name} (${response.status}): ${text.slice(0, 800)}`);
    return text ? JSON.parse(text) : null;
  };

  const wakeAgain = async () => {
    try {
      await fetch(`${supabaseUrl}/functions/v1/dashboard-goal-refresh`, {
        method: "POST",
        headers: { authorization, apikey: apiKey, "content-type": "application/json" },
        body: JSON.stringify({ job_id: jobId }),
        signal: AbortSignal.timeout(10_000),
      });
    } catch (error) {
      console.error("Não foi possível continuar a fila imediatamente; o cron retomará as tarefas.", error);
    }
  };

  const run = async () => {
    const started = Date.now();
    let processed = 0;
    while (processed < 8 && Date.now() - started < 45_000) {
      const task = await rpc("elma_dashboard_goal_refresh_claim", { p_run_id: jobId });
      if (!task?.task_id || !task?.lease_token) return;
      try {
        await rpc("elma_dashboard_goal_refresh_process", {
          p_task_id: task.task_id,
          p_lease_token: task.lease_token,
        });
      } catch (error) {
        const message = String(error instanceof Error ? error.message : error).slice(0, 1000);
        try {
          await rpc("elma_dashboard_goal_refresh_fail", {
            p_task_id: task.task_id,
            p_lease_token: task.lease_token,
            p_error: message,
          });
        } catch (failError) {
          console.error("Falha ao registrar erro da etapa; o prazo de reserva liberará a tarefa.", failError);
        }
      }
      processed += 1;
    }

    const runs = await rpc("elma_dashboard_goal_refresh_status", { p_run_id: jobId });
    const run = Array.isArray(runs) ? runs[0] : null;
    if (run && ["queued", "processing"].includes(run.status)) await wakeAgain();
  };

  EdgeRuntime.waitUntil(run().catch((error) => {
    console.error("Erro ao processar a atualização das metas; o cron tentará novamente.", error);
  }));
  return json({ accepted: true, job_id: jobId }, 202);
});
