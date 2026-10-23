import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var desktopChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    title = "MXLogger Flutter Demo"
    minSize = NSSize(width: 680, height: 600)
    center()

    desktopChannel = FlutterMethodChannel(
      name: "com.mxlogger.demo/desktop",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    desktopChannel?.setMethodCallHandler { call, result in
      guard call.method == "openDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String, !path.isEmpty else {
        result(FlutterError(code: "invalid_path", message: "A directory path is required.", details: nil))
        return
      }
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
        result(FlutterError(code: "directory_missing", message: "The log directory does not exist.", details: path))
        return
      }
      if NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true)) {
        result(nil)
      } else {
        result(FlutterError(code: "open_failed", message: "Finder could not open the log directory.", details: path))
      }
    }

    super.awakeFromNib()
  }
}
