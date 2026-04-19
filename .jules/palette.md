## 2025-02-12 - Ensure explicit focus-visible rings for keyboard navigation
**Learning:** Many buttons in the index.html file lacked explicit focus indicators, relying on default browser styles or completely hiding them. Tailwind's `ring` utilities automatically respect the element's existing border-radius (e.g. `rounded-lg`), so adding `focus-visible:rounded` is unnecessary and causes visual jank on focus by overriding the base border-radius.
**Action:** When adding focus rings to buttons using Tailwind, use `focus:outline-none focus-visible:ring-2 focus-visible:ring-[color]` and rely on the base class for the border-radius rather than adding explicit `focus-visible:rounded`.

## 2025-01-29 - Missing Focus Visible on Action Buttons
**Learning:** Some hidden action buttons like `#nav-uploader` or small clear buttons like `#lp-cliente-search-clear` lacked `focus-visible` outline styles, hurting keyboard accessibility.
**Action:** Always ensure all interactive elements receive a `focus-visible:ring-2` class even if they are initially hidden or dynamically shown.
