import re

with open('index.html', 'r') as f:
    html = f.read()

# At line 597/598 there is:
bad = """                                <div id="tipovenda-filter-dropdown" class="hidden absolute z-[999] w-max min-w-full max-w-[320px] mt-2 bg-[#1a1920]/95 backdrop-blur-md border border-white/10 rounded-xl shadow-2xl max-h-60 overflow-y-auto custom-scrollbar p-2"></div>
                            </div>

                                <div class="flex items-end h-[38px]"><button id="clear-filters-btn" aria-label="Limpar Filtros" class="w-[38px] h-[38px] bg-[#ff9800] hover:bg-orange-500 text-white rounded-lg flex items-center justify-center transition-colors shadow-lg shrink-0" title="Limpar Filtros"><svg aria-hidden="true" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 15l-6 6m0-6l6 6"></path></svg></button></div>
                            </div>
                        </div>
                    </div>"""

# One of these `</div>` before `<!-- Main Dashboard Content -->` is extra.
# Let's count:
# <div id="main-dashboard-header">
#   <header>...</header>
#   <div class="bg-[#151419]/80 ...">
#     <div class="flex flex-wrap items-end gap-3 mb-2">
#        <div (ano)></div>
#        <div (mes)></div>
#        ...
#        <div (tipovenda)></div>
#        <div (clearbtn)></div>
#     </div> (closes flex)
#   </div> (closes bg wrapper)
# </div> (closes main-dashboard-header)
# THEN main-dashboard-content starts.
# So we need exactly THREE </div> tags at the end of the filters.
# Let's see how many there are in the bad block:
# It has:
#                             </div> (closes tipovenda)
#                                 <div (clearbtn)></div>
#                             </div> (closes flex)
#                         </div> (closes bg wrapper)
#                     </div> (closes main-dashboard-header)
# That's three closing divs. That looks perfectly fine!
