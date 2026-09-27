-- Run once in Supabase SQL Editor (after room_members / messages / profiles exist).

CREATE TABLE IF NOT EXISTS public.content_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT now(),
    reporter_user_id text NOT NULL,
    reporter_nickname text,
    room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
    reported_user_id text,
    message_id uuid,
    category text NOT NULL,
    note text,
    CONSTRAINT content_reports_category_check CHECK (
        category IN ('spam', 'harassment', 'illegal', 'other')
    )
);

CREATE INDEX IF NOT EXISTS content_reports_created_at_idx ON public.content_reports (created_at DESC);
CREATE INDEX IF NOT EXISTS content_reports_room_id_idx ON public.content_reports (room_id);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.content_reports TO anon, authenticated;

DROP POLICY IF EXISTS "content_reports_insert" ON public.content_reports;
CREATE POLICY "content_reports_insert"
    ON public.content_reports FOR INSERT TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "content_reports_select_own" ON public.content_reports;
CREATE POLICY "content_reports_select_own"
    ON public.content_reports FOR SELECT TO anon, authenticated
    USING (reporter_user_id = COALESCE(
        auth.jwt() -> 'user_metadata' ->> 'device_user_id',
        ''
    ));

CREATE OR REPLACE FUNCTION public.delete_my_account_data(p_user_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_user_id IS NULL OR btrim(p_user_id) = '' THEN
        RAISE EXCEPTION 'invalid_user_id';
    END IF;

    DELETE FROM public.messages WHERE sender_id = p_user_id;
    DELETE FROM public.room_members WHERE user_id = p_user_id;
    DELETE FROM public.profiles WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_my_account_data(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
