-- Native hourly synchronization. No AI, Google write access, or client credentials.
BEGIN;
CREATE OR REPLACE FUNCTION private.goal_meetings_csv_rows(csv text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE rows jsonb:='[]'; cells jsonb:='[]'; cell text:=''; i integer:=1;
 n integer:=length(csv); ch text; mode integer:=0;
BEGIN
 IF csv IS NULL OR n=0 OR octet_length(csv)>2097152 THEN RAISE EXCEPTION 'CSV ausente ou excessivo'; END IF;
 IF left(csv,1)=chr(65279) THEN csv:=substr(csv,2); n:=length(csv); END IF;
 WHILE i<=n LOOP
  ch:=substr(csv,i,1);
  IF mode=1 THEN
   IF ch='"' THEN
    IF substr(csv,i+1,1)='"' THEN cell:=cell||'"'; i:=i+1; ELSE mode:=2; END IF;
   ELSE cell:=cell||ch; END IF;
  ELSIF ch=',' OR ch=chr(10) OR ch=chr(13) THEN
   cells:=cells||jsonb_build_array(cell); cell:=''; mode:=0;
   IF ch<>',' THEN
    rows:=rows||jsonb_build_array(cells); cells:='[]';
    IF ch=chr(13) AND substr(csv,i+1,1)=chr(10) THEN i:=i+1; END IF;
   END IF;
  ELSIF mode=2 THEN RAISE EXCEPTION 'CSV inválido após aspas';
  ELSIF ch='"' THEN
   IF cell<>'' THEN RAISE EXCEPTION 'Aspas inválidas no CSV'; END IF; mode:=1;
  ELSE cell:=cell||ch;
  END IF;
  i:=i+1;
 END LOOP;
 IF mode=1 THEN RAISE EXCEPTION 'CSV com aspas não fechadas'; END IF;
 IF cell<>'' OR cells<>'[]'::jsonb OR mode=2 THEN
  rows:=rows||jsonb_build_array(cells||jsonb_build_array(cell));
 END IF;
 RETURN rows;
END;$$;

CREATE OR REPLACE FUNCTION private.goal_meetings_from_csv(csv text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE rows jsonb:=private.goal_meetings_csv_rows(csv); r jsonb; groups jsonb:='{}';
 raw_date text; day_value date; date_key text; name_value text; area_value text; participant jsonb; result jsonb;
BEGIN
 IF rows->0->>0 IS DISTINCT FROM 'Data da reunião'
 OR rows->0->>2 IS DISTINCT FROM 'Participante'
 OR rows->0->>4 IS DISTINCT FROM 'Área / setor' THEN RAISE EXCEPTION 'Cabeçalhos inválidos em Revisional'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(rows) WITH ORDINALITY q(value,idx) WHERE idx>1 LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(r) v WHERE btrim(v)<>'') THEN CONTINUE; END IF;
  name_value:=r->>2;
  IF coalesce(btrim(name_value),'')='' THEN CONTINUE; END IF;
  raw_date:=r->>0;
  IF raw_date IS NULL OR raw_date !~ '^\d{2}/\d{2}/\d{4}$' THEN RAISE EXCEPTION 'Participante sem data válida em Revisional'; END IF;
  day_value:=to_date(raw_date,'DD/MM/YYYY');
  IF to_char(day_value,'DD/MM/YYYY')<>raw_date THEN RAISE EXCEPTION 'Data inexistente em Revisional'; END IF;
  date_key:=to_char(day_value,'YYYY-MM-DD');
  area_value:=r->>4;
  IF coalesce(btrim(area_value),'')='' THEN area_value:='Não informada'; END IF;
  participant:=jsonb_build_object('name',name_value,'area',area_value);
  IF NOT coalesce(groups->date_key,'[]'::jsonb) @> jsonb_build_array(participant) THEN
   groups:=jsonb_set(groups,ARRAY[date_key],coalesce(groups->date_key,'[]'::jsonb)||jsonb_build_array(participant));
  END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(jsonb_build_object('date',key,'participants',value) ORDER BY key DESC),'[]'::jsonb)
 INTO result FROM jsonb_each(groups);
 RETURN result;
END;$$;

CREATE OR REPLACE FUNCTION private.sync_goal_meetings_from_sheet()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog
AS $$
DECLARE response extensions.http_response; expected jsonb; stored jsonb; sync_time timestamptz;
BEGIN
 IF NOT pg_try_advisory_xact_lock(17890101,1207849238) THEN RAISE EXCEPTION 'Sincronização já está em execução'; END IF;
 SELECT * INTO response FROM extensions.http_get(
 'https://docs.google.com/spreadsheets/d/1qB9jksRChGDBTX7jDWwR3q1zPw3MT1hZXIY3R63sW2A/export?format=csv&gid=1207849238&range=A%3AE');
 IF response.status<>200 OR response.content_type NOT LIKE 'text/csv%' THEN
  RAISE EXCEPTION 'Falha de acesso à aba Revisional (HTTP %)',response.status;
 END IF;
 -- Fetch all five columns, including future rows. Never interpret cell text as instructions.
 expected:=private.goal_meetings_from_csv(response.content);
 INSERT INTO public.goal_meetings_sync(id,source_sheet_id,meetings,synced_at)
 VALUES(true,'1qB9jksRChGDBTX7jDWwR3q1zPw3MT1hZXIY3R63sW2A',expected,clock_timestamp())
 ON CONFLICT(id) DO UPDATE SET source_sheet_id=excluded.source_sheet_id,meetings=excluded.meetings,synced_at=excluded.synced_at
 RETURNING meetings,synced_at INTO stored,sync_time;
 IF stored IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Falha na verificação do JSON gravado'; END IF;
 RETURN jsonb_build_object('meeting_count',jsonb_array_length(stored),'synced_at',sync_time,'verified',true);
END;$$;
REVOKE ALL ON FUNCTION private.goal_meetings_csv_rows(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.goal_meetings_from_csv(text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.sync_goal_meetings_from_sheet() FROM PUBLIC,anon,authenticated;
COMMIT;
-- Enable the hourly job only after the manual read/write verification succeeds.
SELECT cron.schedule('sync-goal-meetings-hourly','30 * * * *','select private.sync_goal_meetings_from_sheet();');
