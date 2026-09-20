(function () {
  var PLAY =
    "https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub";
  var APP = "https://apps.apple.com/tr/app/engelsiz-club/id6799422264";
  var KEY = "engelsiz_store_download_prompt_until_v1";
  var SNOOZE_MS = 21 * 24 * 60 * 60 * 1000;
  var STYLE_ID = "ec-store-download-style";

  function injectCss() {
    if (document.getElementById(STYLE_ID)) return;
    var css = document.createElement("style");
    css.id = STYLE_ID;
    css.textContent =
      ".ec-store-badges{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:12px 0}" +
      ".ec-store-badges a{display:inline-flex;line-height:0}" +
      ".ec-store-badges img{height:40px;width:auto;max-width:160px}" +
      "#ec-store-prompt{position:fixed;left:12px;right:12px;bottom:12px;z-index:9998;" +
      "font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;" +
      "background:#fff;color:#0D2B1F;border-radius:18px;" +
      "box-shadow:0 10px 28px rgba(13,43,31,.18);padding:14px 14px 10px;" +
      "border:1px solid rgba(26,107,74,.18);max-width:520px;margin:0 auto}" +
      "#ec-store-prompt .ec-store-prompt-row{display:flex;gap:10px;align-items:flex-start}" +
      "#ec-store-prompt .ec-store-prompt-icon{flex:0 0 36px;height:36px;border-radius:50%;" +
      "background:rgba(26,107,74,.12);display:flex;align-items:center;justify-content:center;" +
      "color:#1A6B4A;font-size:18px}" +
      "#ec-store-prompt p{margin:0;font-weight:800;font-size:15px;line-height:1.35;flex:1}" +
      "#ec-store-prompt .ec-store-prompt-close{border:0;background:transparent;color:#4D7A62;" +
      "font-size:22px;line-height:1;cursor:pointer;padding:0 4px}" +
      "#ec-store-prompt .ec-store-prompt-later{display:block;width:100%;margin-top:4px;border:0;" +
      "background:transparent;color:#4D7A62;font-weight:700;font-size:13px;cursor:pointer;padding:8px}" +
      "@media (max-width:480px){#ec-store-prompt{bottom:calc(12px + env(safe-area-inset-bottom,0px))}}";
    document.head.appendChild(css);
  }

  function badgeHtml() {
    return (
      '<div class="ec-store-badges">' +
      '<a href="' +
      APP +
      '" target="_blank" rel="noopener noreferrer">' +
      '<img src="/images/badge_app_store.svg" alt="App Store\'dan indir" height="40" width="120" />' +
      "</a>" +
      '<a href="' +
      PLAY +
      '" target="_blank" rel="noopener noreferrer">' +
      '<img src="/images/badge_google_play.svg" alt="Google Play\'den indir" height="40" width="135" />' +
      "</a>" +
      "</div>"
    );
  }

  function fillPlaceholders() {
    document.querySelectorAll("[data-ec-store-badges]").forEach(function (el) {
      if (!el.getAttribute("data-filled")) {
        el.setAttribute("data-filled", "1");
        el.innerHTML = badgeHtml();
      }
    });
  }

  function dismissedUntil() {
    try {
      return parseInt(localStorage.getItem(KEY) || "0", 10) || 0;
    } catch (e) {
      return 0;
    }
  }

  function snooze() {
    try {
      localStorage.setItem(KEY, String(Date.now() + SNOOZE_MS));
    } catch (e) {}
  }

  function hidePrompt() {
    var el = document.getElementById("ec-store-prompt");
    if (el && el.parentNode) el.parentNode.removeChild(el);
  }

  function dismiss() {
    snooze();
    hidePrompt();
  }

  function isEmbedded() {
    try {
      if (window.self !== window.top) return true;
    } catch (e) {
      return true;
    }
    return false;
  }

  function showPrompt() {
    if (isEmbedded()) return;
    if (document.getElementById("ec-store-prompt")) return;
    if (dismissedUntil() > Date.now()) return;
    var box = document.createElement("aside");
    box.id = "ec-store-prompt";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-modal", "false");
    box.setAttribute("aria-label", "Uygulamayı indirmek ister misiniz?");
    box.innerHTML =
      '<div class="ec-store-prompt-row">' +
      '<div class="ec-store-prompt-icon" aria-hidden="true">↓</div>' +
      "<p>Uygulamayı indirmek ister misiniz?</p>" +
      '<button type="button" class="ec-store-prompt-close" aria-label="Şimdi değil">&times;</button>' +
      "</div>" +
      badgeHtml() +
      '<button type="button" class="ec-store-prompt-later">Şimdi değil</button>';
    document.body.appendChild(box);
    box.querySelector(".ec-store-prompt-close").addEventListener("click", dismiss);
    box.querySelector(".ec-store-prompt-later").addEventListener("click", dismiss);
    box.querySelectorAll("a").forEach(function (a) {
      a.addEventListener("click", function () {
        snooze();
      });
    });
  }

  function init() {
    injectCss();
    fillPlaceholders();
    window.setTimeout(fillPlaceholders, 1500);
    window.setTimeout(showPrompt, 800);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
