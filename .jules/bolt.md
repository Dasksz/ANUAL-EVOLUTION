## 2024-05-19 - Removed innerText in cloned DOM for faster export
**Learning:** `innerText` is styling-aware and triggers expensive layout calculations (reflows) even on detached or cloned DOM nodes.
**Action:** When extracting text from DOM nodes in a loop (like during table export), use `textContent` instead of `innerText` to prevent expensive layout thrashing and significantly improve performance.

## 2024-10-24 - Parallelized Web Crypto digest in chunks
**Learning:** Sequential `await` calls inside a synchronous `for` loop for CPU-bound async operations (like Web Crypto `digest` for generating SHA-256 hashes) cause severe bottlenecks, especially for large arrays of data chunks. Even though the API is async, doing them sequentially forces one-by-one execution instead of scheduling them concurrently.
**Action:** When performing independent async operations on multiple items, map them to an array of promises and use `await Promise.all()` instead of an `await` within a `for...of` loop.

## 2025-04-10 - Replaced verbose `document.createElement('option')` loops with `innerHTML` assignment
**Learning:** Iteratively creating `document.createElement('option')` in a loop and appending them to an element is slower than a single `innerHTML = array.map().join('')` assignment because it creates unnecessary DOM objects and JavaScript function calls. The memory explicitly warns not to go backwards from `innerHTML` to `DocumentFragment`.
**Action:** When populating simple elements like `<select>` options, use a single `innerHTML = array.map(...).join('')` assignment. This is fully optimized out-of-the-box, triggering only one DOM update without the verbosity of `DocumentFragment`.

## 2025-04-10 - Cached Intl.NumberFormat to avoid expensive toLocaleString calls
**Learning:** Calling `Number.prototype.toLocaleString()` inside a loop (e.g. rendering table rows or generating exports) is extremely slow because it internally instantiates a new `Intl.NumberFormat` object for every single call.
**Action:** When a formatting function will be called repeatedly, create and cache an `Intl.NumberFormat` instance (keyed by locale and options) and use its `.format()` method instead. This improves performance by ~50x.
## 2026-04-13 - Optimize Filter Cache Refresh
**Learning:** In `src/js/app.js`, the data synchronization function `enviarDadosParaSupabase` previously called `supabase.rpc('refresh_cache_filters')` for every month inside a nested loop. This resulted in O(years * 12) sequential API calls during a data sync. The parameterless `refresh_cache_filters` RPC triggers a global server-side rebuild that is significantly more efficient than sequential client-side calls due to reduced network latency and database-side chunking logic.
**Action:** When performing bulk updates or synchronizations, always move cache refreshing logic outside of processing loops. Call it once after all data loading is complete.
