with open("index.html", "r") as f:
    content = f.read()

# Wait, in the Meus KPI's block, there is an extra `</div>` at the end which closes the column block, but the button should be outside the div?
# Let's verify original structure:
#         <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
#             <div>
#                 <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Meus KPI's</h2>
#
#                 <div class="mb-6">
# ...
#                 </div>
#             </div>
#
#             <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>
#         </div>

# The way I replaced it:
#                 <div class="flex flex-col h-full">
# ...
#                     <button onclick="openDetalhadoModal('sellout')" class="w-full text-xs text-blue-400 hover:text-blue-300 underline font-bold py-2 mt-4 text-center block">Resultado detalhado</button>
#                 </div>
#             </div>
#         </div>

# The button is now inside the inner div. Let's make sure `flex flex-col h-full` works.
# Let's check "Resultado da equipe" Positivição structure to see how it works there.

search_pos = """                    <!-- Positivação -->
                    <div>
                        <h3 class="text-lg font-bold text-blue-400 mb-2">Positivação</h3>
                        <div class="space-y-1 mb-4">
                            <p class="text-sm text-slate-300 font-medium">Meta: <span id="pos-meta-val" class="font-normal text-slate-400">0 PDV(s)</span></p>
                            <p class="text-sm text-white font-bold">Realizado (Salty): <span id="pos-realizado-salty-val" class="text-white">0 PDV(s)</span></p>
                            <p class="text-sm text-emerald-400 font-medium mt-1">Foods: <span id="pos-realizado-foods-val" class="text-emerald-300">0 PDV(s)</span></p>
                            <p class="text-sm text-slate-300 font-medium mt-2">Pontos possíveis: <span id="pontos-possiveis-pos" class="text-white font-bold">0</span></p>
                        </div>

                        <div class="mt-auto">"""

# For Positivação, it is:
# <div> (col cell)
#   <h3>
#   <div space-y-1>...
#   <div mt-auto> ... bar ... </div>
#   <button> ... </button>
# </div>

# But wait, in Positivação, the col cell is just `<div>`. The reason `mt-auto` pushes it to the bottom is if the parent is a flex column. `grid-cols-2` might not make the children flex columns by default unless it's specified, or maybe it just happens to sit at the bottom naturally. Wait, "Resultado da equipe" right container:
#         <!-- Resultado da equipe -->
#         <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
#             <div>
#                 <h2 class="...">Resultado da equipe</h2>
#                 <div class="grid grid-cols-1 sm:grid-cols-2 gap-8 flex-1"> <!-- Is it flex-1? No, just grid -->
#                     <!-- Positivação -->
#                     <div class="flex flex-col h-full">... <!-- Wait, Positivação is just `<div>` -->
