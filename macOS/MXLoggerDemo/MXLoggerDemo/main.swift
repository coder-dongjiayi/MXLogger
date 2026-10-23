import AppKit

if CommandLine.arguments.contains("--write-worker") || CommandLine.arguments.contains("--smoke-test") {
    do {
        if CommandLine.arguments.contains("--write-worker") { try DemoSession.runWorker() }
        else { try DemoSmoke.run() }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NSWindowController?
    private var controller: DemoViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(configureMenu), name: .init("MXDemoLanguageChanged"), object: nil)
        #if DEBUG
        if CommandLine.arguments.contains("--ui-smoke-test") {
            if #available(macOS 10.14, *) { NSApp.appearance = NSAppearance(named: .aqua) }
        }
        #endif
        let storyboard = NSStoryboard(name: "Main", bundle: .main)
        let windowController = storyboard.instantiateInitialController() as! NSWindowController
        guard let window = windowController.window else { return }
        controller = window.contentViewController as? DemoViewController
        window.minSize = NSSize(width: 1000, height: 740)
        window.center()
        windowController.showWindow(nil)
        NSApp.applicationIconImage = NSImage(named: "mxlogger_logo")
        NSApp.activate(ignoringOtherApps: true)
        self.windowController = windowController
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--ui-smoke-test"),
           CommandLine.arguments.indices.contains(index + 1), let controller = controller {
            let output = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            DispatchQueue.main.async {
                do { try DemoPreview.run(root: controller, directory: output) }
                catch {
                    FileHandle.standardError.write(Data("\(error)\n".utf8))
                    exit(1)
                }
            }
        }
        #endif
    }

    @objc private func configureMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: DemoL10n.choose("Quit MXLoggerDemo", "退出 MXLoggerDemo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let edit = NSMenu(title: DemoL10n.choose("Edit", "编辑"))
        for (title, selector, key) in [(DemoL10n.choose("Cut", "剪切"), #selector(NSText.cut(_:)), "x"),
                                       (DemoL10n.choose("Copy", "复制"), #selector(NSText.copy(_:)), "c"),
                                       (DemoL10n.choose("Paste", "粘贴"), #selector(NSText.paste(_:)), "v"),
                                       (DemoL10n.choose("Select All", "全选"), #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        let editItem = NSMenuItem(title: DemoL10n.choose("Edit", "编辑"), action: nil, keyEquivalent: "")
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { controller?.shutdown() }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
