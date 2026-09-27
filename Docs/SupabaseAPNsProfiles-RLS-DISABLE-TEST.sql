-- ⚠️ 임시 디버그 전용 — profiles INSERT RLS 차단 여부 확인
-- 프로덕션에서 장기 사용 금지. 테스트 후 반드시 RLS 재활성화.
--
-- 1) RLS 끄기 → 앱 실행 → Dashboard profiles 행 생기면 RLS/ metadata 문제 확정
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2) 테스트 후 복구 (Docs/SupabaseAPNsProfiles.sql 정책 다시 실행)
-- ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
-- (그 다음 SupabaseAPNsProfiles.sql 의 CREATE POLICY 블록 실행)
