import AppKit

struct ProfileOptions {
    var records = 100000
    var rounds = 3
    var stride = 64
    var directory: URL
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        directory = base.appendingPathComponent("MXLoggerProfile/Reports/\(stamp)-\(UUID().uuidString.prefix(8))")
    }
}

final class ProfileRunner {
    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(); let n = sorted.count
        return n % 2 == 0 ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2 : sorted[n / 2]
    }
    static func sysctl(_ key: String) -> String {
        let task = Process(); let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        task.arguments = ["-n", key]; task.standardOutput = pipe; task.standardError = Pipe()
        do { try task.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch { return "unavailable" }
    }
    static func run(_ options: ProfileOptions, status: @escaping (String) -> Void) throws -> String {
        guard (1...1_000_000).contains(options.records), (1...20).contains(options.rounds),
              (1...65536).contains(options.stride) else { throw NSError(domain: "Invalid options", code: 2) }
        try FileManager.default.createDirectory(at: options.directory, withIntermediateDirectories: true)
        var report: [String: Any] = ["schema_version": 1, "passed": false, "records": options.records,
            "rounds": options.rounds, "sample_stride": options.stride,
            "scope": "Release; same DemoSession.write and message as native Demo; userInitiated background queue; no per-record UI; initialization/explicit flush/readback/report excluded from write seconds",
            "machine": ["os": ProcessInfo.processInfo.operatingSystemVersionString,
                        "model": sysctl("hw.model"), "cpu": sysctl("machdep.cpu.brand_string"),
                        "logical_cores": sysctl("hw.logicalcpu"), "memory_bytes": sysctl("hw.memsize"),
                        "translated": sysctl("sysctl.proc_translated") == "1"],
            "data_directory": options.directory.path,
            "notes": ["Stage durations are sampled exclusive estimates, not a normalized partition of wall time.",
                      "Rare open/close/resize/map/unmap/growth operations are fully timed.",
                      "swift_other includes bridging outside innerLog and profiling bookkeeping.",
                      "Control cases change allocation/lifetime behavior; do not mechanically subtract their totals."]]
        #if arch(arm64)
        report["process_arch"] = "arm64"
        #else
        report["process_arch"] = "x86_64"
        #endif
        if let url = Bundle.main.url(forResource: "build-info", withExtension: "json"),
           let data = try? Data(contentsOf: url), let info = try? JSONSerialization.jsonObject(with: data) {
            report["build"] = info
        }
        var runs: [[String: Any]] = []
        func save(_ text: String) throws {
            report["runs"] = runs
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: options.directory.appendingPathComponent("summary.json"), options: .atomic)
            try text.write(to: options.directory.appendingPathComponent("summary.txt"), atomically: true, encoding: .utf8)
        }
        do {
            for round in 0..<options.rounds {
                var plans: [(String, Bool, String)] = []
                for encrypted in [false, true] {
                    let modes = round % 2 == 0 ? ["baseline", "sampled"] : ["sampled", "baseline"]
                    for mode in modes { plans.append(("demo_format", encrypted, mode)) }
                    plans.append(("demo_prebuilt", encrypted, "baseline"))
                    plans.append(("core_prebuilt", encrypted, "baseline"))
                }
                plans.append(("format_only", false, "baseline"))
                for (scenario, encrypted, mode) in plans {
                    let name = "round-\(round + 1)-\(scenario)-\(encrypted ? "aes" : "plain")-\(mode)"
                    status("\(round + 1)/\(options.rounds) · \(scenario) · \(encrypted ? "AES" : "Plain") · \(mode)")
                    // Re-running --self-test or reusing a report parent must
                    // never append into an earlier case's log files.
                    let directory = options.directory.appendingPathComponent(name + "-" + UUID().uuidString.prefix(8))
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let task = Process(); let pipe = Pipe()
                    let worker = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Workers/\(mode)/MXLoggerWorker")
                    task.executableURL = worker
                    task.arguments = ["--scenario", scenario, "--encrypted", encrypted ? "1" : "0",
                        "--records", String(options.records), "--stride", String(options.stride),
                        "--offset", String((round * 17) % options.stride), "--report", directory.path]
                    task.standardOutput = pipe; task.standardError = pipe
                    try task.run()
                    let log = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
                    try log.write(to: directory.appendingPathComponent("process.log"))
                    guard task.terminationStatus == 0 else {
                        throw NSError(domain: "Worker failed: \(name). See process.log and result.json", code: Int(task.terminationStatus))
                    }
                    let data = try Data(contentsOf: directory.appendingPathComponent("result.json"))
                    guard var result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          result["passed"] as? Bool == true else { throw NSError(domain: "Invalid worker result", code: 3) }
                    if mode == "sampled" {
                        guard let profile = result["profile"] as? [String: Any],
                              profile["records"] as? Int == options.records,
                              profile["stack_overflow"] as? Int == 0, profile["unclosed_scopes"] as? Int == 0,
                              let stages = profile["stages"] as? [[String: Any]] else { throw NSError(domain: "Invalid profiling collector state", code: 4) }
                        for name in ["objc_bridge", "thread_mutex", "metadata", "directory_lock", "directory_unlock", "append"] {
                            guard stages.first(where: { $0["name"] as? String == name })?["calls"] as? Int == options.records else {
                                throw NSError(domain: "Missing instrumented stage: \(name)", code: 5)
                            }
                        }
                    }
                    result["round"] = round + 1; result["mode"] = mode
                    result["report_directory"] = directory.lastPathComponent; runs.append(result)
                    try save("Running: \(name)\nCompleted \(runs.count) cases.\n")
                }
            }
            var summaries: [[String: Any]] = []
            var text = "MXLogger macOS Release diagnostic — \(options.records) records, \(options.rounds) rounds\n"
            text += "\(report["machine"]!)\nReports: \(options.directory.path)\n\n"
            for scenario in ["demo_format", "demo_prebuilt", "core_prebuilt", "format_only"] {
                for encrypted in [false, true] where scenario != "format_only" || !encrypted {
                    let selected = runs.filter { $0["scenario"] as? String == scenario && $0["encrypted"] as? Bool == encrypted }
                    let baseline = selected.filter { $0["mode"] as? String == "baseline" }.map { $0["seconds"] as! Double }
                    let sampled = selected.filter { $0["mode"] as? String == "sampled" }
                    let seconds = median(baseline)
                    var item: [String: Any] = ["scenario": scenario, "encrypted": encrypted,
                        "baseline_seconds": seconds, "baseline_min_seconds": baseline.min()!, "baseline_max_seconds": baseline.max()!]
                    text += String(format: "%@ / %@: %.3f ms (median, min %.3f, max %.3f)\n", scenario, encrypted ? "AES" : "Plain", seconds * 1000, baseline.min()! * 1000, baseline.max()! * 1000)
                    if !sampled.isEmpty {
                        let instrumented = median(sampled.map { $0["seconds"] as! Double })
                        item["sampled_seconds"] = instrumented
                        item["profiling_overhead_ratio"] = instrumented / seconds
                        let profiles = sampled.map { $0["profile"] as! [String: Any] }
                        let names = (profiles[0]["stages"] as! [[String: Any]]).map { $0["name"] as! String }
                        var stages: [[String: Any]] = []
                        for name in names {
                            let values = profiles.map { ($0["stages"] as! [[String: Any]]).first { $0["name"] as? String == name }! }
                            let ns = median(values.map { $0["estimated_ns"] as! Double })
                            stages.append(["name": name, "estimated_ms": ns / 1e6,
                                           "calls": values[0]["calls"]!, "share_of_sampled_wall": ns / (instrumented * 1e9)])
                        }
                        stages.sort { $0["estimated_ms"] as! Double > $1["estimated_ms"] as! Double }
                        item["stages"] = stages
                        let coverage = stages.reduce(0.0) { $0 + ($1["share_of_sampled_wall"] as! Double) }
                        item["estimated_coverage"] = coverage
                        text += String(format: "  Instrumented: %.3f ms, overhead ratio %.3f, estimated coverage %.1f%%\n", instrumented * 1000, instrumented / seconds, coverage * 100)
                        for stage in stages where stage["calls"] as! Int > 0 {
                            text += String(format: "  %-22@ %9.3f ms  %5.1f%%  calls=%@\n", stage["name"] as! String,
                                           stage["estimated_ms"] as! Double, (stage["share_of_sampled_wall"] as! Double) * 100, String(describing: stage["calls"]!))
                        }
                        if instrumented / seconds > 1.05 {
                            text += "  NOTE: profiling overhead >5%; use baseline for performance. Repeat with a larger sample stride to check estimate stability.\n"
                        }
                        if coverage < 0.85 || coverage > 1.15 { text += "  NOTE: sample estimates differ from wall time; inspect raw exact/sampled counts and repeat.\n" }
                    }
                    summaries.append(item); text += "\n"
                }
            }
            text += "Plain/AES use identical messages and API paths. Flush, verification and report output are excluded.\nStage estimates are exclusive, unadjusted for clock/profiler cost and not normalized to 100%.\n"
            report["cases"] = summaries; report["passed"] = true
            try save(text)
            return text
        } catch {
            report["error"] = error.localizedDescription
            try? save("FAILED: \(error.localizedDescription)\nReports: \(options.directory.path)\n")
            throw error
        }
    }
}

