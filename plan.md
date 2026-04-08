1. **Analyze `src/js/utils.js` & `src/js/app.js`**: Identify duplicated hardcoded data. We found that month names are duplicated multiple times in `src/js/app.js`.
2. **Move Magic Strings to Constants**: Define constants for month names in `src/js/utils.js`.
   - `export const MONTHS_PT = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];`
   - `export const MONTHS_PT_SHORT = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];`
   - `export const MONTHS_PT_INITIALS = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];`
3. **Import and Replace in `app.js`**:
   - Update `app.js` imports from `./utils.js` to include the new constants.
   - Replace occurrences of `["Janeiro", "Fevereiro", ...]` with `MONTHS_PT`.
   - Replace occurrences of `["J", "F", ...]` with `MONTHS_PT_INITIALS`.
   - Replace occurrences of `["JAN", "FEV", ...]` with `MONTHS_PT_SHORT`.
4. **Pre-commit Checks**: Run `pre_commit_instructions` tool to make sure we followed the pre commit steps.
5. **Code Review and Refinement**: Review our changes using the `request_code_review` tool.
