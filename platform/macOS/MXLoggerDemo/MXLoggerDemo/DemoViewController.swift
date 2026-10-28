import AppKit

class DemoPageController: NSViewController {
    weak var owner: DemoViewController?
    func refresh() {}
}

final class DemoViewController: NSViewController {
    @IBOutlet weak var content: NSView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var languageButton: NSButton!
    @IBOutlet weak var statusLabel: NSTextField!
    var session: DemoSession?
    private(set) var page: DemoPageController?
    private var history: [DemoPageController] = []
    var selectedFile = ""
    #if DEBUG
    var previewAlertHandler: ((String, String) -> Void)?
    #endif
    var busy = false { didSet { backButton.isEnabled = !busy; languageButton.isEnabled = !busy } }

    override func viewDidLoad() {
        super.viewDidLoad()
        show("Landing", remember: false)
    }

    func show(_ identifier: String, remember: Bool = true) {
        guard !busy else { return }
        if remember, let page = page { history.append(page) }
        page?.view.removeFromSuperview()
        page?.removeFromParent()
        let next = storyboard!.instantiateController(withIdentifier: identifier) as! DemoPageController
        next.identifier = NSUserInterfaceItemIdentifier(identifier)
        next.owner = self
        addChild(next)
        next.view.frame = content.bounds
        next.view.autoresizingMask = [.width, .height]
        content.addSubview(next.view)
        page = next
        updateNavigation()
        next.refresh()
    }

    private func updateNavigation() {
        let identifier = page?.identifier?.rawValue ?? "Landing"
        backButton.isHidden = history.isEmpty
        backButton.title = DemoL10n.choose("‹ Back", "‹ 返回")
        languageButton.title = DemoL10n.switchTitle
        titleLabel.stringValue = identifier == "Landing" ? "" : (identifier == "Files" ? DemoL10n.text("filelist.title") : identifier == "Viewer" ? selectedFile : "MXLogger Demo")
    }

    @IBAction func back(_ sender: Any?) {
        guard !busy, let previous = history.popLast() else { return }
        page?.view.removeFromSuperview()
        page?.removeFromParent()
        addChild(previous)
        previous.view.frame = content.bounds
        previous.view.autoresizingMask = [.width, .height]
        content.addSubview(previous.view)
        page = previous
        updateNavigation()
        previous.refresh()
    }

    @IBAction func toggleLanguage(_ sender: Any?) {
        guard !busy else { return }
        DemoL10n.toggle()
        updateNavigation()
        page?.refresh()
    }

    func enter() {
        do {
            if session == nil { session = try DemoSession(configuration: DemoConfiguration()) }
            show("Home")
        } catch { notify(error.localizedDescription, error: true) }
    }

    func notify(_ message: String, error: Bool = false) {
        statusLabel.textColor = error ? .systemRed : .secondaryLabelColor
        statusLabel.stringValue = message
    }

    func alert(_ title: String, _ detail: String) {
        #if DEBUG
        if let handler = previewAlertHandler { handler(title, detail); return }
        #endif
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: DemoL10n.text("common.ok"))
        alert.runModal()
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func shutdown() {
        (page as? DemoHomeViewController)?.waitForWorker()
        session?.close()
    }
}

final class DemoLandingViewController: DemoPageController {
    @IBOutlet weak var subtitle: NSTextField!
    @IBOutlet weak var enterButton: NSButton!
    @IBOutlet weak var versionLabel: NSTextField!
    override func refresh() {
        subtitle.stringValue = DemoL10n.choose("High-performance cross-platform logging built on mmap\nAES-CFB 128 encryption · iOS / macOS / Android / Flutter", "基于 mmap 的高性能跨平台日志库\nAES-CFB 128 加密 · iOS / macOS / Android / Flutter")
        enterButton.title = DemoL10n.text("entry.button")
        enterButton.needsDisplay = true
        versionLabel.stringValue = "macOS Native Demo · MXLogger 2.2.0"
    }
    @IBAction func enter(_ sender: Any?) { owner?.enter() }
}
