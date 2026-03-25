2024-05-18: Identified that frontend month dropdowns using 0-indexed values require explicit +1 conversion before passing to PostgreSQL, which expects 1-indexed months.
