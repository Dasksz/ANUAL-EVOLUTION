with open('index.html', 'r') as f:
    lines = f.readlines()

# The script found the extra closing div at line 371 relative to block.
block_start = 0
for i, line in enumerate(lines):
    if '<div id="main-dashboard-view">' in line:
        block_start = i
        break

# Look for the extra closing div around block_start + 371
# It's at line 847 according to my previous script's counting.
# Let's just find the `<!-- Branch View Content -->` and look back a few lines.