final class ProfileAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let button = NSButton(title: "运行 10 万条评测", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "Release · 明文/AES · 每组 3 轮 · 写入期间不刷新进度")
    private let output = NSTextView()
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MXLogger macOS 性能诊断（临时分支）"
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)])
        let heading = NSTextField(labelWithString: "与原生 macOS Demo 相同的消息和写入调用；完成后自动打开报告目录。")
        stack.addArrangedSubview(heading); stack.addArrangedSubview(button); stack.addArrangedSubview(status)
        button.target = self; button.action = #selector(start)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        output.isEditable = false; output.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        scroll.documentView = output; stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func start() {
        button.isEnabled = false; output.string = "评测进行中。每组之间更新状态；写入循环内无 UI 刷新。\n"
        window.standardWindowButton(.closeButton)?.isEnabled = false
        let options = ProfileOptions()
        DispatchQueue.global(qos: .userInitiated).async {
            let text: String
            do {
                text = try ProfileRunner.run(options) { message in DispatchQueue.main.async { self.status.stringValue = message } }
            } catch { text = "评测失败：\(error.localizedDescription)\n报告位置：\(options.directory.path)" }
            DispatchQueue.main.async {
                self.output.string = text; self.status.stringValue = "已结束：\(options.directory.path)"
                self.button.isEnabled = true; self.window.standardWindowButton(.closeButton)?.isEnabled = true
                NSWorkspace.shared.open(options.directory)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ProfileApplication {
    static func main() {
        if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--run") {
            var options = ProfileOptions()
            if CommandLine.arguments.contains("--self-test") { options.records = 256; options.rounds = 1; options.stride = 16 }
            func argument(_ name: String) -> String? {
                guard let i = CommandLine.arguments.firstIndex(of: name), i + 1 < CommandLine.arguments.count else { return nil }
                return CommandLine.arguments[i + 1]
            }
            if let path = argument("--report-dir") { options.directory = URL(fileURLWithPath: path) }
            if let value = argument("--records"), let count = Int(value) { options.records = count }
            if let value = argument("--rounds"), let count = Int(value) { options.rounds = count }
            if let value = argument("--stride"), let count = Int(value) { options.stride = count }
            do { print(try ProfileRunner.run(options) { print($0) }); print("PROFILE_REPORT=\(options.directory.path)") }
            catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        } else {
            let app = NSApplication.shared; let delegate = ProfileAppDelegate()
            app.delegate = delegate; app.setActivationPolicy(.regular)
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}
