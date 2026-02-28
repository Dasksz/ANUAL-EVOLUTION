import sys

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# I already modified index.html, let's restore it first to make sure I get clean diff
