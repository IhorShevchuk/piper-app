// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperTTSLogic

final class FloatRingBufferTests: XCTestCase {
    func testAppendAndCount() {
        var ringBuffer = FloatRingBuffer()
        XCTAssertTrue(ringBuffer.isEmpty)
        ringBuffer.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(ringBuffer.count, 3)
        XCTAssertFalse(ringBuffer.isEmpty)
    }

    func testRemoveFirstAdvancesHead() {
        var ringBuffer = FloatRingBuffer()
        ringBuffer.append(contentsOf: [1, 2, 3, 4, 5])
        ringBuffer.removeFirst(2)
        XCTAssertEqual(ringBuffer.count, 3)
        XCTAssertEqual(ringBuffer.snapshot, [3, 4, 5])
    }

    func testWithUnsafePointer() {
        var ringBuffer = FloatRingBuffer()
        ringBuffer.append(contentsOf: [10, 20, 30])
        let sum = ringBuffer.withUnsafeBufferPointer { pointer in
            pointer.reduce(Float(0), +)
        }
        XCTAssertEqual(sum, 60)
    }

    func testClear() {
        var ringBuffer = FloatRingBuffer()
        ringBuffer.append(contentsOf: [1, 2, 3])
        ringBuffer.clear()
        XCTAssertTrue(ringBuffer.isEmpty)
        XCTAssertEqual(ringBuffer.count, 0)
        XCTAssertEqual(ringBuffer.snapshot, [])
    }

    func testMaxEnforceKeepsNewest() {
        var ringBuffer = FloatRingBuffer()
        ringBuffer.append(contentsOf: [1, 2, 3, 4, 5])
        ringBuffer.appendAndEnforceMax(contentsOf: [6, 7, 8], maxCount: 5)
        XCTAssertEqual(ringBuffer.count, 5)
        XCTAssertEqual(ringBuffer.snapshot, [4, 5, 6, 7, 8])
    }

    func testLargeAppendRemoveEfficiency() {
        var ringBuffer = FloatRingBuffer()
        let large = Array(repeating: Float(0.5), count: 10000)
        ringBuffer.append(contentsOf: large)
        XCTAssertEqual(ringBuffer.count, 10000)
        ringBuffer.removeFirst(9990)
        XCTAssertEqual(ringBuffer.count, 10)
        ringBuffer.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(ringBuffer.count, 13)
        XCTAssertEqual(ringBuffer.snapshot.prefix(10).allSatisfy { $0 == 0.5 }, true)
    }

    func testAppendUnsafeBuffer() {
        var ringBuffer = FloatRingBuffer()
        let array: [Float] = [9, 8, 7]
        array.withUnsafeBufferPointer { pointer in
            ringBuffer.append(contentsOf: pointer)
        }
        XCTAssertEqual(ringBuffer.snapshot, [9, 8, 7])
    }
}
