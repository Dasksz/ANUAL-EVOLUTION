import re
import time

with open('index.html', 'r') as f:
    content = f.read()

new_v = str(int(time.time() * 1000))
new_content = re.sub(r'(src/js/app\.js\?v=)\d+', r'\g<1>' + new_v, content)

with open('index.html', 'w') as f:
    f.write(new_content)

print(f"Bumped version to {new_v}")
