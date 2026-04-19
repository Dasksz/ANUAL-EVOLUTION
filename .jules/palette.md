## 2025-02-12 - Ensure explicit focus-visible rings for keyboard navigation
**Learning:** Many buttons in the index.html file lacked explicit focus indicators, relying on default browser styles or completely hiding them. Tailwind's `ring` utilities automatically respect the element's existing border-radius (e.g. `rounded-lg`), so adding `focus-visible:rounded` is unnecessary and causes visual jank on focus by overriding the base border-radius.
**Action:** When adding focus rings to buttons using Tailwind, use `focus:outline-none focus-visible:ring-2 focus-visible:ring-[color]` and rely on the base class for the border-radius rather than adding explicit `focus-visible:rounded`.

## 2025-01-29 - Missing Focus Visible on Action Buttons
**Learning:** Some hidden action buttons like `#nav-uploader` or small clear buttons like `#lp-cliente-search-clear` lacked `focus-visible` outline styles, hurting keyboard accessibility.
**Action:** Always ensure all interactive elements receive a `focus-visible:ring-2` class even if they are initially hidden or dynamically shown.
## 2025-04-18 - Ensure aria-expanded accurately reflects dropdown states
**Learning:** Dropdowns (like the profile menu) using Tailwind's `hidden` class to toggle visibility must dynamically update the `aria-expanded` attribute on their trigger buttons to properly inform screen readers of state changes.
**Action:** When implementing dropdown clickaway or toggle logic via Javascript, explicitly update `.setAttribute('aria-expanded', 'true'/'false')` on the controlling button concurrently with adding/removing the `hidden` class.
