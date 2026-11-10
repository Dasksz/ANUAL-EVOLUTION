-- Run on PROMOTORES. Temporary fixtures; all definitions/config changes roll back.
BEGIN;
CREATE TEMP TABLE goal_history(dtped timestamptz,codcli text,codusur text,codfor text,produto text,vlvenda numeric,tipovenda text);
CREATE TEMP TABLE goal_clients(codigo_cliente text);
CREATE TEMP TABLE goal_products(codigo text,descricao text);
CREATE TEMP TABLE goal_saved(month_key text,supplier text,brand text,goals_data jsonb,updated_at timestamptz);
CREATE TEMP TABLE goal_current(dtped timestamptz);
DO $$
DECLARE definition text;m date:=date_trunc('month',now() AT TIME ZONE 'America/Bahia')::date;prior date;d jsonb;
BEGIN
 prior:=m-interval '1 month';
 INSERT INTO goal_clients VALUES('100'),('200'),('9569');
 INSERT INTO goal_products VALUES('s','CHEETOS'),('f','TODDY'),('other','OUTROS FOODS');
 INSERT INTO goal_current VALUES(m+1);
 INSERT INTO goal_history VALUES
 (prior,'100','78','707','s',100,'1'),(prior,'100','78','707','s',-10,'9'),
 (prior,'100','78','1119','f',50,'1'),(prior,'100','78','1119','other',999,'1'),
 (prior,'100','78','707','s',999,'5'),(m,'100','78','707','s',300,'1'),
 (prior-1,'100','78','707','s',200,'1'),(prior,'300','78','707','s',100,'1'),
 (prior,'9569','053','707','s',500,'1'),(prior,'9569','78','707','s',20,'1');
 definition:=pg_get_functiondef('private.planning_live_revenue_goals_v1(text,text[])'::regprocedure);
 definition:=replace(replace(replace(definition,'public.data_history','pg_temp.goal_history'),'public.data_clients','pg_temp.goal_clients'),'public.dim_produtos','pg_temp.goal_products');EXECUTE definition;
 definition:=pg_get_functiondef('public.planning_financial_source_v1(text,text[],text)'::regprocedure);
 definition:=replace(replace(definition,'public.goals_distribution','pg_temp.goal_saved'),'public.data_detailed','pg_temp.goal_current');EXECUTE definition;
 UPDATE private.planning_financial_bridge_config SET token_hash=encode(sha256(convert_to(repeat('a',64),'UTF8')),'hex') WHERE id=true;
 d:=public.planning_financial_source_v1(to_char(m,'YYYY-MM'),ARRAY['100','200','300','9569'],repeat('a',64));
 IF d#>>'{goalsSource}'<>'previous-month-default' OR d#>>'{clients,100,revenueGoal}'<>'140'
 OR d#>>'{clients,200,revenueGoal}'<>'0' OR d#>>'{clients,300,revenueGoal}'<>'0' OR d#>>'{clients,9569,revenueGoal}'<>'20'
 THEN RAISE EXCEPTION 'Live Promotores goal parity failed: %',d;END IF;
 INSERT INTO goal_saved VALUES(to_char(m,'YYYY-MM'),'ALL','GENERAL','{"clients":{"100":{"707":{"fat":0}}}}',now());
 d:=public.planning_financial_source_v1(to_char(m,'YYYY-MM'),ARRAY['100','200'],repeat('a',64));
 IF d#>>'{goalsSource}'<>'saved' OR d#>>'{clients,100,revenueGoal}'<>'0' OR d#>>'{clients,200,revenueGoal}'<>'0' THEN RAISE EXCEPTION 'Saved goals or explicit zero overwritten';END IF;
 d:=public.planning_financial_source_v1(to_char(m-interval '2 months','YYYY-MM'),ARRAY['100'],repeat('a',64));
 IF d#>'{clients,100,revenueGoal}'<>'null'::jsonb OR d#>>'{goalsSource}'<>'unavailable' THEN RAISE EXCEPTION 'Unsaved old month incorrectly recalculated';END IF;
END;$$;
ROLLBACK;
