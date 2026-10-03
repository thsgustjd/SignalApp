# 하트 재화 · 소셜 로그인

1. Supabase Dashboard → **Authentication → Providers**에서 **Apple**, **Google** 활성화
2. **Redirect URL**에 `com.hyunseong.signalapp://auth-callback` 및 Supabase 콜백 URL 등록
3. SQL Editor에서 `HeartWalletSystem.sql` 실행
4. App Store Connect에서 IAP Product ID 5종 생성 ( `HeartCatalog.swift` 와 동일 ID )
