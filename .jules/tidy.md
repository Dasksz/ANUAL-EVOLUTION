## 2024-05-24 : (Padronização de Strings)
**Aprendizado:** Quando houverem mapeamentos dependentes de strings externas como nomes de municípios e cidades na aplicação (`src/js/worker.js`), evitar usar apenas `.trim().toUpperCase()` pois letras acentuadas (ex: `ILHÉUS`) causam desintegração nos relacionamentos do banco de dados (RLS/JOINs), especialmente com strings vindas de diferentes planilhas e fontes (IBGE, etc).
**Ação:** Criada utilidade `normalizeCityName(city)` baseada em `.normalize("NFD").replace(/[\u0300-\u036f]/g, "")` para normalizar globalmente os nomes de cidades, unificando os mapeamentos de configuração (`config_city_branches`).
## 2024-05-25 : (Extração de lógica de Dropdowns Absolutos)
**Aprendizado:** A lógica de iterar sobre `.absolute.z-[50], .absolute.z-[999]` para esconder dropdowns (via remoção da classe `hidden`) estava duplicada 5 vezes e era difícil de manter ou extender se novas classes de z-index fossem adicionadas.
**Ação:** Foi criada uma função utilitária `closeAllDropdowns()` em `src/js/utils.js` que centraliza essa query e fechamento, evitando repetição de código em `src/js/app.js`.
## 2024-05-26 : (Consolidação de Múltiplos Selects)
**Aprendizado:** Haviam três funções praticamente idênticas para a criação de menus de seleção múltipla no frontend (`setupMultiSelect`, `setupCityMultiSelect`, `setupBranchMultiSelect`). Isso resultava em mais de 300 linhas de código duplicadas, difíceis de manter.
**Ação:** Refatorei substituindo as implementações específicas (`setupCityMultiSelect` e `setupBranchMultiSelect`) por chamadas repassadas à função base `setupMultiSelect`. A função base recebeu validações extras de segurança contra elementos nulos, absorvendo o que havia de único nas outras implementações.
