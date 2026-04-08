import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

old_innov = """    const rpcFilters = {
        p_ano: filters.p_ano || null,
        p_mes: filters.p_mes || null,
        p_filial: filters.p_filial.length ? filters.p_filial : null,
        p_cidade: filters.p_cidade.length ? filters.p_cidade : null,
        p_supervisor: filters.p_supervisor.length ? filters.p_supervisor : null,
        p_vendedor: filters.p_vendedor.length ? filters.p_vendedor : null,
        p_rede: filters.p_rede.length ? filters.p_rede : null,
        p_tipovenda: filters.p_tipovenda.length ? filters.p_tipovenda : null,
        p_categoria_inovacao: filters.p_categoria_inovacao && filters.p_categoria_inovacao.length ? filters.p_categoria_inovacao[0] : null, // Categoria Inovacao was a text param
        p_codcli: filters.p_codcli || null
    };"""

new_innov = """    const rpcFilters = {
        p_filial: filters.p_filial.length ? filters.p_filial : null,
        p_cidade: filters.p_cidade.length ? filters.p_cidade : null,
        p_supervisor: filters.p_supervisor.length ? filters.p_supervisor : null,
        p_vendedor: filters.p_vendedor.length ? filters.p_vendedor : null,
        p_rede: filters.p_rede.length ? filters.p_rede : null,
        p_tipovenda: filters.p_tipovenda.length ? filters.p_tipovenda : null,
        p_categoria_inovacao: filters.p_categoria_inovacao && filters.p_categoria_inovacao.length ? filters.p_categoria_inovacao[0] : null,
        p_ano: filters.p_ano || null,
        p_mes: filters.p_mes || null,
        p_codcli: filters.p_codcli || null
    };"""

content = content.replace(old_innov, new_innov)

with open('src/js/app.js', 'w') as f:
    f.write(content)
print("done")
