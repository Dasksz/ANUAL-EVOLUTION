-- Use the latest detailed sales assignment for active sellers.
-- Fall back to the compact sales summary only when a seller has no detailed rows.
CREATE OR REPLACE FUNCTION private.evolution_goals_supervisor_by_seller()
RETURNS TABLE(codusur text, codsupervisor text)
LANGUAGE sql
STABLE
SET search_path = ''
AS $function$
    WITH raw_detailed AS MATERIALIZED (
        SELECT d.codusur, d.codsupervisor, d.dtped
        FROM public.data_detailed_current d
        WHERE d.codusur IS NOT NULL
          AND d.codsupervisor IS NOT NULL
          AND d.dtped IS NOT NULL
    ),
    latest_date AS (
        SELECT codusur, max(dtped) AS latest_dtped
        FROM raw_detailed
        GROUP BY codusur
    ),
    detail_counts AS (
        SELECT d.codusur, d.codsupervisor, count(*) AS assignment_count
        FROM raw_detailed d
        JOIN latest_date l
          ON l.codusur = d.codusur
         AND l.latest_dtped = d.dtped
        GROUP BY d.codusur, d.codsupervisor
    ),
    detail_owner AS (
        SELECT DISTINCT ON (codusur) codusur, codsupervisor
        FROM detail_counts
        ORDER BY codusur, assignment_count DESC, codsupervisor
    ),
    fallback_counts AS MATERIALIZED (
        SELECT s.codusur, s.codsupervisor, count(*) AS sale_count
        FROM public.data_summary_current s
        WHERE s.codusur IS NOT NULL
          AND s.codsupervisor IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM detail_owner d
              WHERE d.codusur = s.codusur
          )
        GROUP BY s.codusur, s.codsupervisor
    ),
    fallback_owner AS (
        SELECT DISTINCT ON (codusur) codusur, codsupervisor
        FROM fallback_counts
        ORDER BY codusur, sale_count DESC, codsupervisor
    )
    SELECT codusur, codsupervisor
    FROM detail_owner
    UNION ALL
    SELECT codusur, codsupervisor
    FROM fallback_owner;
$function$;

REVOKE ALL ON FUNCTION private.evolution_goals_supervisor_by_seller() FROM PUBLIC, anon, authenticated;
