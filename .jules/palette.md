## 2025-04-25 - Synced Tooltips for Toggle Buttons
**Learning:** For icon-only toggle buttons (like password visibility), setting an initial `aria-label` isn't enough for a complete UX, especially for mouse users who don't immediately recognize the icon. Adding a native HTML `title` attribute creates a helpful tooltip, but crucially, this `title` must be dynamically updated in javascript alongside the `aria-label` whenever the button's state changes.
**Action:** When creating stateful icon buttons, always set both `aria-label` and `title`, and ensure the JavaScript logic updates both attributes simultaneously.
## 2026-04-28 - Dynamic Title Tooltips for Disabled Buttons
**Learning:** Adding dynamic `title` tooltips to disabled buttons significantly improves UX/accessibility, allowing screen readers and mouse-users to understand *why* an action cannot be performed (e.g., 'Primeira página' for disabled 'Anterior'). However, when the state changes to enabled, these titles must be removed dynamically to avoid redundant hover tooltips when the action is obvious.
**Action:** When implementing disabled states for pagination or form buttons in `app.js`, use `setAttribute('title', 'reason')` when disabled and `removeAttribute('title')` when enabled.
## 2024-05-19 - Dropdown Options Truncation & Tooltips
**Learning:** Custom multi-select dropdown options with long names can break container layouts and become unreadable.
**Action:** Always apply text truncation (e.g., Tailwind's `truncate` class) and a native `title` attribute reflecting the full text to custom dropdown items. Additionally, propagate the selected text to the dropdown toggle button's `title` attribute for immediate context on hover.
