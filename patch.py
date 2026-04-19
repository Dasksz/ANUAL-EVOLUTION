import re

with open("src/js/utils.js", "r") as f:
    content = f.read()

new_content = re.sub(
    r'export function setElementLoading\(target, btn, loadingText, extraClasses = \'\'\) \{',
    "export function setElementLoading(target, btn, loadingText, extraClasses = '') {\n    // Ensure loadingText is escaped to prevent DOM XSS",
    content
)

with open("src/js/utils.js", "w") as f:
    f.write(new_content)
