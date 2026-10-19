-- Historical supervisor discovery is needed only when selecting a supervisor.
DO $$ DECLARE def text; BEGIN
 SELECT pg_get_functiondef('private.evolution_dashboard_targets_official(integer,integer,jsonb)'::regprocedure) INTO def;
 def:=replace(def,'WHERE ano BETWEEN y-1 AND y AND ano*12+mes<=y*12+mo AND codsupervisor IS NOT NULL',
 'WHERE EXISTS(SELECT 1 FROM filters WHERE cardinality(supervisors)>0) AND ano BETWEEN y-1 AND y AND ano*12+mes<=y*12+mo AND codsupervisor IS NOT NULL');
 EXECUTE def;
END $$;
