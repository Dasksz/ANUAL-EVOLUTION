import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure all filter buttons use z-[999] in case the string replace failed on something
content = content.replace('z-[50]', 'z-[999]')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Checked z-index again.")
