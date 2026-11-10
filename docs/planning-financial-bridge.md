# Planning PDF financial columns

Planning keeps its existing historical monthly revenue average and current-month net revenue. `planning_financial_source_promotores.sql` runs on PROMOTORES and reads the saved client goals for the exact month (`goals_distribution`, ALL / GENERAL) plus open overdue titles. Salty and Foods leaf goals are summed without counting aggregate totals twice. Missing monthly/client goals stay null; saved zero stays zero. Overdue means `vl_receber > 0` and due date before the current Bahia date, regardless of the route date.

`planning_financial_bridge.sql` runs on EVOLUTION. A dedicated random 256-bit integration token is stored only in Evolution Vault as `planning_financial_bridge`, with JSON fields `token` and `anon` (the Promotores public API key). PROMOTORES stores only its SHA-256 in `private.planning_financial_bridge_config` (`id=true`). Provision values separately, never commit the token. Rotating this token requires updating both places together.

The source RPC intentionally permits REST execution using the public API key, but checks the dedicated token before any data read. It accepts only numeric client codes (at most 2500) and a valid month, and returns only those clients' monthly revenue goal and overdue boolean. The configuration table has RLS, no permissive policies, and no client privileges. It does not share a service-role key. The Evolution helper checks the caller's approved account before accessing Vault; the browser receives no integration token.

Financial information is requested when exporting, not copied on a timer, so saved goal corrections and title uploads are visible on the next export. An unavailable or incomplete financial response stops the export instead of classifying unknown clients as not overdue. The legacy portfolio/list RPC and raw sales remain unchanged.

Apply the source migration to PROMOTORES, provision the dedicated token in both projects, apply the bridge and portfolio export migrations to EVOLUTION, and run `sql/tests/planning_financial_source.sql` on PROMOTORES and `sql/tests/planning_financial_bridge.sql` on EVOLUTION. Notify PostgREST to reload the source schema after first installation.
