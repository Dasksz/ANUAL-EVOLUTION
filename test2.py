with open('index.html', 'r') as f:
    text = f.read()

# Let's count EXACTLY <div and </div between main-dashboard-view and branch-view
block = text.split('<div id="main-dashboard-view">')[1].split('<div id="branch-view" class="hidden">')[0]
open_count = block.count('<div')
close_count = block.count('</div')

print(f"Open: {open_count}, Close: {close_count}")
