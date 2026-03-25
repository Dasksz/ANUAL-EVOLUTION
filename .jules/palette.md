# Palette Learnings

## 2026-03-25: Modal Table UX Improvements
To enhance readability and aesthetic appeal for dense data tables inside modals:
1. Use consistent icon systems (inline SVGs) in headers to quickly identify column types (e.g., Target, Person, Building).
2. Utilize Tailwind UI elements like semi-transparent colored backgrounds (`bg-indigo-500/10`) and text colors (`text-indigo-200`) to theme tables contextually based on the KPI type (Sellout = Indigo, Positivação = Emerald, Aceleradores = Amber).
3. Ensure parent containers have adequate max-widths (`max-w-5xl`) and avoid aggressive `whitespace-nowrap` if content clipping occurs, though for structured data `whitespace-nowrap` on a table with an `overflow-x-auto` wrapper ensures columns don't randomly wrap and break alignment.
4. Always provide an empty state layout with an icon when data is missing, instead of a blank space.
