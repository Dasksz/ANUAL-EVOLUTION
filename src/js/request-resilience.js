/* Retry only read operations. Never replay imports, edits, uploads or auth requests. */
(function (root) {
    function createDashboardReadFetch(baseFetch, getClient, projectUrl) {
        const origin = new URL(projectUrl).origin;
        let refreshInFlight = null;
        const wait = () => new Promise(resolve => setTimeout(resolve, 250));
        return async function dashboardReadFetch(input, options = {}) {
            const url = new URL(typeof input === 'string' ? input : input.url);
            const method = (options.method || input.method || 'GET').toUpperCase();
            const read = url.origin === origin && (
                (method === 'GET' && url.pathname.startsWith('/rest/v1/')) ||
                (method === 'POST' && /^\/rest\/v1\/rpc\/get_[a-z0-9_]+$/.test(url.pathname))
            );
            if (!read || options.signal?.aborted) return baseFetch(input, options);
            let response;
            try {
                response = await baseFetch(input, options);
            } catch (error) {
                if (!(error instanceof TypeError) || options.signal?.aborted) throw error;
                await wait();
                if (options.signal?.aborted) throw error;
                return baseFetch(input, options);
            }
            if (options.signal?.aborted) return response;
            if (response.status === 401) {
                const client = getClient();
                if (!client?.auth) return response;
                // Concurrent reads share one refresh. No valid session means no anonymous retry.
                if (!refreshInFlight) {
                    refreshInFlight = (async () => {
                        const current = await client.auth.getSession();
                        if (current.error || !current.data?.session) return null;
                        const refreshed = await client.auth.refreshSession();
                        return refreshed.error ? null : refreshed.data?.session?.access_token || null;
                    })().catch(() => null);
                    const pending = refreshInFlight;
                    pending.finally(() => { if (refreshInFlight === pending) refreshInFlight = null; });
                }
                const token = await refreshInFlight;
                if (!token || options.signal?.aborted) return response;
                const headers = new Headers(options.headers || (typeof input === 'object' ? input.headers : undefined));
                headers.set('Authorization', `Bearer ${token}`);
                return baseFetch(input, { ...options, headers });
            }
            if ([502, 503, 504].includes(response.status)) {
                await wait();
                if (!options.signal?.aborted) return baseFetch(input, options);
            }
            return response;
        };
    }
    root.createDashboardReadFetch = createDashboardReadFetch;
    if (typeof module !== 'undefined' && module.exports) module.exports = createDashboardReadFetch;
})(typeof window !== 'undefined' ? window : globalThis);
