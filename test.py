with open('index.html', 'r') as f:
    lines = f.readlines()

stack = []
for i, line in enumerate(lines[475:851]):  # main-dashboard-view starts at 476 (idx 475)
    if '<div' in line:
        stack.append(i+476)
    if '</div' in line:
        if stack:
            stack.pop()
        else:
            print(f"Extra closing div at line {i+476}")

print(f"Unclosed div tags count: {len(stack)}")
