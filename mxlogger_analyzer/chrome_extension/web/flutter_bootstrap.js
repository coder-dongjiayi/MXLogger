{{flutter_js}}
{{flutter_build_config}}

const mxEngineConfig = {
    renderer: "canvaskit",
    canvasKitBaseUrl: "canvaskit/",
    canvasKitVariant: "chromium",
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
