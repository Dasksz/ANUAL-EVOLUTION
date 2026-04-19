import re

with open("src/js/app.js", "r") as f:
    content = f.read()

# Make sure toast title and message uses textContent instead of textContent or innerHTML to prevent XSS
# Actually the toast implementation already uses textContent:
# toast.querySelector('.toast-title').textContent = finalTitle;
# toast.querySelector('.toast-message').textContent = message;
