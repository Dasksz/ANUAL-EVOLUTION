## 2026-04-16 - n8n Credential Redaction

**Vulnerability:** Third-party API credentials (like Chatwoot `api_access_token`) were exposed in exported n8n workflow JSON files, risking unauthorized access if the repository is public or compromised.
**Learning:** Hardcoded secrets in static declarative files (like n8n JSONs or Postman collections) are easily overlooked because they often sit deep inside node parameter definitions.
**Prevention:** Always implement automated or manual sanitization steps to replace API keys, tokens, and sensitive URLs with `REDACTED` or placeholders before committing workflow exports.

## 2024-05-18 - Content Security Policy (CSP) for Static Frontends Heavy on DOM Manipulation
**Vulnerability:** Static, frontend-only applications relying heavily on `.innerHTML` loops (e.g., table generation logic like in `src/js/app.js`) are inherently at a higher risk of DOM-based Cross-Site Scripting (XSS) if variable sanitization (like `escapeHtml()`) is ever accidentally missed by a developer.
**Learning:** Because this architecture relies on zero build tools (no bundler/Vite) and imports scripts dynamically from third-party CDNs (Tailwind, Chart.js, etc), it is highly susceptible to script injection or object embedding if an attacker successfully finds a sink. We cannot eliminate `unsafe-inline` because the app and CDNs depend on it, but we can completely disable `unsafe-eval` and block insecure domains or objects.
**Prevention:** Implement a strict Content Security Policy (CSP) meta tag in `index.html` that whitelists known CDNs (`cdn.tailwindcss.com`, `cdn.jsdelivr.net`, `cdnjs.cloudflare.com`), explicitly drops `object-src 'none'`, and blocks `unsafe-eval`. This provides a crucial defense-in-depth layer to mitigate impact even if an `escapeHtml()` call is missed.
## 2024-04-19 - [DOM-based XSS via unsafe innerHTML usage]
**Vulnerability:** Found multiple instances where values were interpolated into `innerHTML` strings without being sanitized by `escapeHtml()` first. This includes dates, month names, and mathematical derivations in various dashboard tables (`calendar`, `frequency tree`, `innovations table`, `pdf header`). Also the `setElementLoading` in `src/js/utils.js` wasn't escaping `loadingText`.
**Learning:** Developers often forget to sanitize numeric or derived values (like dates or rounded numbers) when writing template literals for `innerHTML`, assuming they are inherently safe. However, if those values are eventually derived from untrusted inputs or the schema changes, it introduces XSS.
**Prevention:** Always use `escapeHtml()` when interpolating *any* dynamic variable into a string that will be assigned to `innerHTML`, regardless of whether the variable currently holds a number or a date. Consider using `.textContent` where possible instead.

## 2025-05-15 - SVG Path Update XSS Prevention (Refined)
**Vulnerability:** Potential Cross-Site Scripting (XSS) via unsafe `innerHTML` assignments when updating SVG icons. Although the data sources were hardcoded path strings, using `innerHTML` with template literals is a dangerous pattern that can be exploited if the data source ever becomes dynamic or compromised.
**Learning:** Updating SVG icons by replacing the entire `innerHTML` of the `<svg>` element is less efficient and more risky than targeting specific attributes. Simple UI toggles often only need to change the `d` attribute of a `<path>` element.
**Prevention:** Always prefer granular DOM API methods like `setAttribute()` or `textContent` over `innerHTML`. For SVG icon state changes, target the `<path>` element and update its `d` attribute directly. If the number of paths changes, consider pre-defining them in the HTML and toggling their visibility or clearing their `d` attribute.
**Refined Action:** Introduced a centralized `updateSvgPaths` utility that uses `document.createElementNS` to manage path elements safely, ensuring consistent styling (attributes) and avoiding `innerHTML` entirely.
## 2025-06-05 - Avoid SQL Injection via Direct Parameter usage
The new `chart_data` return block inside `get_loja_perfeita_data` relies safely on predefined string patterns `p_codcli` arrays instead of allowing unescaped text input natively into the formatting via `$1`.
## 2025-06-10 - Ensure SQL schemas use specific columns instead of relying only on parsed text variables

