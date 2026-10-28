#if DEBUG
import AppKit

/// Renders this app's own Storyboard views; it does not capture the desktop.
/// Also exercises Storyboard outlets, prototypes, navigation, localization and filters.
enum DemoPreview {
    static func run(root: DemoViewController, directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        DemoL10n.forcedLanguage = "en"
        root.show("Landing", remember: false)
        try render(root.view, to: directory.appendingPathComponent("01-landing.png"))
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("mxlogger-demo-preview-\(UUID().uuidString)")
        var config = DemoConfiguration()
        config.directory = temporary.path
        config.namespace = "com.djy.mxlogger"
        config.console = false
        root.session = try DemoSession(configuration: config)
        root.enter()
        guard let home = root.page as? DemoHomeViewController, home.table.numberOfRows > 20 else {
            throw DemoError(message: "Storyboard home scene or prototypes failed to load")
        }
        for index in 0..<5 { home.writeSample(index) }
        try root.session?.write(level: 1, message: "ui-smoke-search-value", name: "preview", tag: "native")
        try render(root.view, to: directory.appendingPathComponent("02-home-en.png"))
        guard let cell = home.table.view(atColumn: 0, row: 1, makeIfNecessary: true), cell.bounds.width > 700 else {
            throw DemoError(message: "Storyboard table column was compressed")
        }
        for expected in [false, true] {
            guard let cell = home.table.view(atColumn: 0, row: 12, makeIfNecessary: true) as? DemoActionCell else {
                throw DemoError(message: "Storyboard toggle cell failed to load")
            }
            cell.toggle.performClick(nil)
            guard root.session?.logger.isEnabled == expected else {
                throw DemoError(message: "Storyboard toggle action did not update the logger")
            }
        }
        root.toggleLanguage(nil)
        try render(root.view, to: directory.appendingPathComponent("03-home-zh.png"))
        root.show("Files")
        guard let files = root.page as? DemoFilesViewController, files.table.numberOfRows > 0 else {
            throw DemoError(message: "Storyboard file list failed to load")
        }
        try render(root.view, to: directory.appendingPathComponent("04-files.png"))
        files.open(row: 0)
        let deadline = Date().addingTimeInterval(20)
        func finishWhenLoaded() {
            if root.busy && Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: finishWhenLoaded)
                return
            }
            do {
                guard let viewer = root.page as? DemoLogViewerController, !root.busy, viewer.filtered.count == 7 else {
                    throw DemoError(message: "Storyboard viewer did not finish parsing")
                }
                viewer.filters.setSelected(true, forSegment: 2)
                viewer.search.stringValue = "ui-smoke"
                viewer.applyFilter()
                guard viewer.filtered.count == 1 else { throw DemoError(message: "Viewer level/search filter failed") }
                viewer.search.stringValue = ""
                viewer.filters.setSelected(true, forSegment: 0)
                viewer.applyFilter()
                try render(root.view, to: directory.appendingPathComponent("05-viewer.png"))
                root.back(nil)
                root.back(nil)
                guard root.page === home else { throw DemoError(message: "Back navigation lost the demo state") }
                home.table.scrollRowToVisible(19)
                try render(root.view, to: directory.appendingPathComponent("06-configuration.png"))
                home.table.scrollRowToVisible(home.table.numberOfRows - 1)
                try render(root.view, to: directory.appendingPathComponent("07-instance-info.png"))
                var passes = 0
                root.previewAlertHandler = { title, _ in
                    if title == DemoL10n.text("verify.pass.title") { passes += 1 }
                }
                home.concurrentThreads()
                let actionDeadline = Date().addingTimeInterval(30)
                func verifyActions() {
                    if root.busy && Date() < actionDeadline {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: verifyActions)
                        return
                    }
                    if !root.busy && passes == 1 {
                        passes = 2
                        home.concurrentProcesses()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: verifyActions)
                        return
                    }
                    guard !root.busy, passes == 3 else {
                        FileHandle.standardError.write(Data("Demo concurrency actions failed: \(root.statusLabel.stringValue)\n".utf8))
                        exit(1)
                    }
                    root.shutdown()
                    try? FileManager.default.removeItem(at: temporary)
                    print("MXLOGGER_NATIVE_MACOS_UI_OK: Storyboard, toggles, navigation, English/Chinese, filters, thread/process actions")
                    exit(0)
                }
                verifyActions()
            } catch {
                FileHandle.standardError.write(Data("\(error)\n".utf8))
                exit(1)
            }
        }
        finishWhenLoaded()
    }
    private static func render(_ view: NSView, to url: URL) throws {
        view.layoutSubtreeIfNeeded()
        view.display()
        guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw DemoError(message: "Could not render preview")
        }
        view.cacheDisplay(in: view.bounds, to: image)
        guard let png = image.representation(using: .png, properties: [:]) else {
            throw DemoError(message: "Could not encode preview")
        }
        try png.write(to: url)
    }
}
#endif
