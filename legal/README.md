# 법적 고지 웹페이지 (GitHub Pages)

`privacy.html` · `terms.html` 은 App Store Connect **Privacy Policy URL** 및 앱 내 링크용입니다.

## 1. 이메일 맞추기

1. `config.js` 의 `SUPPORT_EMAIL` 을 본인 이메일로 수정  
2. `SignalApp/AppLegalConfig.swift` 의 `supportEmail` 도 **동일하게** 수정  

## 2. GitHub Pages 켜기

1. 이 저장소를 GitHub에 push  
2. 저장소 **Settings → Pages**  
3. **Build and deployment → Source:** Deploy from a branch  
4. **Branch:** `main` · **Folder:** `/docs`  
5. 저장 후 1~3분 뒤 URL 확인 (예: `https://<사용자명>.github.io/<저장소명>/legal/privacy.html`)

저장소 이름이 `SignalApp`이면:

- 방침: `https://<사용자명>.github.io/SignalApp/legal/privacy.html`
- 약관: `https://<사용자명>.github.io/SignalApp/legal/terms.html`

## 3. 앱 URL 연결

`AppLegalConfig.swift` 의 `legalSiteBase` 를 위 Pages URL에서 `/privacy.html` 을 뺀 경로로 설정:

```swift
private static let legalSiteBase = "https://YOUR_USERNAME.github.io/SignalApp/legal"
```

## 4. App Store Connect

- **App Information → Privacy Policy URL:** `.../legal/privacy.html`  
- **App Privacy** 질문은 방침 본문과 동일하게 작성  

## 로컬 미리보기

```bash
cd docs/legal && python3 -m http.server 8765
```

브라우저: http://localhost:8765/privacy.html
