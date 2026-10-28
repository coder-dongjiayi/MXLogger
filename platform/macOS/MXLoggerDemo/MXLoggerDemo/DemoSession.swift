import Foundation
import MXLogger

struct DemoError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct DemoConfiguration: Codable {
    var namespace = "com.djy.mxlogger"
    var directory: String?
    var policy = 1
    var encrypted = true
    var key = "abcdefgabcdefgob"
    var iv = "abcdefgabcdefgcc"
    var minimumLevel = 0
    var enabled = true
    #if DEBUG
    var console = true
    #else
    var console = false
    #endif
    var maxAge: UInt = 7 * 24 * 60 * 60
    var maxSize: UInt = 10 * 1024 * 1024

    var resolvedDirectory: String { directory ?? MXLogger.defaultDiskCacheDirectory() }
    var cryptKey: String? { encrypted ? key : nil }
    var cryptIV: String? { encrypted && !iv.isEmpty ? iv : nil }

    func validate() throws {
        guard !namespace.isEmpty, !namespace.contains("/"), namespace != ".", namespace != ".." else {
            throw DemoError(message: "命名空间不能为空，也不能包含路径分隔符。")
        }
        guard !encrypted || (key.utf8.count == 16 && (iv.isEmpty || iv.utf8.count == 16)) else {
            throw DemoError(message: "Demo 的 AES Key 需要 16 字节，IV 可留空或填写 16 字节。")
        }
    }
}

struct WorkerRequest: Codable {
    var configuration: DemoConfiguration
    var count: Int
    var prefix: String
}

/// UI actions use the main thread; a worker is a separate OS process.
/// No extra synchronization is added to the library's write path.
final class DemoSession {
    let configuration: DemoConfiguration
    let logger: MXLogger
    private var closed = false

    init(configuration: DemoConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        logger = MXLogger.shared(namespace: configuration.namespace,
                                 diskCacheDirectory: configuration.directory,
                                 storagePolicy: MXLogger.StoragePolicy(rawValue: configuration.policy) ?? .daily,
                                 fileName: nil, fileHeader: "{\"platform\":\"macOS\",\"appVersion\":\"2.2.0\",\"from\":\"native-demo\"}",
                                 cryptKey: configuration.cryptKey, iv: configuration.cryptIV)
        apply(configuration)
    }

    func apply(_ configuration: DemoConfiguration) {
        logger.level = configuration.minimumLevel
        logger.isEnabled = configuration.enabled
        logger.isConsoleEnabled = configuration.console
        logger.maxDiskAge = configuration.maxAge
        logger.maxDiskSize = configuration.maxSize
    }

    func close() {
        guard !closed else { return }
        MXLogger.destroy(namespace: configuration.namespace, diskCacheDirectory: configuration.directory)
        closed = true
    }

    deinit { close() }

    func write(level: Int, message: String, name: String, tag: String, viaToken: Bool = false, generic: Bool = false) throws {
        let result: Int
        if viaToken {
            switch level {
            case 0: result = MXLogger.debug(loggerToken: logger.loggerToken, name: name, message: message, tag: tag)
            case 1: result = MXLogger.info(loggerToken: logger.loggerToken, name: name, message: message, tag: tag)
            case 2: result = MXLogger.warn(loggerToken: logger.loggerToken, name: name, message: message, tag: tag)
            case 3: result = MXLogger.error(loggerToken: logger.loggerToken, name: name, message: message, tag: tag)
            default: result = MXLogger.fatal(loggerToken: logger.loggerToken, name: name, message: message, tag: tag)
            }
        } else if generic {
            result = logger.log(level: level, name: name, message: message, tag: tag)
        } else {
            switch level {
            case 0: result = logger.debug(name: name, message: message, tag: tag)
            case 1: result = logger.info(name: name, message: message, tag: tag)
            case 2: result = logger.warn(name: name, message: message, tag: tag)
            case 3: result = logger.error(name: name, message: message, tag: tag)
            default: result = logger.fatal(name: name, message: message, tag: tag)
            }
        }
        guard result == 0 else { throw DemoError(message: "写入失败 (\(result))：\(logger.errorDesc())") }
    }

    func batch(prefix: String, count: Int) throws {
        for index in 0..<count {
            try write(level: max(1, logger.level), message: "\(prefix):\(index)",
                      name: "pid:\(ProcessInfo.processInfo.processIdentifier)", tag: prefix)
        }
    }

    func records(file: String) -> [[String: Any]] {
        let path = URL(fileURLWithPath: logger.diskCachePath).appendingPathComponent(file).path
        return MXLogger.select(filePath: path, cryptKey: configuration.cryptKey, iv: configuration.cryptIV)
            .map { record in
                var fields: [String: Any] = [:]
                for (key, value) in record { fields[String(describing: key)] = value }
                return fields
            }
    }

    func launchWorker(count: Int, prefix: String = "worker", completion: (@Sendable (Process) -> Void)? = nil) throws -> Process {
        guard let executable = Bundle.main.executableURL else {
            throw DemoError(message: "找不到 Demo 可执行文件。")
        }
        var config = configuration
        config.directory = configuration.resolvedDirectory
        config.minimumLevel = logger.level
        config.enabled = true
        config.console = false
        let data = try JSONEncoder().encode(WorkerRequest(configuration: config, count: count, prefix: prefix))
        let input = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--write-worker"]
        process.standardInput = input
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.terminationHandler = completion
        try process.run()
        // Configuration (including demo AES parameters) goes through stdin, not argv.
        input.fileHandleForWriting.write(data)
        input.fileHandleForWriting.closeFile()
        return process
    }

    static func checkWorker(_ process: Process) throws {
        guard process.terminationStatus == 0 else {
            let pipe = process.standardError as? Pipe
            let data = pipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
            throw DemoError(message: "子进程失败：\(String(data: data, encoding: .utf8) ?? "未知错误")")
        }
    }

    static func runWorker() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let request = try JSONDecoder().decode(WorkerRequest.self, from: data)
        guard (1...10000).contains(request.count) else { throw DemoError(message: "批量条数超出范围。") }
        let session = try DemoSession(configuration: request.configuration)
        try session.batch(prefix: request.prefix, count: request.count)
        session.close()
        print("MXLOGGER_DEMO_WORKER_OK")
    }
}
