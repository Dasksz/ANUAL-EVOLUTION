with open("index.html", "r") as f:
    content = f.read()

search = """                    <div class="w-full bg-slate-700/50 rounded-full h-4 mb-2 overflow-hidden flex relative items-center">
                        <div id="sellout-pdb-bar" class="bg-emerald-500 h-4 rounded-full transition-all duration-1000" style="width: 0%"></div>
                        <span class="absolute right-2 text-[10px] font-bold text-white mix-blend-difference" id="sellout-pdb-pct">0%</span>
                        <span class="absolute left-2 text-[10px] font-bold text-white mix-blend-difference">Total PDB</span>
                    </div>

                </div>
            </div>

            <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>
        </div>"""

replace = """                    </div>

                    <div class="mt-auto">
                        <div class="flex justify-between items-center mb-1">
                            <span class="text-xs font-bold text-slate-300">Realizado vs Meta</span>
                            <span class="text-xs font-bold text-emerald-400" id="sellout-pdb-pct">0%</span>
                        </div>
                        <div class="w-full bg-slate-700/50 rounded-full h-3 overflow-hidden flex relative items-center">
                            <div id="sellout-pdb-bar" class="bg-emerald-500 h-3 rounded-full transition-all duration-1000" style="width: 0%"></div>
                        </div>
                    </div>

                    <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>

                </div>
            </div>
        </div>"""

# Note the enclosing div structure:
# Right now it's:
# <div class="mb-6">
#     <h3>...</h3>
#     <div class="space-y-1 mb-4">...</div>
#     <div class="w-full bg-slate-700/50...">...</div> <!-- We replace this part -->
# </div>
# But wait, to make `mt-auto` work, its parent must be `flex flex-col` and have height.
# In "Positivação", it is:
# <div>
#     <h3>...</h3>
#     <div class="space-y-1 mb-4">...</div>
#     <div class="mt-auto">...bar...</div>
#     <button>...
# </div>
# So we need to restructure Sellout to match this exact structure:

search_2 = """                <div class="mb-6">
                    <h3 class="text-lg font-bold text-blue-400 mb-2">Sellout</h3>
                    <div class="space-y-1 mb-4">
                        <p class="text-sm text-slate-300 font-medium">Meta: <span id="sellout-meta-val" class="font-normal text-slate-400">0.00 tons</span></p>
                        <p class="text-sm text-white font-bold">Realizado: <span id="sellout-realizado-val" class="text-white">0.00 tons</span></p>
                        <p class="text-sm text-emerald-400 font-medium mt-2">Sell out salty: <span id="sellout-salty-val" class="text-emerald-300">0.00</span></p>
                        <p class="text-sm text-emerald-400 font-medium">Sell out foods: <span id="sellout-foods-val" class="text-emerald-300">0.00</span></p>
                    </div>

                    <div class="w-full bg-slate-700/50 rounded-full h-4 mb-2 overflow-hidden flex relative items-center">
                        <div id="sellout-pdb-bar" class="bg-emerald-500 h-4 rounded-full transition-all duration-1000" style="width: 0%"></div>
                        <span class="absolute right-2 text-[10px] font-bold text-white mix-blend-difference" id="sellout-pdb-pct">0%</span>
                        <span class="absolute left-2 text-[10px] font-bold text-white mix-blend-difference">Total PDB</span>
                    </div>

                </div>
            </div>

            <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>"""


replace_2 = """                <div class="flex flex-col h-full">
                    <h3 class="text-lg font-bold text-blue-400 mb-2">Sellout</h3>
                    <div class="space-y-1 mb-4">
                        <p class="text-sm text-slate-300 font-medium">Meta: <span id="sellout-meta-val" class="font-normal text-slate-400">0.00 tons</span></p>
                        <p class="text-sm text-white font-bold">Realizado: <span id="sellout-realizado-val" class="text-white">0.00 tons</span></p>
                        <p class="text-sm text-emerald-400 font-medium mt-2">Sell out salty: <span id="sellout-salty-val" class="text-emerald-300">0.00</span></p>
                        <p class="text-sm text-emerald-400 font-medium">Sell out foods: <span id="sellout-foods-val" class="text-emerald-300">0.00</span></p>
                    </div>

                    <div class="mt-auto">
                        <div class="flex justify-between items-center mb-1">
                            <span class="text-xs font-bold text-slate-300">Realizado vs Meta</span>
                            <span class="text-xs font-bold text-emerald-400" id="sellout-pdb-pct">0%</span>
                        </div>
                        <div class="w-full bg-slate-700/50 rounded-full h-3 overflow-hidden flex relative items-center">
                            <div id="sellout-pdb-bar" class="bg-emerald-500 h-3 rounded-full transition-all duration-1000" style="width: 0%"></div>
                        </div>
                    </div>

                    <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>
                </div>
            </div>"""

if search_2 in content:
    content = content.replace(search_2, replace_2)
    with open("index.html", "w") as f:
        f.write(content)
    print("Patched successfully")
else:
    print("Search string not found")
