-- Extends `rooms` for group chat (max 5) + keeps `room_members` as detail rows.
-- Run AFTER RoomMembers.sql

ALTER TABLE public.rooms
    ADD COLUMN IF NOT EXISTS max_members smallint NOT NULL DEFAULT 5;

ALTER TABLE public.rooms
    ADD COLUMN IF NOT EXISTS participant_ids text[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.rooms.max_members IS 'Maximum participants (app default 5)';
COMMENT ON COLUMN public.rooms.participant_ids IS 'Denormalized device user ids; synced from room_members';

-- Backfill participant_ids from room_members (or legacy user1/user2)
UPDATE public.rooms r
SET participant_ids = sub.ids
FROM (
    SELECT rm.room_id,
           COALESCE(array_agg(rm.user_id ORDER BY rm.joined_at), '{}') AS ids
    FROM public.room_members rm
    GROUP BY rm.room_id
) sub
WHERE r.id = sub.room_id;

UPDATE public.rooms r
SET participant_ids = array_remove(array_cat(ARRAY[r.user1_id], ARRAY[r.user2_id]), NULL)
WHERE cardinality(participant_ids) = 0
  AND r.user1_id IS NOT NULL
  AND btrim(r.user1_id) <> '';

CREATE OR REPLACE FUNCTION public.sync_rooms_participant_ids_from_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    target_room uuid;
BEGIN
    target_room := COALESCE(NEW.room_id, OLD.room_id);
    UPDATE public.rooms
    SET participant_ids = (
        SELECT COALESCE(array_agg(user_id ORDER BY joined_at), '{}')
        FROM public.room_members
        WHERE room_id = target_room
    )
    WHERE id = target_room;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS room_members_sync_participant_ids ON public.room_members;
CREATE TRIGGER room_members_sync_participant_ids
    AFTER INSERT OR UPDATE OR DELETE ON public.room_members
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_rooms_participant_ids_from_members();

CREATE OR REPLACE FUNCTION public.enforce_room_member_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    cap smallint;
    cnt integer;
BEGIN
    SELECT COALESCE(max_members, 5) INTO cap FROM public.rooms WHERE id = NEW.room_id;
    SELECT count(*)::integer INTO cnt FROM public.room_members WHERE room_id = NEW.room_id;
    IF cnt >= cap THEN
        RAISE EXCEPTION 'room_full' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_members_capacity_check ON public.room_members;
CREATE TRIGGER room_members_capacity_check
    BEFORE INSERT ON public.room_members
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_room_member_capacity();
