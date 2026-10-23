import Foundation

// Exercise the public Swift names against the actual Objective-C/C++ implementation.
let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("mxlogger-swift-\(UUID().uuidString)", isDirectory: true)
let namespace = "com.mxlogger.swift.smoke"
let key = "0123456789abcdef"
let iv = "fedcba9876543210"
let logger = MXLogger.shared(namespace: namespace,
                             diskCacheDirectory: root.path,
                             storagePolicy: .daily,
                             fileName: "swift",
                             fileHeader: nil,
                             cryptKey: key,
                             iv: iv)
defer {
    MXLogger.destroy(namespace: namespace, diskCacheDirectory: root.path)
    try? FileManager.default.removeItem(at: root)
}

precondition(!MXLogger.defaultDiskCacheDirectory().isEmpty)
precondition(logger.info(name: "swift", message: "macOS 中文日志", tag: "native") == 0)
precondition(MXLogger.logger(forToken: logger.loggerToken) === logger)
guard let name = logger.logFiles().first?["name"] else {
    fatalError("No log file was created")
}
let path = URL(fileURLWithPath: logger.diskCachePath).appendingPathComponent(name).path
let records = MXLogger.select(filePath: path, cryptKey: key, iv: iv)
precondition(records.count == 1)
precondition(records.first?["msg"] as? String == "macOS 中文日志")
let expired = URL(fileURLWithPath: logger.diskCachePath).appendingPathComponent("expired.mx")
for enabled in [false, true] {
    try Data("old log".utf8).write(to: expired)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)],
                                          ofItemAtPath: expired.path)
    logger.shouldRemoveExpiredDataWhenEnterBackground = enabled
    logger.maxDiskAge = 86400
    precondition(FileManager.default.fileExists(atPath: expired.path))
    logger.removeExpireData()
    precondition(!FileManager.default.fileExists(atPath: expired.path))
}
print("Swift native API smoke test passed")
