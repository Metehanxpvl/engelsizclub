{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // Service worker mobil Safari'de boş ekran / sonsuz yenilemeye yol açabiliyor.
  // Bu yüzden bilerek kaydetmiyoruz.
  config: {
    // Yerel canvaskit kullan (--no-web-resources-cdn ile build).
    useLocalCanvasKit: true,
    renderer: 'canvaskit',
    canvasKitVariant: 'full',
    // Safari (webkit) dart2wasm / skwasm ile sık açılmaz — yalnızca dart2js.
    wasmAllowList: { blink: false, gecko: false, webkit: false, unknown: false },
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        useLocalCanvasKit: true,
        renderer: 'canvaskit',
        canvasKitVariant: 'full',
      });
      await appRunner.runApp();
    } catch (err) {
      console.error('Flutter engine failed', err);
      var el = document.getElementById('loading');
      if (!el) return;
      el.classList.remove('hidden');
      el.style.pointerEvents = 'auto';
      var hint = el.querySelector('.hint');
      if (hint) {
        hint.innerHTML =
          'Tarayıcı bu sayfayı açamadı. Safari’de Geçmiş ve Website Verilerini Silin, sonra ' +
          '<a href="' + location.href + '" style="color:#fff;text-decoration:underline">yenileyin</a>.';
      }
      var spin = el.querySelector('.spinner');
      if (spin) spin.style.display = 'none';
    }
  },
});
