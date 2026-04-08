with open('index.html', 'r') as f:
    text = f.read()

# Let's count open/close divs between `<!-- Main Dashboard Content -->` and `<!-- Branch View Content -->`
block = text.split('<!-- Main Dashboard Content -->')[1].split('<!-- Branch View Content -->')[0]
o = block.count('<div')
c = block.count('</div')
print(f"Content to Branch: Open {o}, Close {c}")
