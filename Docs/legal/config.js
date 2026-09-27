/**
 * GitHub Pages 배포 후 이메일만 앱(AppLegalConfig)과 맞추면 됩니다.
 * HTML 안의 mailto 링크를 일괄 갱신합니다.
 */
(function () {
  var SUPPORT_EMAIL = "duftlaglehsdmfqjfwk@gmail,com";

  document.querySelectorAll('a[href^="mailto:"]').forEach(function (anchor) {
    anchor.href = "mailto:" + SUPPORT_EMAIL;
    if (anchor.id === "support-mail" || anchor.textContent.indexOf("@") >= 0) {
      anchor.textContent = SUPPORT_EMAIL;
    }
  });
})();
