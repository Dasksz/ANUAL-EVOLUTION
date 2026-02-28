with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

def get_block(start_str, end_str):
    s = content.find(start_str)
    e = content.find(end_str, s) + len(end_str)
    return content[s:e]

print("--- Main Dashboard Filters ---")
s = content.find('<!-- Filters Grid -->')
e = content.find('<!-- Main Dashboard Content -->')
print(content[s:e])

print("--- Caixas Filters ---")
s = content.find('<!-- Filters -->', content.find('<div id="boxes-view"'))
e = content.find('<!-- Trend Button -->', content.find('<div id="boxes-view"'))
print(content[s:e])
