// Supabase Configuration
// To prevent accidental exposure of your API keys, it is recommended to use environment variables or a local config file.
// The config.js file should be ignored by git.

// These are expected to be provided via window.SUPABASE_URL and window.SUPABASE_KEY.
const SUPABASE_URL = window.SUPABASE_URL;
const SUPABASE_KEY = window.SUPABASE_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.warn('Supabase configuration is missing. The app may not function correctly.');
    console.info('To configure, copy src/js/config.example.js to src/js/config.js and fill in your credentials.');
}

const supabase = window.supabase.createClient(SUPABASE_URL || '', SUPABASE_KEY || '', {
    global: {
        fetch: (url, options) => {
            // Safely merge headers using the Headers constructor
            const headers = new Headers(options?.headers);
            
            // Ensure apikey is present (fixes "No API key found in request" error)
            if (!headers.has('apikey') || !headers.get('apikey')) {
                headers.set('apikey', SUPABASE_KEY);
            }

            // Ensure Authorization is present (Standard Supabase requirement)
            if (!headers.has('Authorization')) {
                headers.set('Authorization', `Bearer ${SUPABASE_KEY}`);
            }
            
            // Apply cache only to GET requests to avoid issues with mutations
            const method = options?.method?.toUpperCase() || 'GET';
            if (method === 'GET') {
                headers.set('Cache-Control', 'max-age=60');
            }

            const newOptions = {
                ...options,
                headers: headers
            };

            // Use a default timeout signal if none is provided
            if (!options?.signal && typeof AbortSignal.timeout === 'function') {
                newOptions.signal = AbortSignal.timeout(600000); // 10 minutes timeout
            }

            return fetch(url, newOptions);
        }
    }
});

export default supabase;
