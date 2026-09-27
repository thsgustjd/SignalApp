-- 5-person group chat: run this entire script once in Supabase SQL Editor.
-- Recreates `room_members` with columns the iOS app expects.
-- WARNING: drops existing `room_members` data.

DROP TABLE IF EXISTS public.room_members CASCADE;

CREATE TABLE public.room_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
    user_id text NOT NULL,
    display_name text NOT NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT room_members_room_user_unique UNIQUE (room_id, user_id)
);

CREATE INDEX room_members_room_id_idx ON public.room_members (room_id);
CREATE INDEX room_members_user_id_idx ON public.room_members (user_id);

COMMENT ON TABLE public.room_members IS 'Up to 5 participants per room (source of truth for membership)';
COMMENT ON COLUMN public.room_members.user_id IS 'Device user id — matches profiles.id and messages.sender_id';

INSERT INTO public.room_members (room_id, user_id, display_name)
SELECT r.id, r.user1_id, COALESCE(NULLIF(btrim(r.user1_name), ''), 'member')
FROM public.rooms r
WHERE r.user1_id IS NOT NULL AND btrim(r.user1_id) <> '';

INSERT INTO public.room_members (room_id, user_id, display_name)
SELECT r.id, r.user2_id, COALESCE(NULLIF(btrim(r.user2_name), ''), 'member')
FROM public.rooms r
WHERE r.user2_id IS NOT NULL AND btrim(r.user2_id) <> ''
ON CONFLICT (room_id, user_id) DO NOTHING;

ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_members TO anon, authenticated;

CREATE POLICY "room_members_select"
    ON public.room_members FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "room_members_insert"
    ON public.room_members FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "room_members_update"
    ON public.room_members FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "room_members_delete"
    ON public.room_members FOR DELETE TO anon, authenticated USING (true);

CREATE OR REPLACE FUNCTION public.enforce_room_member_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    member_count integer;
BEGIN
    SELECT count(*)::integer INTO member_count
    FROM public.room_members
    WHERE room_id = NEW.room_id;
    IF member_count >= 5 THEN
        RAISE EXCEPTION 'room_full' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER room_members_capacity_check
    BEFORE INSERT ON public.room_members
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_room_member_capacity();

NOTIFY pgrst, 'reload schema';
