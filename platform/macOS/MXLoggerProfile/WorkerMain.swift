import Foundation
import MXLogger

private let messageFormat = "[%06ld] This is a benchmark loooooooooooooooooooooooooooooog"

@main
struct ProfileWorker {
    static func argument(_ name: String, default value: String = "") -> String {
        guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return value }
        return CommandLine.arguments[index + 1]
    }
    static func run() throws {
        let output = URL(fileURLWithPath: argument("--report"), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var result: [String: Any] = ["passed": false, "core_version": MXPCoreVersion(), "instrumented": MXPInstrumented()]
        do {
            let records = Int(argument("--records", default: "100000")) ?? 0
            let stride = UInt32(argument("--stride", default: "64")) ?? 0
            let offset = UInt32(argument("--offset", default: "0")) ?? 0
            let scenario = argument("--scenario", default: "demo_format")
            let encrypted = argument("--encrypted", default: "1") == "1"
            guard (1...1_000_000).contains(records), stride > 0,
                  ["demo_format", "demo_prebuilt", "core_prebuilt", "format_only"].contains(scenario) else {
                throw DemoError(message: "Invalid diagnostic arguments")
            }
            result["scenario"] = scenario; result["encrypted"] = encrypted; result["records"] = records
            // Match Demo's defaults and real DemoSession.write(), on the same QoS.
            var configuration = DemoConfiguration()
            configuration.directory = output.appendingPathComponent("data").path
            configuration.namespace = "com.djy.mxlogger.profile"
            configuration.encrypted = encrypted
            configuration.console = false
            // Warm Foundation/Swift/ObjC/AES code paths using a separate file.
            var warmConfig = configuration
            warmConfig.namespace += ".warmup"
            try autoreleasepool {
                let warm = try DemoSession(configuration: warmConfig)
                for index in 0..<min(2000, records) {
                    try warm.write(level: 1, message: String(format: messageFormat, index + 1), name: "benchmark", tag: "perf")
                }
                warm.close()
            }
            let prebuilt = scenario == "demo_prebuilt" || scenario == "core_prebuilt"
                ? (0..<records).map { String(format: messageFormat, $0 + 1) } : []
            let usePrebuilt = scenario == "demo_prebuilt"
            var path: String = ""
            var before: [String: NSNumber] = [:]
            var after: [String: NSNumber] = [:]
            let seconds: Double
            if scenario == "format_only" {
                var checksum = 0
                before = MXPResources() as! [String: NSNumber]
                let start = DispatchTime.now().uptimeNanoseconds
                for index in 0..<records { checksum &+= String(format: messageFormat, index + 1).utf8.count }
                seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
                after = MXPResources() as! [String: NSNumber]
                result["checksum"] = checksum
            } else if scenario == "core_prebuilt" {
                let core = MXPCoreRun(configuration.directory!, prebuilt, encrypted) as! [String: Any]
                if let error = core["error"] as? String, !error.isEmpty { throw DemoError(message: error) }
                seconds = core["seconds"] as! Double; path = core["path"] as! String
                before = core["resource_before"] as! [String: NSNumber]
                after = core["resource_after"] as! [String: NSNumber]
            } else {
                let session = try DemoSession(configuration: configuration)
                path = session.logger.diskCachePath
                #if MXLOGGER_PROFILE
                MXPStart(stride, offset)
                #endif
                before = MXPResources() as! [String: NSNumber]
                let start = DispatchTime.now().uptimeNanoseconds
                do {
                    for index in 0..<records {
                        #if MXLOGGER_PROFILE
                        MXPRecordBegin(UInt64(index)); MXPMessageBegin()
                        #endif
                        let message = usePrebuilt ? prebuilt[index] : String(format: messageFormat, index + 1)
                        #if MXLOGGER_PROFILE
                        MXPMessageEnd()
                        #endif
                        do {
                            try session.write(level: max(1, session.logger.level), message: message, name: "benchmark", tag: "perf")
                        } catch {
                            #if MXLOGGER_PROFILE
                            MXPRecordEnd()
                            #endif
                            throw error
                        }
                        #if MXLOGGER_PROFILE
                        MXPRecordEnd()
                        #endif
                    }
                } catch { session.close(); throw error }
                seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
                after = MXPResources() as! [String: NSNumber]
                #if MXLOGGER_PROFILE
                let data = Data(String(cString: MXPFinishJSON()).utf8)
                result["profile"] = try JSONSerialization.jsonObject(with: data)
                #endif
                MXPFlushLogger(session.logger.loggerToken)
                session.close()
            }
            var resources: [String: Double] = [:]
            for (key, value) in after {
                resources[key] = key == "max_rss_bytes" ? value.doubleValue : value.doubleValue - (before[key]?.doubleValue ?? 0)
            }
            result["resources"] = resources; result["seconds"] = seconds
            // Explicit flush, readback, formatting expected strings and report I/O
            // all occur after the measured loop.
            if scenario != "format_only" {
                var sequence = 0
                let files = try FileManager.default.contentsOfDirectory(atPath: path).filter { $0.hasSuffix(".mx") }.sorted()
                for file in files {
                    let rows = MXLogger.select(filePath: URL(fileURLWithPath: path).appendingPathComponent(file).path,
                                               cryptKey: configuration.cryptKey, iv: configuration.cryptIV)
                    for row in rows.reversed() {
                        if row["tag"] as? String != "perf" { continue }
                        guard row["error_code"] as? String == "0", row["name"] as? String == "benchmark",
                              row["msg"] as? String == String(format: messageFormat, sequence + 1) else {
                            throw DemoError(message: "Readback/order/decryption mismatch at record \(sequence)")
                        }
                        sequence += 1
                    }
                }
                guard sequence == records else { throw DemoError(message: "Expected \(records) records, got \(sequence)") }
                result["verified_records"] = sequence
            }
            result["passed"] = true
        } catch {
            result["error"] = error.localizedDescription
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.appendingPathComponent("result.json"), options: .atomic)
            throw error
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("result.json"), options: .atomic)
    }
    static func main() {
        let done = DispatchGroup(); done.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            do { try autoreleasepool { try run() } }
            catch { FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8)); exit(1) }
            done.leave()
        }
        done.wait()
    }
}
