{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // Service worker mobil Safari'de boş ekran / sonsuz yenilemeye yol açabiliyor.
  // Bu yüzden bilerek kaydetmiyoruz.
  config: {
    // Yerel canvaskit kullan (--no-web-resources-cdn ile build).
    useLocalCanvasKit: true,
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      useLocalCanvasKit: true,
    });
    await appRunner.runApp();
  },
});
