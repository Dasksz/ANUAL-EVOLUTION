import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# I messed up the regex backreference or the string wasn't exactly that. Let's find exactly what it is.
pattern = r'class="bg-\[#151419\]/80 backdrop-blur-md border border-white/10 p-4 rounded-xl mb-6 shadow-lg"'
content = re.sub(pattern, 'class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-4 rounded-xl mb-6 shadow-lg relative z-[100]"', content)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Replacement complete")
