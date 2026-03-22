// Supabase Configuration Template
// 1. Copy this file to src/js/config.js
// 2. Fill in your credentials
// 3. The config.js file is ignored by git to protect your secrets.

const SUPABASE_CONFIG = {
    SUPABASE_URL: 'https://your-project-ref.supabase.co',
    SUPABASE_KEY: 'your-anon-key'
};

// If using in index.html:
// <script src="src/js/config.js"></script>
// Then window.SUPABASE_URL and window.SUPABASE_KEY will be available.
window.SUPABASE_URL = SUPABASE_CONFIG.SUPABASE_URL;
window.SUPABASE_KEY = SUPABASE_CONFIG.SUPABASE_KEY;
