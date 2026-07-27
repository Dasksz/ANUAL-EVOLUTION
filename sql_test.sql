BEGIN;

-- Run the patched get_closing_presentation_data function definition
\i sql/full_system_v1.sql

-- Shadow test the function call with dummy parameters (e.g., Year 2024, Month 5)
SELECT get_closing_presentation_data('2024', '5');

ROLLBACK;
