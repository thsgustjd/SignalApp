-- SignalApp APNs token storage
-- Run in Supabase SQL Editor after enabling Push Notifications on the iOS app target.
-- Dashboard: Authentication → Providers → enable **Anonymous sign-ins** (필수).

CREATE TABLE IF NOT EXISTS public.profiles (
    id text PRIMARY KEY,
    apns_token text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS apns_token text;

COMMENT ON COLUMN public.profiles.id IS 'App-local user id (messages.sender_id / device UserDefaults UUID)';
COMMENT ON COLUMN public.profiles.apns_token IS 'APNs device token (hex string)';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.profiles TO anon, authenticated;

-- RLS 차단 의심 시 (Dashboard 0 rows, 앱 콘솔 🟠 RLS SILENT): Docs/SupabaseAPNsProfiles-RLS-DISABLE-TEST.sql
-- 테스트 후 ENABLE ROW LEVEL SECURITY + 아래 정책 재적용.

-- JWT user_metadata.device_user_id ↔ profiles.id (대소문자 무시)
CREATE OR REPLACE FUNCTION public.profile_id_owned_by_caller(profile_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    length(btrim(COALESCE(auth.jwt() -> 'user_metadata' ->> 'device_user_id', ''))) > 0
    AND lower(btrim(profile_id)) = lower(btrim(auth.jwt() -> 'user_metadata' ->> 'device_user_id'))
  OR (
    auth.uid() IS NOT NULL
    AND lower(btrim(profile_id)) = lower(btrim(auth.uid()::text))
  );
$$;

DROP POLICY IF EXISTS "profiles upsert own row" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

CREATE POLICY "profiles_select_own"
    ON public.profiles
    FOR SELECT
    TO anon, authenticated
    USING (public.profile_id_owned_by_caller(id));

CREATE POLICY "profiles_insert_own"
    ON public.profiles
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (public.profile_id_owned_by_caller(id));

CREATE POLICY "profiles_update_own"
    ON public.profiles
    FOR UPDATE
    TO anon, authenticated
    USING (public.profile_id_owned_by_caller(id))
    WITH CHECK (public.profile_id_owned_by_caller(id));

-- iOS: Anonymous sign-in → user_metadata.device_user_id = currentUserId → profiles INSERT/UPDATE
-- Edge Function (service role): profiles SELECT by recipient_id (RLS bypass)
--
-- RLS 검증 (Dashboard SQL로 확인):
--   SELECT public.profile_id_owned_by_caller('<profiles.id 후보>');
-- INSERT/UPDATE WITH CHECK 는 profile_id_owned_by_caller(id) 와 동일.
-- profiles.id 가 auth.uid() 와 다르면 metadata.device_user_id 가 JWT 에 있어야 통과.
