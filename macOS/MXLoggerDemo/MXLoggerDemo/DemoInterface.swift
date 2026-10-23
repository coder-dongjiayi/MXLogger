import AppKit

// The same palette, logo, labels and sample parameters as the iOS/Android/Flutter demos.
enum DemoStyle {
    static let brand = color(0x4F46E5)
    static let levels = [color(0x8E8E93), color(0x007AFF), color(0xFF9500), color(0xFF3B30), color(0xAF52DE)]
    static let names = ["Debug", "Info", "Warn", "Error", "Fatal"]
    static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
    static var dark: Bool {
        if #available(macOS 10.14, *) { return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
        return false
    }
    static var background: NSColor { color(dark ? 0x111113 : 0xF2F2F7) }
    static var card: NSColor { color(dark ? 0x1C1C1E : 0xFFFFFF) }
    static func bytes(_ count: UInt) -> String {
        if count < 1024 { return "\(count) B" }
        if count < 1024 * 1024 { return String(format: "%.1f KB", Double(count) / 1024) }
        return String(format: "%.2f MB", Double(count) / 1024 / 1024)
    }
    static func age(_ seconds: UInt) -> String {
        if seconds == 0 { return DemoL10n.text("common.unlimited") }
        if seconds < 3600 { return DemoL10n.text("duration.minutes.fmt", seconds / 60) }
        if seconds < 86400 { return DemoL10n.text("duration.hours.fmt", seconds / 3600) }
        return DemoL10n.text("duration.days.fmt", seconds / 86400)
    }
    static func date(_ value: Any?) -> String {
        guard var time = Double(String(describing: value ?? "")), time > 0 else { return "—" }
        if time > 1e14 { time /= 1e6 } else if time > 1e11 { time /= 1e3 }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date(timeIntervalSince1970: time))
    }
    static func icon(_ name: String, fallback: String) -> NSImage? {
        if #available(macOS 11, *) { return NSImage(systemSymbolName: name, accessibilityDescription: nil) }
        return NSImage(named: NSImage.Name(fallback))
    }
}

enum DemoL10n {
    static var forcedLanguage: String?
    static var chinese: Bool { (forcedLanguage ?? UserDefaults.standard.string(forKey: "MXDemoLanguage")) == "zh-Hans" }
    static var switchTitle: String { chinese ? "English" : "中文" }
    static func toggle() {
        let next = chinese ? "en" : "zh-Hans"
        if forcedLanguage != nil { forcedLanguage = next }
        else { UserDefaults.standard.set(next, forKey: "MXDemoLanguage") }
        NotificationCenter.default.post(name: .init("MXDemoLanguageChanged"), object: nil)
    }
    static func choose(_ en: String, _ zh: String) -> String { chinese ? zh : en }
    static func text(_ key: String, _ args: CVarArg...) -> String {
        let language = chinese ? "zh-Hans" : "en"
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        let value = bundle.localizedString(forKey: key, value: key, table: nil)
        return args.isEmpty ? value : String(format: value, arguments: args)
    }
}

final class DemoBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) { DemoStyle.background.setFill(); bounds.fill() }
}

final class DemoSummaryView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18)
        NSGradient(starting: DemoStyle.brand, ending: DemoStyle.color(0x6861F2))?.draw(in: path, angle: 0)
    }
}

final class DemoTableView: NSTableView {
    override func layout() {
        super.layout()
        if let column = tableColumns.first, bounds.width > 0, abs(column.width - bounds.width) > 1 {
            column.width = bounds.width
        }
    }
}

final class DemoPrimaryButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        (isHighlighted ? DemoStyle.brand.withAlphaComponent(0.8) : DemoStyle.brand).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.white])
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}

final class DemoToggleButton: NSButton {
    override func awakeFromNib() { super.awakeFromNib(); setButtonType(.switch) }
    override var state: NSControl.StateValue { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let track = NSRect(x: (bounds.width - 36) / 2, y: (bounds.height - 20) / 2, width: 36, height: 20)
        let active = state == .on
        let color = active ? NSColor.systemGreen : DemoStyle.color(DemoStyle.dark ? 0x48484A : 0xD1D1D6)
        color.withAlphaComponent(isEnabled ? 1 : 0.4).setFill()
        NSBezierPath(roundedRect: track, xRadius: 10, yRadius: 10).fill()
        NSColor.white.withAlphaComponent(isEnabled ? 1 : 0.6).setFill()
        NSBezierPath(ovalIn: NSRect(x: track.minX + (active ? 18 : 2), y: track.minY + 2, width: 16, height: 16)).fill()
    }
}

