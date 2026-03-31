const fs = require('fs');

let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// I need to find the definition of `MIX PDV` and `SKU/PDV` in get_main_dashboard_data.
