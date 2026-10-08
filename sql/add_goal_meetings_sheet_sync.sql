CREATE TABLE public.goal_meetings_sync (
id boolean PRIMARY KEY DEFAULT true CHECK(id),
source_sheet_id text NOT NULL,
meetings jsonb NOT NULL CHECK(jsonb_typeof(meetings)='array'),
synced_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.goal_meetings_sync ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.goal_meetings_sync FROM anon,authenticated;
GRANT SELECT ON public.goal_meetings_sync TO authenticated;
CREATE POLICY approved_read_goal_meetings ON public.goal_meetings_sync FOR SELECT TO authenticated USING ((SELECT public.is_approved()));
