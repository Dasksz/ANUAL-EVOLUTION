import json

with open('/app/N8N PRIME/AGENTE ELMA V3_FINAL.json', 'r', encoding='utf-8') as f:
    workflow = json.load(f)

print("Nodes presentes:")
for node in workflow['nodes']:
    print(f"- {node['name']}")
    if node['name'] == 'Mestre_Busca_PRIME':
        print(f"  (Ferramenta nova encontrada)")
    if node['name'] == 'AI Agent':
        print(f"  (Prompt length: {len(node['parameters']['options']['systemMessage'])})")
