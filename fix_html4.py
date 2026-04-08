with open('index.html', 'r') as f:
    text = f.read()

# Let's count open/close divs between `<!-- Main Dashboard Content -->` and `<!-- Comparison View Placeholder -->`
# Because `main-dashboard-content` also needs to be closed. And `main-dashboard-view` needs to be closed.
try:
    content_block = text.split('<!-- Main Dashboard Content -->')[1].split('<!-- COMPARISON VIEW PLACEHOLDER -->')[0]
    open_c = content_block.count('<div')
    close_c = content_block.count('</div')
    print(f"Content Block: Open {open_c}, Close {close_c}")
except IndexError:
    print("Could not split by COMPARISON VIEW PLACEHOLDER")

# Try splitting by id="comparison-view"
content_block2 = text.split('<!-- Main Dashboard Content -->')[1].split('<div id="comparison-view"')[0]
open_c2 = content_block2.count('<div')
close_c2 = content_block2.count('</div')
print(f"Content Block 2: Open {open_c2}, Close {close_c2}")
