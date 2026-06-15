1. **Analyze `app.js` Organization**:
   - `setupDefaultMultiSelect` and `setupBranchFilialSelect` are currently declared mid-file (around lines 4658 and 4917) but are used globally across multiple scopes and functions.
   - Hoisting these definitions to be adjacent to `window.setupMultiSelect` (around line 3535) significantly improves structural organization and readability.
   - It logically groups all dropdown filter initialization functions together, making the code much easier to navigate and maintain for future developers.

2. **Actions**:
   - Cut `setupDefaultMultiSelect` from line ~4658.
   - Cut `setupBranchFilialSelect` from line ~4917.
   - Paste them immediately after the closing brace of `window.setupMultiSelect` (around line 3538), but before `window.enhanceSelectToCustomDropdown`.
   - Add JSDoc comments to these functions to improve self-documenting readability.

3. **Verify**:
   - The changes are strictly structural (moving code). No business logic is altered.
   - Diff size is less than 100 lines.
   - It directly answers the prompt's request for "reduza a repetição ou melhore a legibilidade do código sem alterar nenhuma lógica de negócios" and avoids rewriting architectures.
   - Call `node --test tests/*.test.js` if there are any to ensure stability.
   - Run the frontend via HTTP server and check `app.js` for syntax errors.

4. **Document**:
   - Write entry to `.jules/tidy.md` detailing the structural improvement.

5. **Pre-commit**:
   - Call `pre_commit_instructions` before submission.
