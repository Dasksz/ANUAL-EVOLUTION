// Supabase Configuration
import { SUPABASE_URL, SUPABASE_KEY } from './config.js';

if (!SUPABASE_URL || !SUPABASE_KEY || SUPABASE_URL.includes('YOUR_SUPABASE_URL_HERE')) {
    console.error('CRITICAL: Supabase credentials missing or invalid. Please check src/js/config.js');
}

// Initialize the Supabase client
const supabaseClient = window.supabase.createClient(SUPABASE_URL || '', SUPABASE_KEY || '', {
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

// Attach to window to maintain global 'supabase' variable access for non-module scripts/legacy code
window.supabase = supabaseClient;

export default supabaseClient;
