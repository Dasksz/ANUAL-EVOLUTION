// Supabase Configuration
const SUPABASE_URL = 'https://vawrdqreibhlfsfvxbpv.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhd3JkcXJlaWJobGZzZnZ4YnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwNzg1MTAsImV4cCI6MjA4MjY1NDUxMH0.-mAobZK_dc3QOwey3Z8NbrtybWPoPRfBqW_IN0gehl8';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
    global: {
        fetch: (url, options) => {
            // Safely merge headers using the Headers constructor
            // This handles whether options.headers is a plain object or a Headers instance
            const headers = new Headers(options?.headers);

            // Ensure apikey is present (fixes "No API key found in request" error)
            if (!headers.has('apikey')) {
                headers.set('apikey', SUPABASE_KEY);
            }

            headers.set('Cache-Control', 'max-age=60'); // Cache de 1 min em rede

            const newOptions = {
                ...options,
                signal: AbortSignal.timeout(600000), // 10 minutes timeout
                headers: headers
            };
            return fetch(url, newOptions);
        }
    }
});

export default supabase;
