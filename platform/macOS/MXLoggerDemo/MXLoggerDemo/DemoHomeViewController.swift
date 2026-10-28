import AppKit
import MXLogger

final class DemoHomeViewController: DemoPageController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var sizeValue: NSTextField!
    @IBOutlet weak var filesValue: NSTextField!
    @IBOutlet weak var levelValue: NSTextField!
    @IBOutlet weak var policyValue: NSTextField!
    @IBOutlet weak var sizeCaption: NSTextField!
    @IBOutlet weak var filesCaption: NSTextField!
    @IBOutlet weak var levelCaption: NSTextField!
    @IBOutlet weak var policyCaption: NSTextField!
    @IBOutlet weak var namespaceLabel: NSTextField!
    private struct Row {
        var title: String
        var subtitle = ""
        var value = "›"
        var icon = "info.circle"
        var tint = DemoStyle.brand
        var header = false
        var toggle: Bool?
        var switchEnabled = true
        var action: (() -> Void)?
        var change: ((Bool) -> Void)?
    }
    private var rows: [Row] = []
    private var count = 0
    private var perf = ""
    private var worker: Process?
    private let tasks = DispatchGroup()
    private var logger: MXLogger { owner!.session!.logger }
    private var session: DemoSession { owner!.session! }
    private var consoleAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(activateRow)
        table.backgroundColor = DemoStyle.background
        table.selectionHighlightStyle = .none
        if #available(macOS 11, *) { table.style = .plain }
    }
    override func refresh() {
        guard owner?.session != nil else { return }
        sizeValue.stringValue = DemoStyle.bytes(logger.logSize)
        filesValue.stringValue = "\(logger.logFiles().count)"
        levelValue.stringValue = DemoStyle.names[min(4, max(0, logger.level))]
        policyValue.stringValue = DemoL10n.text("home.card.policy.hourly")
        namespaceLabel.stringValue = DemoL10n.text("home.card.namespace.fmt", session.configuration.namespace)
        for (label, key) in [(sizeCaption, "size"), (filesCaption, "files"), (levelCaption, "level"), (policyCaption, "policy")] {
            label?.stringValue = DemoL10n.text("home.card.\(key)")
        }
        buildRows()
        table.reloadData()
    }
    private func section(_ title: String) { rows.append(Row(title: title, value: "", header: true)) }
    private func action(_ title: String, _ subtitle: String, _ icon: String, _ tint: NSColor = DemoStyle.brand,
                        value: String = "›", run: @escaping () -> Void) {
        rows.append(Row(title: title, subtitle: subtitle, value: value, icon: icon, tint: tint, action: run))
    }
    private func buildRows() {
        rows = []
        section(DemoL10n.text("home.section.write"))
        let icons = ["ladybug.fill", "info.circle.fill", "exclamationmark.triangle.fill", "xmark.circle.fill", "flame.fill"]
        for index in 0..<5 {
            action(DemoL10n.text("home.write.level.title", DemoStyle.names[index]),
                   "\(DemoStyle.names[index].lowercased())(name:message:tag:)", icons[index], DemoStyle.levels[index]) { [weak self] in self?.writeSample(index) }
        }
        action(DemoL10n.text("home.write.network.title"), DemoL10n.text("home.write.network.subtitle"), "network", .systemTeal) { [weak self] in self?.networkLog() }
        action(DemoL10n.choose("log() Generic Write", "log() 通用写入"), DemoL10n.text("home.write.custom.subtitle"), "slider.horizontal.3") { [weak self] in
            self?.write(3, DemoL10n.text("log.pay.msg"), name: "pay", tag: "order", generic: true)
        }
        action(DemoL10n.text("home.write.key.title"), "MXLogger.info(loggerToken:name:message:tag:)", "key.fill", .systemBrown) { [weak self] in
            self?.write(1, DemoL10n.text("log.module.msg"), name: "module.user", tag: "module", token: true)
        }
        section(DemoL10n.text("home.section.config"))
        action(DemoL10n.text("home.config.level.title"), DemoL10n.text("home.config.level.subtitle"), "slider.horizontal.3", .systemBlue, value: DemoStyle.names[logger.level]) { [weak self] in
            self?.pick(DemoL10n.text("home.config.level.title"), DemoStyle.names, selected: self?.logger.level ?? 0) { self?.logger.level = $0 }
        }
        rows.append(Row(title: DemoL10n.text("home.config.console.title"), subtitle: DemoL10n.text(consoleAvailable ? "home.config.console.subtitle" : "home.config.console.subtitle.release"), icon: "terminal.fill", tint: .systemGray,
                        toggle: logger.isConsoleEnabled, switchEnabled: consoleAvailable, change: { [weak self] on in self?.logger.isConsoleEnabled = on }))
        rows.append(Row(title: DemoL10n.text("home.config.enable.title"), subtitle: DemoL10n.text("home.config.enable.subtitle"), icon: "power", tint: .systemGreen,
                        toggle: logger.isEnabled, change: { [weak self] on in self?.logger.isEnabled = on }))
        action(DemoL10n.text("home.config.age.title"), DemoL10n.text("home.config.age.subtitle"), "clock.fill", .systemOrange, value: DemoStyle.age(logger.maxDiskAge)) { [weak self] in
            let values: [UInt] = [0, 60, 3600, 86400, 604800]
            self?.pick(DemoL10n.text("home.config.age.title"), [DemoL10n.text("common.unlimited"), DemoL10n.text("duration.1min"), DemoL10n.text("duration.1hour"), DemoL10n.text("duration.1day"), DemoL10n.text("duration.7days")]) { self?.logger.maxDiskAge = values[$0] }
        }
        action(DemoL10n.text("home.config.size.title"), DemoL10n.text("home.config.size.subtitle"), "internaldrive.fill", .systemPink, value: logger.maxDiskSize == 0 ? DemoL10n.text("common.unlimited") : DemoStyle.bytes(logger.maxDiskSize)) { [weak self] in
            let values: [UInt] = [0, 1024 * 1024, 10 * 1024 * 1024, 50 * 1024 * 1024]
            self?.pick(DemoL10n.text("home.config.size.title"), [DemoL10n.text("common.unlimited"), "1 MB", "10 MB", "50 MB"]) { self?.logger.maxDiskSize = values[$0] }
        }
        section(DemoL10n.choose("macOS cleanup is explicit; entering background does not trigger it.", "macOS 需手动清理，进入后台不会触发清理。"))
        section(DemoL10n.text("home.section.perf"))
        action(DemoL10n.text("home.perf.bench.title"), DemoL10n.text("home.perf.bench.subtitle"), "speedometer", .systemGreen, value: perf.isEmpty ? "›" : perf) { [weak self] in self?.benchmark() }
        action(DemoL10n.text("home.perf.thread.title"), DemoL10n.text("home.perf.thread.subtitle"), "cpu.fill", .systemTeal) { [weak self] in self?.concurrentThreads() }
        action(DemoL10n.choose("Concurrent Multi-process Write", "多进程并发写入"), DemoL10n.choose("Two processes share one directory; verify 2,000 records and their order", "两个进程共用日志目录，自动校验 2000 条记录及顺序"), "square.stack.3d.up.fill", .systemPurple) { [weak self] in self?.concurrentProcesses() }
        section(DemoL10n.text("home.section.file"))
        action(DemoL10n.text("home.file.browse.title"), "logFiles() + select(filePath:cryptKey:iv:)", "folder.fill", .systemBlue) { [weak self] in self?.owner?.show("Files") }
        action(DemoL10n.text("home.file.expire.title"), "removeExpireData()", "clock.arrow.circlepath", .systemOrange) { [weak self] in self?.logger.removeExpireData(); self?.done("toast.expire.done") }
        action(DemoL10n.text("home.file.before.title"), DemoL10n.text("home.file.before.subtitle"), "trash.slash.fill", .systemOrange) { [weak self] in self?.logger.removeBeforeAllData(); self?.done("toast.before.done") }
        action(DemoL10n.text("home.file.all.title"), "removeAllData()", "trash.fill", .systemRed) { [weak self] in self?.removeAll() }
        section(DemoL10n.text("home.section.info"))
        action("loggerToken", logger.loggerToken, "number", value: "⧉") { [weak self] in guard let self = self else { return }; self.owner?.copy(self.logger.loggerToken); self.done("toast.key.copied") }
        action(DemoL10n.text("home.info.path.title"), logger.diskCachePath, "gearshape.fill", .systemGray, value: "⧉") { [weak self] in guard let self = self else { return }; self.owner?.copy(self.logger.diskCachePath); self.done("toast.path.copied") }
        action(DemoL10n.choose("Open in Finder", "在 Finder 中打开"), "Application Support/<bundle-id>/MXLogger", "folder.fill", .systemBlue) { [weak self] in
            guard let self = self else { return }; NSWorkspace.shared.open(URL(fileURLWithPath: self.logger.diskCachePath))
        }
        action(DemoL10n.text("home.info.error.title"), DemoL10n.text("home.info.error.subtitle"), "text.bubble.fill", .systemOrange) { [weak self] in
            guard let self = self else { return }; let text = self.logger.errorDesc(); self.owner?.alert("errorDesc", text.isEmpty ? DemoL10n.text("alert.no.error") : text)
        }
        action(DemoL10n.text("home.info.rebuild.title"), "destroy(namespace:) → shared(namespace:…)", "arrow.clockwise", .systemRed) { [weak self] in
            guard let self = self else { return }
            let configuration = self.session.configuration
            self.session.close()
            do { self.owner?.session = try DemoSession(configuration: configuration); self.done("toast.rebuild.done") }
            catch { self.owner?.notify(error.localizedDescription, error: true) }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { rows[row].header ? 34 : 66 }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = rows[row]
        if item.header {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: self) as! NSTableCellView
            cell.textField?.stringValue = item.title
            cell.textField?.textColor = .secondaryLabelColor
            return cell
        }
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ActionCell"), owner: self) as! DemoActionCell
        cell.configure(title: item.title, subtitle: item.subtitle, value: item.value, symbol: item.icon,
                       tint: item.tint, header: item.header, switchValue: item.toggle, switchEnabled: item.switchEnabled)
        cell.roundedTop = row == 0 || rows[row - 1].header
        cell.roundedBottom = row + 1 == rows.count || rows[row + 1].header
        cell.onToggle = { [weak self] on in guard self?.owner?.busy == false else { return }; item.change?(on); self?.refresh() }
        return cell
    }
    @objc private func activateRow() {
        guard owner?.busy == false, rows.indices.contains(table.clickedRow) else { return }
        rows[table.clickedRow].action?()
    }
    private func pick(_ title: String, _ values: [String], selected: Int = 0, change: (Int) -> Void) {
        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        picker.addItems(withTitles: values)
        picker.selectItem(at: selected)
        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = picker
        alert.addButton(withTitle: DemoL10n.text("common.ok"))
        alert.addButton(withTitle: DemoL10n.text("common.cancel"))
        if alert.runModal() == .alertFirstButtonReturn { change(picker.indexOfSelectedItem); refresh() }
    }
    func writeSample(_ level: Int) {
        write(level, DemoL10n.text("log.msg.fmt", UInt(count + 1), DemoStyle.names[level], DemoStyle.date(Date().timeIntervalSince1970)))
    }
    private func write(_ level: Int, _ message: String, name: String = "mxlogger", tag: String = "demo", token: Bool = false, generic: Bool = false) {
        do {
            try session.write(level: level, message: message, name: name, tag: tag, viaToken: token, generic: generic)
            count += 1
            owner?.notify(DemoL10n.text("toast.write.success", DemoStyle.names[level]))
            refresh()
        } catch { owner?.notify(error.localizedDescription, error: true) }
    }
    private func networkLog() {
        let payload: [String: Any] = ["uri": "https://api.example.com/v1/login", "method": "POST", "statusCode": 200, "costTime": "183ms", "requestBody": ["mobile": "188****8888"], "response": ["code": 0, "msg": "ok"]]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) { write(1, String(decoding: data, as: UTF8.self), name: "network", tag: "request") }
    }
    private func done(_ key: String) { owner?.notify(DemoL10n.text(key)); refresh() }
    private func removeAll() {
        let alert = NSAlert()
        alert.messageText = DemoL10n.text("alert.removeall.title")
        alert.informativeText = DemoL10n.text("alert.removeall.message")
        alert.addButton(withTitle: DemoL10n.text("common.remove"))
        alert.addButton(withTitle: DemoL10n.text("common.cancel"))
        if alert.runModal() == .alertFirstButtonReturn { logger.removeAllData(); done("toast.removeall.done") }
    }
    private func begin() -> Bool {
        guard owner?.busy == false, logger.isEnabled else { return false }
        owner?.busy = true
        table.isEnabled = false
        owner?.notify(DemoL10n.text("toast.concurrent.running"))
        return true
    }
    private func finish(console: Bool, error: Error? = nil) {
        logger.isConsoleEnabled = console
        owner?.busy = false
        table.isEnabled = true
        refresh()
        if let error = error { owner?.notify(error.localizedDescription, error: true) }
    }
    private func benchmark() {
        guard begin() else { return }
        let session = self.session
        let console = logger.isConsoleEnabled
        logger.isConsoleEnabled = false
        tasks.enter()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let start = DispatchTime.now().uptimeNanoseconds
            var failure: Error?
            do {
                for index in 0..<100000 {
                    let message = String(format: "[%06ld] This is a benchmark loooooooooooooooooooooooooooooog", index + 1)
                    try session.write(level: max(1, session.logger.level), message: message, name: "benchmark", tag: "perf")
                }
            } catch { failure = error }
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
            self?.tasks.leave()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.perf = String(format: "%.0f ms", milliseconds)
                self.finish(console: console, error: failure)
                if failure == nil { self.owner?.notify(DemoL10n.text("toast.bench.done", milliseconds)) }
            }
        }
    }
    private func verify(_ prefixes: [String: Int]) throws -> String {
        let records = logger.logFiles().compactMap { $0["name"] }.sorted().flatMap { Array(session.records(file: $0).reversed()) }
        var lines: [String] = []
        for (prefix, expected) in prefixes.sorted(by: { $0.key < $1.key }) {
            let messages = records.filter { $0["tag"] as? String == prefix }.compactMap { $0["msg"] as? String }
            guard messages == (0..<expected).map({ "\(prefix):\($0)" }) else {
                throw DemoError(message: "\(prefix): \(messages.count)/\(expected), " + DemoL10n.text("verify.fail.title"))
            }
            lines.append("\(prefix): \(messages.count)/\(expected) ✓")
        }
        return lines.joined(separator: "\n")
    }
    func concurrentThreads() {
        guard begin() else { return }
        let console = logger.isConsoleEnabled
        logger.isConsoleEnabled = false
        let run = "mt-\(UUID().uuidString.prefix(8))"
        let session = self.session
        let failures = OperationQueue()
        failures.maxConcurrentOperationCount = 1
        var failure: Error?
        let priorities: [DispatchQoS.QoSClass] = [.userInitiated, .default, .utility]
        for index in 0..<3 {
            tasks.enter()
            DispatchQueue.global(qos: priorities[index]).async { [weak self] in
                do { try session.batch(prefix: "\(run)-queue\(index)", count: 1000) }
                catch { let error = error; failures.addOperation { failure = error } }
                self?.tasks.leave()
            }
        }
        do { try session.batch(prefix: "\(run)-main", count: 200) }
        catch { let error = error; failures.addOperation { failure = error } }
        tasks.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            failures.waitUntilAllOperationsAreFinished()
            do {
                if let failure = failure { throw failure }
                let result = try self.verify(["\(run)-queue0": 1000, "\(run)-queue1": 1000, "\(run)-queue2": 1000, "\(run)-main": 200])
                self.finish(console: console)
                self.owner?.alert(DemoL10n.text("verify.pass.title"), result)
            } catch { self.finish(console: console, error: error) }
        }
    }
    func concurrentProcesses() {
        guard begin() else { return }
        let console = logger.isConsoleEnabled
        logger.isConsoleEnabled = false
        let run = "mp-\(UUID().uuidString.prefix(8))"
        do {
            let process = try session.launchWorker(count: 1000, prefix: "\(run)-worker") { [weak self] process in
                DispatchQueue.main.async {
                    guard let self = self, self.worker === process else { return }
                    self.worker = nil
                    do {
                        try DemoSession.checkWorker(process)
                        let result = try self.verify(["\(run)-worker": 1000, "\(run)-parent": 1000])
                        self.finish(console: console)
                        self.owner?.alert(DemoL10n.text("verify.pass.title"), result)
                    } catch { self.finish(console: console, error: error) }
                }
            }
            worker = process
            try session.batch(prefix: "\(run)-parent", count: 1000)
        } catch {
            if let process = worker { process.terminationHandler = nil; process.waitUntilExit() }
            worker = nil
            finish(console: console, error: error)
        }
    }
    func waitForWorker() { tasks.wait(); worker?.waitUntilExit() }
}
