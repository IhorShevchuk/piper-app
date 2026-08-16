// swiftlint:disable all
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperAppUtils

final class LoggerTests: XCTestCase {

    func testLevelComparable() {
        XCTAssertLessThan(Log.Level.debug, Log.Level.info)
        XCTAssertLessThan(Log.Level.info, Log.Level.warning)
        XCTAssertLessThan(Log.Level.warning, Log.Level.error)
        XCTAssertGreaterThan(Log.Level.error, Log.Level.debug)
    }

    func testLevelOrderingEquality() {
        XCTAssertEqual(Log.Level.debug, Log.Level.debug)
        XCTAssertNotEqual(Log.Level.debug, Log.Level.info)
    }

    func testLogLevelGetterSetter() {
        let original = Log.logLevel
        defer { Log.logLevel = original }
        Log.logLevel = .debug
        XCTAssertEqual(Log.logLevel, .debug)
        Log.logLevel = .error
        XCTAssertEqual(Log.logLevel, .error)
    }

    func testLevelAllCases() {
        let all = Log.Level.allCases
        XCTAssertTrue(all.contains(.debug))
        XCTAssertTrue(all.contains(.info))
        XCTAssertTrue(all.contains(.warning))
        XCTAssertTrue(all.contains(.error))
        XCTAssertEqual(all.count, 4)
    }

    func testLogTypeAllCases() {
        let types = Log.LogType.allCases
        XCTAssertTrue(types.contains(.ui))
        XCTAssertTrue(types.contains(.synthesizer))
        XCTAssertTrue(types.contains(.tests))
    }

    func testDebugDoesNotCrash() {
        // Should not crash regardless of log level
        Log.logLevel = .debug
        Log.debug("debug message")
        Log.info("info message")
        Log.warning("warn")
        Log.error("err")
        Log.debug(type: .tests, "test type debug")
    }

    func testShouldMaskLogic() {
        let original = Log.logLevel
        defer { Log.logLevel = original }
        Log.logLevel = .debug
        // When debug, shouldMask false
        // We can't access private shouldMask directly, but we can verify logging doesn't crash
        Log.info("unmasked")
        Log.logLevel = .error
        Log.info("masked (should be private)")
        // No assertion, just ensure no crash and masking handled by OSLog
    }
}
