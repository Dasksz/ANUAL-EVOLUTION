with open("src/js/app.js", "r") as f:
    js = f.read()

# Let's check `isAgendaInitialized`. It is declared globally.
# I had already written all the JS functions for Agenda:
# `loadAgendaFilters`, `setupAgendaFilters`, `renderAgendaView`, `updateAgendaView`.
# They are there. Are there any logic errors?
# "Quando clico na pagina Agenda não acontece nada"
# That is caused by `navAgendaBtn` not having the event listener bound correctly.
