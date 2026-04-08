import re

with open('index.html', 'r') as f:
    html = f.read()

# At line 847, there is a `</div>` followed by another `</div>`.
# Let's count back exactly what's open.
# `main-dashboard-content` (open at 604)
#   `<div class="grid ...` (open at 605)
#     `<div class="kpi-card ...` (606) ... `</div>` (638)
#   `</div>` (closes grid) -- wait, does it?
# Let's just fix it by matching the divs. The fact that the user showed the layout completely stacked vertically and the branch-view/comparison-view showing on the same page means `main-dashboard-view` is NOT getting `display: none` effectively, or it IS, but the content fell out of it.
# Actually, if `main-dashboard-view` fell short, it means there are TOO MANY closing divs inside it.
# "Content to Branch: Open 64, Close 65"
# Yes! `main-dashboard-content` has an EXTRA `</div>`.
# But wait, `main-dashboard-view` ALSO needs a closing `</div>`.
# So if we have `main-dashboard-view` (open) -> `main-dashboard-content` (open), we should have exactly TWO more closing divs than opening divs inside this block? No, `main-dashboard-content` should be closed inside `main-dashboard-view`.

# Let's analyze the whole `main-dashboard-view` block:
block = html.split('<div id="main-dashboard-view">')[1].split('<!-- Branch View Content -->')[0]
print(f"main-dashboard-view to Branch: Open {block.count('<div')}, Close {block.count('</div')}")

# If Close - Open == 0, then `main-dashboard-view` was perfectly closed right before `Branch View Content`.
# If Close > Open, it closed TOO EARLY.
