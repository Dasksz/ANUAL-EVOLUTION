## Issue Summary
The `presentation.html` dashboard was not rendering data and was failing with `window.supabase.rpc is not a function`.

## Root Cause
1. **Frontend script (`presentation.js`) mismatch:** The frontend presentation logic requested variables named `data.geral`, `data.filial`, `fat_ant_year`, etc. However, the database SQL function (`get_closing_presentation_data`) returned the aggregated data using keys `global`, `filiais`, `fat_ant`, etc.
2. **Supabase client context:** The application uses `<script type="module">` tags to import `supabaseClient` across scripts. In `src/js/supabase.js`, the code was overwriting the global CDN object `window.supabase = supabaseClient`, breaking modules or features that relied on the global namespace being exactly what the CDN provided natively. It was corrected to `window.supabaseClient = supabaseClient`.

## Resolution
1. Corrected all the data property accessor bindings in `presentation.js` to match the JSON response payload built in `get_closing_presentation_data` within `sql/full_system_v1.sql`.
2. Changed the property name where the supabaseClient instance is exposed on the `window` object in `src/js/supabase.js` to avoid conflict with `window.supabase` CDN loading.
- **Action:** Fixed `column ds.produto does not exist` error in the `get_closing_presentation_data` RPC in `sql/full_system_v1.sql`.
- **Learning:** The `public.data_summary` table (`ds`) does not have a `produto` column, but it does pre-calculate the product category as `categoria_produto`. Instead of joining with `dim_produtos` (which throws an error), the query must use the pre-calculated `ds.categoria_produto` directly.
