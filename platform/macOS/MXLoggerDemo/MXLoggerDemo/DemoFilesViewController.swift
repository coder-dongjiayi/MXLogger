import AppKit

final class DemoFilesViewController: DemoPageController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var summary: NSTextField!
    private var files: [[String: String]] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.action = #selector(openFile)
        table.backgroundColor = DemoStyle.background
        table.selectionHighlightStyle = .none
        if #available(macOS 11, *) { table.style = .plain }
    }
    override func refresh() {
        guard let logger = owner?.session?.logger else { return }
        files = logger.logFiles()
        summary.stringValue = DemoL10n.text("filelist.summary.fmt", UInt(files.count), DemoStyle.bytes(logger.logSize))
        table.reloadData()
    }
    @IBAction func refreshFiles(_ sender: Any?) { refresh() }
    func numberOfRows(in tableView: NSTableView) -> Int { files.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ActionCell"), owner: self) as! DemoActionCell
        let file = files[row]
        cell.configure(title: file["name"] ?? "", subtitle: DemoL10n.text("filelist.dates.fmt", DemoStyle.date(file["create_timestamp"]), DemoStyle.date(file["last_timestamp"])),
                       value: DemoStyle.bytes(UInt(file["size"] ?? "0") ?? 0) + "  ›", symbol: "doc.text.fill", tint: DemoStyle.brand)
        return cell
    }
    @objc private func openFile() { if files.indices.contains(table.clickedRow) { open(row: table.clickedRow) } }
    func open(row: Int) {
        owner?.selectedFile = files[row]["name"] ?? ""
        owner?.show("Viewer")
    }
}

final class DemoLogViewerController: DemoPageController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var filters: NSSegmentedControl!
    @IBOutlet weak var search: NSSearchField!
    @IBOutlet weak var summary: NSTextField!
    private var records: [[String: Any]] = []
    private(set) var filtered: [[String: Any]] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(showRecord)
        table.backgroundColor = DemoStyle.background
        table.selectionHighlightStyle = .none
        if #available(macOS 11, *) { table.style = .plain }
        search.delegate = self
    }
    override func refresh() {
        filters.setLabel(DemoL10n.text("viewer.segment.all"), forSegment: 0)
        search.placeholderString = DemoL10n.text("viewer.search.placeholder")
        guard let owner = owner, let session = owner.session else { return }
        owner.busy = true
        summary.stringValue = DemoL10n.text("viewer.loading")
        let file = owner.selectedFile
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let records = session.records(file: file)
            DispatchQueue.main.async {
                guard let self = self else { return }
                owner.busy = false
                self.records = records
                self.applyFilter()
            }
        }
    }
    @IBAction func filterChanged(_ sender: Any?) { applyFilter() }
    func controlTextDidChange(_ obj: Notification) { applyFilter() }
    func applyFilter() {
        let selected = filters.selectedSegment - 1
        let keyword = search.stringValue.lowercased()
        filtered = records.filter { record in
            let level = Int(record["level"] as? String ?? "0") ?? 0
            let text = ["msg", "name", "tag"].map { String(describing: record[$0] ?? "") }.joined(separator: " ").lowercased()
            return (selected < 0 || selected == level) && (keyword.isEmpty || text.contains(keyword))
        }
        summary.stringValue = "\(filtered.count) / \(records.count) " + DemoL10n.choose("records · double-click to view full details", "条记录 · 双击查看完整内容")
        table.reloadData()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RecordCell"), owner: self) as! DemoRecordCell
        cell.configure(filtered[row])
        return cell
    }
    @objc private func showRecord() {
        guard filtered.indices.contains(table.clickedRow) else { return }
        let record = filtered[table.clickedRow]
        let alert = NSAlert()
        alert.messageText = record["name"] as? String ?? DemoL10n.text("viewer.title")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 340))
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.font = NSFont.userFixedPitchFont(ofSize: 12)
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        text.string = data.flatMap { String(data: $0, encoding: .utf8) } ?? String(describing: record)
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        alert.accessoryView = scroll
        alert.addButton(withTitle: DemoL10n.text("common.copy"))
        alert.addButton(withTitle: DemoL10n.text("common.close"))
        if alert.runModal() == .alertFirstButtonReturn { owner?.copy(record["msg"] as? String ?? "") }
    }
}
