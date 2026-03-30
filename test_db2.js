const { execSync } = require('child_process');

// In the error log image we see:
// API Error: code 42703, message: column "categorias" does not exist
// This happened when POST /rest/v1/rpc/get_main_dashboard_data was called.

// Ah! In get_main_dashboard_data, the v_where_base logic is appended to a WHERE clause for `data_detailed` and `data_history`!
// Not `data_summary_frequency`!
// Let's verify where v_where_base is used inside get_main_dashboard_data.
