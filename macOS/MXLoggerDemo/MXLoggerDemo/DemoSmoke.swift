import Foundation
import MXLogger

enum DemoSmoke {
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mxlogger-macos-demo-\(UUID().uuidString)")
        var config = DemoConfiguration()
        config.namespace = "com.mxlogger.macos.demo.smoke"
        config.directory = root.path
        config.encrypted = true
        config.console = false
        let session = try DemoSession(configuration: config)
        defer {
            session.close()
            try? FileManager.default.removeItem(at: root)
        }
        try session.write(level: 1, message: "原生 macOS 中文日志", name: "demo", tag: "native")
        try session.write(level: 2, message: "token message", name: "demo", tag: "token", viaToken: true)
        let process = try session.launchWorker(count: 1000)
        do { try session.batch(prefix: "parent", count: 1000) }
        catch { process.waitUntilExit(); throw error }
        process.waitUntilExit()
        try DemoSession.checkWorker(process)
        guard let file = session.logger.logFiles().first?["name"] else {
            throw DemoError(message: "Demo 未生成日志文件。")
        }
        let records = session.records(file: file)
        let messages = Set(records.compactMap { $0["msg"] as? String })
        guard records.count == 2003, messages.contains("原生 macOS 中文日志"),
              messages.contains("token message"), messages.contains("parent:999"),
              messages.contains("worker:999"), messages.count == 2003 else {
            throw DemoError(message: "Demo 双进程加密读写校验失败：\(records.count) 条。")
        }
        let expired = URL(fileURLWithPath: session.logger.diskCachePath).appendingPathComponent("expired.mx")
        try Data("expired".utf8).write(to: expired)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: expired.path)
        session.logger.removeExpireData()
        guard !FileManager.default.fileExists(atPath: expired.path) else {
            throw DemoError(message: "Demo 手动清理失败。")
        }
        session.close()
        let reopened = try DemoSession(configuration: config)
        defer { reopened.close() }
        try reopened.write(level: 1, message: "reopened", name: "demo", tag: "reopen")
        guard reopened.records(file: file).count == 2004 else {
            throw DemoError(message: "Demo 重新打开日志校验失败。")
        }
        print("MXLOGGER_NATIVE_MACOS_DEMO_OK: encrypted read/write, token, two processes, cleanup, reopen")
    }
}
