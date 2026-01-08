-- Function to get the latest data timestamp for cache invalidation
CREATE OR REPLACE FUNCTION get_data_version()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_update timestamp with time zone;
BEGIN
    -- Get the most recent creation time from summary (which is truncated/rebuilt on update)
    SELECT MAX(created_at) INTO v_last_update FROM public.data_summary;

    -- If null (empty table), return epoch
    IF v_last_update IS NULL THEN
        RETURN '1970-01-01 00:00:00+00';
    END IF;

    RETURN v_last_update::text;
END;
$$;
