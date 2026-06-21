import json

with open('/app/N8N PRIME/AGENTE ELMA V3_FINAL.json', 'r', encoding='utf-8') as f:
    workflow = json.load(f)

# Remover o modelo antigo (Google Gemini) se presente
novos_nodes = []
gemini_id = None
for node in workflow['nodes']:
    if node['name'] == 'Google Gemini Chat Model':
        gemini_id = node['id']
    else:
        novos_nodes.append(node)

# Adicionar o DeepSeek
deepseek_node = {
  "parameters": {
    "model": "deepseek-v4-flash",
    "options": {
      "temperature": 0.5
    }
  },
  "type": "@n8n/n8n-nodes-langchain.lmChatDeepSeek",
  "typeVersion": 1,
  "position": [
    -10976,
    1696
  ],
  "id": "2538be75-216e-4ea7-9217-4552828d3b66",
  "name": "DeepSeek Chat Model",
  "credentials": {
    "deepSeekApi": {
      "id": "jt14I0QFoOdSOdGr",
      "name": "DeepSeek account"
    }
  }
}
novos_nodes.append(deepseek_node)
workflow['nodes'] = novos_nodes

# Atualizar as conexões
if 'connections' in workflow:
    if 'Google Gemini Chat Model' in workflow['connections']:
        del workflow['connections']['Google Gemini Chat Model']

    workflow['connections']['DeepSeek Chat Model'] = {
        "ai_languageModel": [
            [
                {
                    "node": "AI Agent",
                    "type": "ai_languageModel",
                    "index": 0
                }
            ]
        ]
    }

with open('/app/N8N PRIME/AGENTE ELMA V3_FINAL.json', 'w', encoding='utf-8') as f:
    json.dump(workflow, f, indent=2, ensure_ascii=False)

print("DeepSeek inserido com sucesso.")
