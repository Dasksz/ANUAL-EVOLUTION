BEGIN;

EXPLAIN ANALYZE
SELECT count(*) FROM data_detailed WHERE EXTRACT(YEAR FROM dtped) = 2024;

EXPLAIN ANALYZE
SELECT count(*) FROM data_detailed WHERE dtped >= make_date(2024, 1, 1) AND dtped <= make_date(2024, 12, 31);

ROLLBACK;
