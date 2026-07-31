BEGIN;

EXPLAIN ANALYZE
SELECT count(*) FROM (
                SELECT
                    SUM(CASE WHEN tipovenda IN ('5', '11') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as caixas
                FROM data_detailed s
                WHERE EXTRACT(YEAR FROM s.dtped) = 2024
) t;

EXPLAIN ANALYZE
SELECT count(*) FROM (
                SELECT
                    SUM(CASE WHEN tipovenda IN ('5', '11') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as caixas
                FROM data_detailed s
                WHERE s.dtped >= make_date(2024, 1, 1) AND s.dtped <= make_date(2024, 12, 31)
) t;

ROLLBACK;
