import re

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the end of loja-perfeita-view. It ends just before `</div>\n            </main>`
# Alternatively, we can find the exact placeholder.
search_str = '<!-- LOJA PERFEITA VIEW PLACEHOLDER -->'
start_idx = content.find(search_str)
if start_idx == -1:
    print("Could not find LOJA PERFEITA VIEW PLACEHOLDER")
    exit(1)

# Find the matching closing div for loja-perfeita-view
# We can search for the end of the <div id="loja-perfeita-view"...
loja_perf_str = '<div id="loja-perfeita-view"'
lp_idx = content.find(loja_perf_str)

if lp_idx == -1:
    print("Could not find loja-perfeita-view")
    exit(1)

# Count divs to find the end
div_count = 0
in_div = False
end_idx = -1
i = lp_idx
while i < len(content):
    if content[i:i+4] == '<div':
        div_count += 1
        in_div = True
    elif content[i:i+6] == '</div>':
        div_count -= 1

    if in_div and div_count == 0:
        end_idx = i + 6
        break
    i += 1

if end_idx == -1:
    print("Could not find the end of loja-perfeita-view")
    exit(1)

estrelas_html = """
<!-- ESTRELAS VIEW PLACEHOLDER -->
<div id="estrelas-view" class="hidden container mx-auto p-4 max-w-7xl animate-fade-in-up">
    <header class="mb-8 border-b border-slate-700/50 pb-4 flex justify-between items-end">
        <div>
            <h1 class="text-3xl font-bold text-white mb-1">Estrelas</h1>
            <p class="text-slate-400">Indicadores Pepsico</p>
        </div>
    </header>

    <!-- Filters Section -->
    <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-4 rounded-xl mb-6 shadow-lg relative z-[100]">
        <div class="flex flex-wrap items-end gap-3 mb-2" id="estrelas-filters-container">

            <div class="flex-1 min-w-[140px] relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Ano</label>
                <div class="relative w-full">
                    <select id="estrelas-ano-filter" class="w-full bg-white/5 border border-white/10 rounded-lg p-2 text-sm text-slate-300 h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 appearance-none">
                        <option value="todos">Todos</option>
                    </select>
                </div>
            </div>

            <div class="flex-1 min-w-[140px] relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Mês</label>
                <div class="relative w-full">
                    <select id="estrelas-mes-filter" class="w-full bg-white/5 border border-white/10 rounded-lg p-2 text-sm text-slate-300 h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 appearance-none">
                        <option value="">Todos</option>
                    </select>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Filial</label>
                <button id="estrelas-filial-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todas</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-filial-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2"></div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Cidade</label>
                <button id="estrelas-cidade-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todas</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-cidade-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2">
                    <input type="text" id="estrelas-cidade-filter-search" placeholder="Buscar..." aria-label="Buscar filtro"  class="w-[200px] sm:w-full bg-white/5 text-slate-300 text-xs p-2 mb-2 rounded border border-white/10 focus:outline-none focus:border-orange-500 placeholder-slate-500">
                    <div id="estrelas-cidade-filter-list"></div>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Supervisor</label>
                <button id="estrelas-supervisor-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todos</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-supervisor-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2"></div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Vendedor</label>
                <button id="estrelas-vendedor-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todos</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-vendedor-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2">
                    <input type="text" id="estrelas-vendedor-filter-search" placeholder="Buscar..." aria-label="Buscar filtro"  class="w-[200px] sm:w-full bg-white/5 text-slate-300 text-xs p-2 mb-2 rounded border border-white/10 focus:outline-none focus:border-orange-500 placeholder-slate-500">
                    <div id="estrelas-vendedor-filter-list"></div>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Fornecedor</label>
                <button id="estrelas-fornecedor-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todos</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-fornecedor-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2">
                    <input type="text" id="estrelas-fornecedor-filter-search" placeholder="Buscar..." aria-label="Buscar filtro"  class="w-[200px] sm:w-full bg-white/5 text-slate-300 text-xs p-2 mb-2 rounded border border-white/10 focus:outline-none focus:border-orange-500 placeholder-slate-500">
                    <div id="estrelas-fornecedor-filter-list"></div>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Categoria</label>
                <button id="estrelas-categoria-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todas</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-categoria-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2">
                    <input type="text" id="estrelas-categoria-filter-search" placeholder="Buscar..." aria-label="Buscar filtro"  class="w-[200px] sm:w-full bg-white/5 text-slate-300 text-xs p-2 mb-2 rounded border border-white/10 focus:outline-none focus:border-orange-500 placeholder-slate-500">
                    <div id="estrelas-categoria-filter-list"></div>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Rede</label>
                <button id="estrelas-rede-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todas</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-rede-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2">
                    <input type="text" id="estrelas-rede-filter-search" placeholder="Buscar..." aria-label="Buscar filtro"  class="w-[200px] sm:w-full bg-white/5 text-slate-300 text-xs p-2 mb-2 rounded border border-white/10 focus:outline-none focus:border-orange-500 placeholder-slate-500">
                    <div id="estrelas-rede-filter-list"></div>
                </div>
            </div>

            <div class="relative">
                <label class="text-[11px] font-bold text-slate-500 uppercase tracking-wider block mb-1">Tipo Venda</label>
                <button id="estrelas-tipovenda-filter-btn" aria-haspopup="listbox" aria-expanded="false" class="w-full bg-white/5 border border-white/10 text-slate-300 text-sm rounded-lg p-2 text-left flex justify-between items-center h-[38px] hover:bg-white/10 transition-colors focus:outline-none focus:ring-1 focus:ring-orange-500 min-w-[140px]">
                    <span class="truncate">Todos</span>
                    <svg class="w-3 h-3 text-slate-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                <div id="estrelas-tipovenda-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2"></div>
            </div>

            <div class="ml-auto flex justify-end items-end gap-3">
                <button aria-label="Limpar Filtros Estrelas" onclick="clearAllFilters('estrelas')" class="bg-orange-500 hover:bg-orange-600 text-white p-2 rounded-lg transition-colors flex items-center justify-center h-[38px] w-[38px]" title="Limpar Filtros">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"></path><line x1="4" y1="4" x2="20" y2="20" stroke="currentColor" stroke-width="2" stroke-linecap="round"></line></svg>
                </button>
            </div>
        </div>
    </div>
</div>
"""

new_content = content[:end_idx] + '\n' + estrelas_html + content[end_idx:]

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Added estrelas view")
