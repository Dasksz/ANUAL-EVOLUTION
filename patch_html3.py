with open("index.html", "r") as f:
    content = f.read()

# Let's fix Sellout column so it looks exactly like the others.
# The `Meus KPI's` card:

#         <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
#             <div>
#                 <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Meus KPI's</h2>
#
#                 <div class="flex flex-col h-full"> ...

# Let's replace the whole `Meus KPI's` section to make sure it's correct.

old_meus_kpi = """        <!-- Meus KPI's -->
        <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
            <div>
                <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Meus KPI's</h2>

                <div class="flex flex-col h-full">
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
            </div>
        </div>"""

new_meus_kpi = """        <!-- Meus KPI's -->
        <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
            <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Meus KPI's</h2>

            <div class="flex flex-col flex-1">
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

# Wait, in the right column ("Resultado da equipe"), how is the "Positivação" card styled?
#         <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
#             <div> <!-- Notice this div wrapper for the whole content minus the spacing placeholder -->
#                 <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Resultado da equipe</h2>
#
#                 <div class="grid grid-cols-1 sm:grid-cols-2 gap-8">
#                     <!-- Positivação -->
#                     <div class="flex flex-col h-full"> ...

# Wait, let's look closely at `Positivação` in "Resultado da equipe"
#                     <!-- Positivação -->
#                     <div>
#                         <h3 class="text-lg font-bold text-blue-400 mb-2">Positivação</h3>
# ...
#                     </div>

# Positivação is just a `<div>`. But it uses `mt-auto`. The only way `mt-auto` works is if its parent is flex. The `grid grid-cols-1 sm:grid-cols-2` itself doesn't make children flex-col. But wait! Wait, `mt-auto` inside a standard block `div` doesn't do bottom alignment. It just acts as `mt-0`. However, the right column doesn't need to push to bottom *unless* they differ in height. Wait, there is a placeholder at the bottom of the right column:
#             <!-- Spacing placeholder to match left side button -->
#             <div class="mt-4 pt-3 h-[48px]"></div>

# Wait, they added a placeholder `div` to match the left side button's height!?
# But my change on the left side might change its height. Let's make both sides use proper `flex-col` so they naturally align.

old_pos = """                    <!-- Positivação -->
                    <div>
                        <h3 class="text-lg font-bold text-blue-400 mb-2">Positivação</h3>"""

new_pos = """                    <!-- Positivação -->
                    <div class="flex flex-col h-full">
                        <h3 class="text-lg font-bold text-blue-400 mb-2">Positivação</h3>"""

old_acel = """                    <!-- Aceleradores -->
                    <div>
                        <h3 class="text-lg font-bold text-blue-400 mb-2">Aceleradores</h3>"""

new_acel = """                    <!-- Aceleradores -->
                    <div class="flex flex-col h-full">
                        <h3 class="text-lg font-bold text-blue-400 mb-2">Aceleradores</h3>"""

# Also fix the right column wrapper to have h-full on the grid so flex columns can stretch
old_grid = """                <div class="grid grid-cols-1 sm:grid-cols-2 gap-8">"""
new_grid = """                <div class="grid grid-cols-1 sm:grid-cols-2 gap-8 h-full">"""

# Let's write the whole file with these cleanups.
content = content.replace(old_meus_kpi, new_meus_kpi)
content = content.replace(old_pos, new_pos)
content = content.replace(old_acel, new_acel)
content = content.replace(old_grid, new_grid)

# Also let's check the spacing placeholder on the right side.
#             <!-- Spacing placeholder to match left side button -->
#             <div class="mt-4 pt-3 h-[48px]"></div>
# We probably don't need this placeholder anymore since the buttons are aligned, but actually on the left there is only 1 KPI and on the right there are 2. So the buttons on the right *are* the buttons that need alignment. The placeholder was there because the left side had the button outside the KPI content block, but now I put it *inside* the flex column of the left side. So the left button is at the bottom, and the right buttons are at the bottom of their respective flex columns. We should remove the placeholder.

old_placeholder = """            <!-- Spacing placeholder to match left side button -->
            <div class="mt-4 pt-3 h-[48px]"></div>"""
content = content.replace(old_placeholder, "")

# Wait, the right column parent also needs `flex-1` or `h-full` to stretch if it's in a flex row? No, it's a grid row: `grid grid-cols-1 lg:grid-cols-2 gap-6`. So they automatically stretch to equal height.
# Then inside, `bg-[#151419]/80 flex flex-col justify-between`.
# The right side:
#         <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
#             <div class="flex flex-col h-full">
#                 <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Resultado da equipe</h2>
#                 <div class="grid grid-cols-1 sm:grid-cols-2 gap-8 h-full">

old_right_wrapper = """        <!-- Resultado da equipe -->
        <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
            <div>
                <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10">Resultado da equipe</h2>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-8 h-full">"""

new_right_wrapper = """        <!-- Resultado da equipe -->
        <div class="bg-[#151419]/80 backdrop-blur-md border border-white/10 p-6 rounded-xl shadow-lg flex flex-col justify-between">
            <div class="flex flex-col h-full">
                <h2 class="text-xl font-bold text-white mb-6 pb-2 border-b border-white/10 shrink-0">Resultado da equipe</h2>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-8 flex-1">"""

content = content.replace(old_right_wrapper, new_right_wrapper)

with open("index.html", "w") as f:
    f.write(content)

print("Final HTML patched")
