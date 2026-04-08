import re

with open('index.html', 'r') as f:
    html = f.read()

# Since `Close` is 98 and `Open` is 97 inside the block, there is an EXTRA `</div>` somewhere between `<div id="main-dashboard-view">` and `<!-- Branch View Content -->`.
# And this extra `</div>` was probably introduced by my previous edits.
# Let's find exactly where it is by counting cumulatively.

block = html.split('<div id="main-dashboard-view">')[1].split('<!-- Branch View Content -->')[0]

lines = block.split('\n')
open_c = 0
close_c = 0
for i, line in enumerate(lines):
    open_c += line.count('<div')
    close_c += line.count('</div')
    if close_c > open_c:
        print(f"Extra closing div at line {i} relative to block. Text: {line.strip()}")
        break

# I suspect it's at the end of the filters where I had `</div>` tags.
