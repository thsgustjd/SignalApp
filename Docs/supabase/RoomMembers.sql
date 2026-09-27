-- Group chat: `room_members` is the source of truth (max 5 users per room).
-- `rooms.user1_id` / `user2_id` stay for backward compatibility (creator + optional 2nd slot mirror only).
--
-- If you see: column room_members.user_id does not exist
--   → run RoomMembersSchemaRepair.sql FIRST, then this script.
-- Run order: RoomMembersSchemaRepair.sql → RoomMembers.sql → RoomsGroupMigration.sql

CREATE TABLE IF NOT EXISTS public.room_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
    user_id text NOT NULL,
    display_name text NOT NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT room_members_room_user_unique UNIQUE (room_id, user_id)
);

CREATE INDEX IF NOT EXISTS room_members_room_id_idx ON public.room_members (room_id);
CREATE INDEX IF NOT EXISTS room_members_user_id_idx ON public.room_members (user_id);

COMMENT ON TABLE public.room_members IS 'Up to 5 participants per room; source of truth for group membership';

-- Backfill legacy 1:1 rows (safe to re-run)
INSERT INTO public.room_members (room_id, user_id, display_name)
SELECT r.id, r.user1_id, COALESCE(NULLIF(btrim(r.user1_name), ''), 'member')
FROM public.rooms r
WHERE r.user1_id IS NOT NULL AND btrim(r.user1_id) <> ''
ON CONFLICT (room_id, user_id) DO NOTHING;

INSERT INTO public.room_members (room_id, user_id, display_name)
SELECT r.id, r.user2_id, COALESCE(NULLIF(btrim(r.user2_name), ''), 'member')
FROM public.rooms r
WHERE r.user2_id IS NOT NULL AND btrim(r.user2_id) <> ''
ON CONFLICT (room_id, user_id) DO NOTHING;

ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_members TO anon, authenticated;

DROP POLICY IF EXISTS "room_members_select" ON public.room_members;
DROP POLICY IF EXISTS "room_members_insert" ON public.room_members;
DROP POLICY IF EXISTS "room_members_update" ON public.room_members;
DROP POLICY IF EXISTS "room_members_delete" ON public.room_members;

CREATE POLICY "room_members_select"
    ON public.room_members FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "room_members_insert"
    ON public.room_members FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "room_members_update"
    ON public.room_members FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "room_members_delete"
    ON public.room_members FOR DELETE TO anon, authenticated USING (true);
