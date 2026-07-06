import re

with open('src/js/utils.js', 'r') as f:
    content = f.read()

# Remove the unused updateEl function
pattern = r"\/\*\*\n \* Safely updates text content or style of a DOM element\..*?export function updateEl[^\}]+?\n\}"
content = re.sub(pattern, "", content, flags=re.DOTALL)

with open('src/js/utils.js', 'w') as f:
    f.write(content)
print("Removed updateEl from utils.js")
