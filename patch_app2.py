import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

# Fix sign in behavioral change
content = re.sub(
    r"const oldText = setElementLoading\(btnText \|\| btn, btn, 'Entrando\.\.\.', 'text-white'\);",
    r"const oldText = btnText ? setElementLoading(btnText, btn, 'Entrando...', 'text-white') : setElementLoading(btn, btn, 'Entrando...', 'text-white');",
    content
)

content = re.sub(
    r"restoreElementState\(btnText \|\| btn, btn, oldText\);",
    r"btnText ? restoreElementState(btnText, btn, oldText) : restoreElementState(btn, btn, oldText);",
    content
)

with open('src/js/app.js', 'w') as f:
    f.write(content)
