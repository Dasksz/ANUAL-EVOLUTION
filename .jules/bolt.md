## 2024-05-19 - Removed innerText in cloned DOM for faster export
**Learning:** `innerText` is styling-aware and triggers expensive layout calculations (reflows) even on detached or cloned DOM nodes.
**Action:** When extracting text from DOM nodes in a loop (like during table export), use `textContent` instead of `innerText` to prevent expensive layout thrashing and significantly improve performance.

## 2024-10-24 - Parallelized Web Crypto digest in chunks
**Learning:** Sequential `await` calls inside a synchronous `for` loop for CPU-bound async operations (like Web Crypto `digest` for generating SHA-256 hashes) cause severe bottlenecks, especially for large arrays of data chunks. Even though the API is async, doing them sequentially forces one-by-one execution instead of scheduling them concurrently.
**Action:** When performing independent async operations on multiple items, map them to an array of promises and use `await Promise.all()` instead of an `await` within a `for...of` loop.