final class DemoActionCell: NSTableCellView {
    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var heading: NSTextField!
    @IBOutlet weak var subtitle: NSTextField!
    @IBOutlet weak var value: NSTextField!
    @IBOutlet weak var toggle: NSButton!
    var onToggle: ((Bool) -> Void)?
    var header = false
    var tint = DemoStyle.brand
    var roundedTop = true
    var roundedBottom = true
    override func draw(_ dirtyRect: NSRect) {
        guard !header else { return }
        DemoStyle.card.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        if !roundedTop { NSRect(x: 0, y: bounds.height - 12, width: bounds.width, height: 12).fill() }
        if !roundedBottom {
            NSRect(x: 0, y: 0, width: bounds.width, height: 12).fill()
            DemoStyle.color(DemoStyle.dark ? 0x2C2C2E : 0xE5E5EA).setStroke()
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 62, y: 0.5))
            line.line(to: NSPoint(x: bounds.width, y: 0.5))
            line.lineWidth = 0.5
            line.stroke()
        }
        tint.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: NSRect(x: 14, y: (bounds.height - 34) / 2, width: 34, height: 34), xRadius: 9, yRadius: 9).fill()
    }
    @IBAction func toggleChanged(_ sender: NSButton) { onToggle?(sender.state == .on) }
    func configure(title: String, subtitle: String, value: String, symbol: String, tint: NSColor,
                   header: Bool = false, switchValue: Bool? = nil, switchEnabled: Bool = true) {
        self.header = header
        roundedTop = true
        roundedBottom = true
        self.tint = tint
        heading.stringValue = title
        heading.font = .systemFont(ofSize: header ? 12 : 14, weight: header ? .medium : .regular)
        heading.textColor = header ? .secondaryLabelColor : .labelColor
        self.subtitle.stringValue = subtitle
        self.subtitle.textColor = .secondaryLabelColor
        self.subtitle.isHidden = header || subtitle.isEmpty
        self.value.stringValue = value
        self.value.textColor = .secondaryLabelColor
        self.value.alignment = .right
        self.value.isHidden = switchValue != nil
        icon.image = DemoStyle.icon(symbol, fallback: NSImage.infoName)
        icon.isHidden = header
        if #available(macOS 10.14, *) { icon.contentTintColor = tint }
        toggle.isHidden = switchValue == nil
        toggle.state = switchValue == true ? .on : .off
        toggle.isEnabled = switchEnabled
        onToggle = nil
        needsDisplay = true
    }
}

final class DemoRecordCell: NSTableCellView {
    @IBOutlet weak var badge: NSTextField!
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var timeLabel: NSTextField!
    @IBOutlet weak var messageLabel: NSTextField!
    @IBOutlet weak var tagLabel: NSTextField!
    override func draw(_ dirtyRect: NSRect) {
        DemoStyle.card.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 3), xRadius: 12, yRadius: 12).fill()
    }
    func configure(_ record: [String: Any]) {
        let level = min(4, max(0, Int(record["level"] as? String ?? "0") ?? 0))
        let failed = (Int(record["error_code"] as? String ?? "0") ?? 0) != 0
        badge.stringValue = failed ? "BAD" : DemoStyle.names[level].uppercased()
        badge.textColor = .white
        badge.drawsBackground = true
        badge.backgroundColor = failed ? .systemRed : DemoStyle.levels[level]
        badge.alignment = .center
        nameLabel.stringValue = record["name"] as? String ?? "—"
        timeLabel.stringValue = DemoStyle.date(record["timestamp"])
        messageLabel.stringValue = record["msg"] as? String ?? ""
        let tag = record["tag"] as? String ?? ""
        let main = record["is_main_thread"] as? String == "1"
        tagLabel.stringValue = "# \(tag)    \(DemoL10n.text(main ? "record.thread.main" : "record.thread.sub")) · tid \(record["thread_id"] ?? "—")"
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right
        tagLabel.textColor = .secondaryLabelColor
    }
}
