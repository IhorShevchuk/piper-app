// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import OSLog

fileprivate extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

public class Log {

    private static let oslog: OSLog = {
        let bundleID: String = Bundle.main.bundleIdentifier ?? "unknown"
        return OSLog(subsystem: bundleID, category: "app")
    }()

    private static let logLevelLock = NSLock()
#if DEBUG
    private static var _logLevel: Log.Level = .debug
#else
    private static var _logLevel: Log.Level = .error
#endif

    public enum Level: String, Codable, CaseIterable, Identifiable {
        case debug
        case info
        case warning
        case error

        var os_logLevel: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .error
            case .error:
                return .fault
            }
        }

        public var id: String {
            return self.rawValue
        }
    }

    fileprivate static var shouldMask: Bool {
        return logLevel != .debug
    }

    public enum LogType: String, Codable, CaseIterable {
        // swiftlint:disable:next identifier_name
        case ui
        case synthesizer
        case integrity
        case network
        case tests
        case other
    }

    static public var logLevel: Log.Level {
        get {
            return self.logLevelLock.withLock { self._logLevel }
        }
        set {
            self.logLevelLock.withLock { self._logLevel = newValue }
        }
    }

    static public func debug(type: LogType = .other, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        doPrint(logLevel: .debug, type: type, message, file: file, function: function, line: line)
    }

    static public func info(type: LogType = .other, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        doPrint(logLevel: .info, type: type, message, file: file, function: function, line: line)
    }

    static public func warning(type: LogType = .other, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        doPrint(logLevel: .warning, type: type, message, file: file, function: function, line: line)
    }

    static public func error(type: LogType = .other, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        doPrint(logLevel: .error, type: type, message, file: file, function: function, line: line)
    }
}

private extension Log {
    // swiftlint:disable:next function_parameter_count
    static func doPrint(logLevel: Level, type: LogType, _ message: String, file: String, function: String, line: UInt) {
        if self.logLevel <= logLevel {
            let fileName = file.components(separatedBy: "/").last ?? file
            let messageToPrint = "[\(logLevel)][\(type)][\(fileName)(\(line))] \(message)"
            if shouldMask {
                os_log("%{private}@", log: oslog, type: logLevel.os_logLevel, messageToPrint)
            } else {
                os_log("%{public}@", log: oslog, type: logLevel.os_logLevel, messageToPrint)
            }
        }
    }
}

fileprivate extension Log.Level {
    var naturalIntegralValue: Int {
        switch self {
        case .debug:
            return 0
        case .info:
            return 1
        case .warning:
            return 2
        case .error:
            return 3
        }
    }
}

extension Log.Level: Comparable {
    public static func < (lhs: Log.Level, rhs: Log.Level) -> Bool {
        return lhs.naturalIntegralValue < rhs.naturalIntegralValue
    }
}

extension String {
    public var masked: String {
        if Log.shouldMask {
            return self
        }
        return String(self.hashValue)
    }
}
