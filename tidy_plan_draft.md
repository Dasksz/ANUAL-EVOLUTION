Wait, extracting the `clearAllFilters` into a shared logic block might exceed 100 lines, because the arrays and wrappers are different for each.
Is there a simpler refactor that improves readability?

Look at `window.setupMultiSelect` taking 8 arguments:
```javascript
window.setupMultiSelect = function(btn, dropdown, container, items, selectedArray, labelCallback, isObject = false, searchInput = null)
```
And `setupDefaultMultiSelect`:
```javascript
function setupDefaultMultiSelect(btn, dropdown, container, items, selectedArray, searchInput = null, isObject = false) {
    return window.setupMultiSelect(btn, dropdown, container, items, selectedArray, () => {}, isObject, searchInput);
}
```
If we hoist `setupDefaultMultiSelect` directly below `window.setupMultiSelect`, it's exactly the kind of Tidy that cleans up structure (15 lines moved).
But wait! If I just hoist `setupDefaultMultiSelect`, that's simple and extremely safe, well under 100 lines, with no logic change!

Wait, another candidate:
Look at the `formatPercentage` inside `.map` or `toFixed(1)` usage.

What about fixing the class names passed to `enhanceSelectToCustomDropdown`?

Let's read the Tidy prompt again.
"Focus on ONE small (<100 lines) refactoring reducing repetition/improving readability without altering business logic."
"🧹 Move declared functions up so they aren't randomly floating inside components." (not explicitly listed, but "Dividir um arquivo" is).
"🧹 Extrair código duplicado para uma função utilitária compartilhada"

Let's see if we can create `resetDropdownsVisualState(prefix, defaultLabel)` to replace the duplicate blocks inside `clearAllFilters`.
