EXPLAIN ANALYZE SELECT COALESCE(json_agg(v), '[]'::json) FROM (
                WITH RECURSIVE t AS (
                    SELECT MIN(rede) AS v FROM public.cache_filters WHERE rede IS NOT NULL AND rede NOT IN ('N/A', 'N/D')
                    UNION ALL
                    SELECT (SELECT MIN(rede) FROM public.cache_filters WHERE rede > t.v AND rede IS NOT NULL AND rede NOT IN ('N/A', 'N/D'))
                    FROM t WHERE t.v IS NOT NULL
                )
                SELECT v FROM t WHERE v IS NOT NULL ORDER BY v
            ) sub;
