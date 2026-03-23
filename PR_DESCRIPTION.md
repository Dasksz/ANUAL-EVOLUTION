🔒 Fix potential XSS vulnerability in toast notifications

🎯 **What:**
Fixed a Cross-Site Scripting (XSS) vulnerability in the `showToast` function within `src/js/app.js`.

⚠️ **Risk:**
The previous implementation used `innerHTML` to directly insert the `message` and `finalTitle` variables into the DOM. This meant that if the application ever passed unescaped, malicious user input or untrusted API data to the toast notification function (e.g. `<script>alert('xss')</script>`), it would be executed by the browser, potentially leading to unauthorized actions or data theft.

🛡️ **Solution:**
Refactored the `showToast` implementation to construct the HTML structure using `innerHTML` with empty elements for the title and message. It then queries those elements and sets their content using `.textContent`. Using `textContent` automatically escapes HTML entities, neutralizing any potential malicious scripts while preserving the original layout and styles. Also updated the cache-busting query parameter in `index.html` to ensure clients load the corrected code.
