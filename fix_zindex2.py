import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the one that didn't match
pattern2 = r'class="bg-\[#151419\]/80 backdrop-blur-md p-4 rounded-xl shadow-lg border border-white/10 mb-6"'
content = re.sub(pattern2, 'class="bg-[#151419]/80 backdrop-blur-md p-4 rounded-xl shadow-lg border border-white/10 mb-6 relative z-[100]"', content)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Replacement 2 complete")
