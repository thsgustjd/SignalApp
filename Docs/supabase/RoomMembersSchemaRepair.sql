-- Fix: `column room_members.user_id does not exist`
-- Run this ONCE in Supabase SQL Editor when the app/PostgREST expects:
--   id, room_id, user_id, display_name, joined_at
-- Safe to re-run (idempotent).

-- 1) Ensure base table exists (empty shell if missing)
CREATE TABLE IF NOT EXISTS public.room_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.rooms (id) ON DELETE CASCADE,
    user_id text NOT NULL,
    display_name text NOT NULL,
    joined_at timestamptz NOT NULL DEFAULT now()
);

-- 2) Rename common legacy column names → user_id
DO $repair$
DECLARE
    alt text;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = 'user_id'
    ) THEN
        FOREACH alt IN ARRAY ARRAY[
            'device_id', 'device_user_id', 'member_id', 'member_user_id',
            'profile_id', 'participant_id', 'participant_user_id'
        ]
        LOOP
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = alt
            ) THEN
                EXECUTE format('ALTER TABLE public.room_members RENAME COLUMN %I TO user_id', alt);
                EXIT;
            END IF;
        END LOOP;
    END IF;
END $repair$;

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS user_id text;

-- 3) display_name aliases
DO $repair$
DECLARE
    alt text;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = 'display_name'
    ) THEN
        FOREACH alt IN ARRAY ARRAY['nickname', 'user_name', 'member_name', 'name']
        LOOP
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = alt
            ) THEN
                EXECUTE format('ALTER TABLE public.room_members RENAME COLUMN %I TO display_name', alt);
                EXIT;
            END IF;
        END LOOP;
    END IF;
END $repair$;

ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS display_name text;

-- 4) room_id / joined_at
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS room_id uuid REFERENCES public.rooms (id) ON DELETE CASCADE;
ALTER TABLE public.room_members ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();

-- 5) Backfill nulls before NOT NULL enforcement
UPDATE public.room_members SET display_name = 'member'
WHERE display_name IS NULL OR btrim(display_name) = '';

UPDATE public.room_members SET joined_at = now() WHERE joined_at IS NULL;

-- 6) Unique (room_id, user_id) — required by app inserts
ALTER TABLE public.room_members DROP CONSTRAINT IF EXISTS room_members_room_user_unique;
DELETE FROM public.room_members a
    USING public.room_members b
WHERE a.id > b.id AND a.room_id = b.room_id AND a.user_id = b.user_id;

ALTER TABLE public.room_members
    ADD CONSTRAINT room_members_room_user_unique UNIQUE (room_id, user_id);

CREATE INDEX IF NOT EXISTS room_members_room_id_idx ON public.room_members (room_id);
CREATE INDEX IF NOT EXISTS room_members_user_id_idx ON public.room_members (user_id);

COMMENT ON COLUMN public.room_members.user_id IS 'Device user id (matches profiles.id, messages.sender_id, rooms.user1_id)';
COMMENT ON COLUMN public.room_members.display_name IS 'Chat nickname in this room';

-- 7) PostgREST schema cache (Supabase API)
NOTIFY pgrst, 'reload schema';

DO $verify$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'room_members' AND column_name = 'user_id'
    ) THEN
        RAISE EXCEPTION
            'room_members.user_id is still missing. Drop public.room_members (if test data only) and run RoomMembers.sql, or add user_id manually.';
    END IF;
END $verify$;

-- Verify (optional — run separately):
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'room_members' ORDER BY ordinal_position;
