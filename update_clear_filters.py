import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

# Locate the clearFiltersBtn event listener
pattern = r"""(clearFiltersBtn\.addEventListener\('click', async \(\) => \{\n\s+// Reset Single Selects\n\s+anoFilter\.value = 'todos';\n\s+mesFilter\.value = '';)"""

replacement = r"""\1

        // Update custom dropdown visual text
        if (anoFilter.nextElementSibling && anoFilter.nextElementSibling.tagName === 'BUTTON') {
            const span = anoFilter.nextElementSibling.querySelector('span');
            if (span) span.textContent = 'Todos';
        }
        if (mesFilter.nextElementSibling && mesFilter.nextElementSibling.tagName === 'BUTTON') {
            const span = mesFilter.nextElementSibling.querySelector('span');
            if (span) span.textContent = 'Todos';
        }"""

new_content = re.sub(pattern, replacement, content, count=1)

with open('src/js/app.js', 'w') as f:
    f.write(new_content)

print("Updated app.js")
