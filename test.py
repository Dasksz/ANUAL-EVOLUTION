# The user says "quando eu clico na pagina "Agenda" não acontece nada... Nem aparece nenhum erro no console"
# Wait!
# Did I add `agendaView` inside `resetViews` but not inside the `views` array?
# I checked the `views` array earlier:
# { id: 'agenda-view', navId: 'nav-agenda-btn', name: 'Agenda' }
# What about `setupMultiSelect`?
# In my `loadAgendaFilters` function I used `setupMultiSelect('agenda-supervisor-filter', ...)`
# `setupMultiSelect` takes parameters: `btn, dropdown, container, items, ...`
