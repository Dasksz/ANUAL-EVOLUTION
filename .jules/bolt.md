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

## 2026-04-12 - Deferring RPC-based cache refreshes to a single batch call
**Learning:** Sequential network-bound RPC calls inside nested loops (e.g., refreshing filter caches per month/year) create significant O(N*M) latency bottlenecks.
**Action:** When a process involves multiple data-loading steps that require a subsequent cache refresh, defer the refresh until the end of the loop and trigger a single, parameterless global refresh RPC. This reduces network overhead and allows the database to perform the rebuild in a single, more efficient operation.
