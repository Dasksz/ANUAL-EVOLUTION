import json

# Carregar o workflow V3 (que já tem o novo prompt e ferramentas antigas)
with open('/app/N8N PRIME/AGENTE ELMA V3.json', 'r', encoding='utf-8') as f:
    workflow = json.load(f)

nova_ferramenta = {
  "parameters": {
    "descriptionType": "manual",
    "toolDescription": "FERRAMENTA PRINCIPAL DA ELMA V2\n\nUse esta ferramenta para consultar TODOS os dados dos clientes e colaboradores, de forma consolidada.\n\nInstruções:\n1. Sempre passe a 'opcao' desejada pelo usuário (veja abaixo).\n2. Passe 'cpf' apenas se o usuário forneceu.\n3. Passe 'codigo_cliente' apenas se o usuário forneceu.\n4. Para 'setor_transferencia', só envie se a intenção for transferir (opcao 8).\n\nOpções disponíveis:\n1 = Cadastro de Cliente\n2 = Histórico de Pedidos\n3 = Consultar Pedido Específico\n4 = Inovações\n5 = Mix Ideal\n6 = Sugestão de Pedido\n7 = Consultar Estoque\n8 = Transferir Atendimento\n",
    "operation": "getAll",
    "tableId": "n8n_agent_view_v2",
    "limit": 50,
    "filterType": "string",
    "filterString": "={{   [     $fromAI(\"opcao\") ? `opcao=eq.${$fromAI(\"opcao\")}` : \"\",     $fromAI(\"cpf\") ? `cpf=eq.${$fromAI(\"cpf\")}` : \"\",     $fromAI(\"codigo_cliente\") ? `codigo_cliente=eq.${$fromAI(\"codigo_cliente\")}` : \"\",     $fromAI(\"setor_transferencia\") ? `setor_transferencia=eq.${$fromAI(\"setor_transferencia\")}` : \"\"   ].filter(x => x !== \"\").join(\"&\") || \"opcao=is.null\" }}"
  },
  "type": "n8n-nodes-base.supabaseTool",
  "typeVersion": 1,
  "position": [
    -10192,
    1696
  ],
  "id": "9fdf85f5-a7a7-48c4-a3b5-ef1231038d97",
  "name": "Mestre_Busca_PRIME",
  "credentials": {
    "supabaseApi": {
      "id": "UZvmJzBqXrtqsGRh",
      "name": "Supabase account"
    }
  }
}

# Listar ferramentas antigas para remover do V3
ferramentas_para_remover = [
    'Consultar_Cadastro_Cliente',
    'Master_Busca_PRIME', # o antigo
    'Consultar_Mix_Ideal',
    'Consultar_relação_inovações',
    'Consultar_Historico_Frequencia',
    'Consultar_Inovacao_Mes_Atual',
    'Consultar_Filial_Cidade',
    'Consultar_Catalogo_Produtos'
]

# Remover ferramentas antigas do V3
novos_nodes = []
for node in workflow['nodes']:
    if node['name'] not in ferramentas_para_remover:
        novos_nodes.append(node)

# Adicionar a nova ferramenta consolidada Mestre_Busca_PRIME
novos_nodes.append(nova_ferramenta)

workflow['nodes'] = novos_nodes

# Atualizar as conexões do AI Agent
# Remover conexões das ferramentas antigas e adicionar a nova
if 'connections' in workflow:
    for tool in ferramentas_para_remover:
        if tool in workflow['connections']:
            del workflow['connections'][tool]

    # Adicionar a nova conexão para Mestre_Busca_PRIME
    workflow['connections']['Mestre_Busca_PRIME'] = {
        "ai_tool": [
            [
                {
                    "node": "AI Agent",
                    "type": "ai_tool",
                    "index": 0
                }
            ]
        ]
    }

with open('/app/N8N PRIME/AGENTE ELMA V3.json', 'w', encoding='utf-8') as f:
    json.dump(workflow, f, indent=2, ensure_ascii=False)

print("Ferramentas atualizadas com sucesso no V3.")
