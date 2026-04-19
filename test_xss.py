import re

with open("src/js/app.js", "r") as f:
    content = f.read()

print("--- 6667 ---")
print(content.splitlines()[6620:6630])
