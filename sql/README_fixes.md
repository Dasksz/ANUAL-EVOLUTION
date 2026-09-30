# Dashboard and access corrections — 2026-09-30

These scripts were applied to the EVOLUTION database. For another environment, apply `fix_dashboard_filters_and_foods.sql` first, then `secure_evolution_access.sql`. The security script installs authorization checks in the reporting functions; rerunning the functional script requires rerunning the security script afterward.

Deploy `supabase/functions/presentation-analysis` with JWT verification enabled before publishing the updated presentation frontend. It uses the built-in Supabase environment variables and the service-only `api_ia` configuration. No provider key belongs in browser code.

The existing DeepSeek provider key still needs rotation at the provider and replacement in the protected configuration. Restricting access does not revoke a previously exposed credential.

The n8n views and procedures now require service-role access. Verify the existing n8n credential and an authenticated presentation request in the target environment.

Regression checks: `node --test tests/dashboard-loading.test.cjs tests/presentation-analysis.test.mjs`.