**Learning:** When altering existing schemas for new business requirements (like filtering data by `mes` and `ano` on `data_nota_perfeita`), ensure the respective SQL columns exist and are safely added with `IF NOT EXISTS` in the schema definitions, avoiding assumptions that raw text parsed date columns (like `mes_ano`) are sufficient for integer operations and filtering.
**Action:** When errors like "column np.mes does not exist" occur, check the initial schema definition, and then alter the database tables using safe migration blocks (`DO $$ BEGIN ... END $$;`) instead of modifying just the function/rpc queries that rely on them.
## 2026-06-22 - Add Category Ranking and Total Salty Positivação in Share View
**Learning:** Understand how  and  are used to map specific business logic like 'Salty Positivação' using pure SQL aggregated via JSON to the frontend. Validated that  must wrap string interpolations inside HTML mappings.
**Action:** Always verify  constraints when adding global positive indicators (e.g. Salty vs general foods).
## 2026-06-22 - Add Category Ranking and Total Salty Positivação in Share View
**Learning:** Understand how `vlvenda >= 1` and `codfor IN (...)` are used to map specific business logic like 'Salty Positivação' using pure SQL aggregated via JSON to the frontend. Validated that `escapeHtml` must wrap string interpolations inside HTML mappings.
**Action:** Always verify `codfor` constraints when adding global positive indicators (e.g. Salty vs general foods).
## 2026-06-26 - Fix sp_mix_ideal_cliente
## 2024-06-26 - [Fix sp_mix_ideal_cliente JSON lookup logic]
**Aprendizado:** When pulling nested properties from a dynamic JSON column in PostgreSQL like `estoque_filial->>v_cliente_ramo`, it's critical to ensure the lookup key corresponds exactly to the actual logical key stored inside the JSON blob. Looking up the stock count using `ramo` (industry sector) instead of the `filial` (branch) will always return `NULL`, breaking the logic that depends on `estoque_filial_num > 0`.
**Ação:** When querying JSONB maps with variable keys, double check the origin table of the target object to ensure the data domain of the key variable correctly matches the data domain of the stored JSON object keys. Always test JSON extraction boundaries manually against production-like schemas before deploying.
## 2026-06-27 - Prevent LLM Markdown Hallucination

**Learning:** Even when explicitly instructed to *not* format database outputs, LLMs (like DeepSeek or GPT) have a strong inherent bias towards formatting tabular data into markdown tables (`|---|---|`), which renders poorly in WhatsApp.
**Action:** When pulling pre-formatted string blobs from SQL views/functions into an AI agent, the system prompt must explicitly forbid the specific unwanted format (e.g. `NUNCA use tabelas markdown (ex: |---|---|)`). Furthermore, ensure the SQL functions return clean string interpolations with mapped enumerations (e.g. `CASE WHEN tipo_venda = '1' THEN 'Normal'`) instead of raw shorthand strings (e.g. `11=Bonif / 5=Perda`) to reduce confusion for both the LLM and the end user.
## 2026-06-27 - Positivation Logic in Order History

**Learning:** Calculating "positivation" status over an entire month using aggregate queries inside `sp_historico_pedidos` is more accurate for business goals (e.g. tracking Salty and Foods targets) than evaluating positivity on a per-order basis, which is how it was originally implemented.
**Action:** When implementing complex business rules like "must buy at least one item from 5 specific categories to be considered positivado", use exact category matches against the transaction history for the time period (e.g. `WHERE cat.marca NOT IN (...)`) and generate a clear summary (e.g. "Faltam: X, Y"). Always verify the exact string values expected for those categories (like `KERO COCO` vs `KEROCOCO`) in `dim_produtos`.
## 2026-06-27 - N8N AI Agent Prompt Updates
**Insight:** When interacting with rigid database tools (e.g. tools accepting exactly one order number via `sp_consultar_pedido`), the AI must be explicitly instructed on how to handle plural requests (like "these two orders").
**Action:** Added explicit instructions to the N8N prompt: "Se o usuário pedir para consultar mais de um pedido... VOCÊ DEVE CHAMAR A FERRAMENTA DE BUSCA MÚLTIPLAS VEZES".
