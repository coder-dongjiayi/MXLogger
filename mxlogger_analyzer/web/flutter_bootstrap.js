{{flutter_js}}
{{flutter_build_config}}

// Use locally bundled CanvasKit without restricting the app to Chromium.
const mxEngineConfig = {
  renderer: "canvaskit",
  canvasKitBaseUrl: "canvaskit/",
  fontFallbackBaseUrl: "fonts/",
};

_flutter.loader.load({
  config: mxEngineConfig,
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine(mxEngineConfig);
    document.getElementById("loading")?.remove();
    await appRunner.runApp();
  },
});
