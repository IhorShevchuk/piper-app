// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperTTSLogic

final class FloatRingBufferTests: XCTestCase {

    func testAppendAndCount() {
        var ring = FloatRingBuffer()
        XCTAssertTrue(ring.isEmpty)
        ring.append(contentsOf: [1, 2, 3])
        XCTAssertEqual(ring.count, 3)
        XCTAssertEqual(ring.snapshot, [1, 2, 3])
    }

    func testRemoveFirst() {
        var ring = FloatRingBuffer()
        ring.append(contentsOf: [1, 2, 3, 4, 5])
        ring.removeFirst(2)
        XCTAssertEqual(ring.count, 3)
        XCTAssertEqual(ring.snapshot, [3, 4, 5])
    }

    func testClear() {
        var ring = FloatRingBuffer()
        ring.append(contentsOf: [1, 2, 3])
        ring.clear()
        XCTAssertTrue(ring.isEmpty)
        XCTAssertEqual(ring.count, 0)
    }

    func testWithUnsafeBufferPointer() {
        var ring = FloatRingBuffer()
        ring.append(contentsOf: [10, 20, 30])
        let sum = ring.withUnsafeBufferPointer { buf in
            buf.reduce(0, +)
        }
        XCTAssertEqual(sum, 60)
    }

    func testAppendAndEnforceMaxArray() {
        var ring = FloatRingBuffer()
        ring.appendAndEnforceMax(contentsOf: [1, 2, 3, 4, 5], maxCount: 3)
        XCTAssertEqual(ring.count, 3)
        XCTAssertEqual(ring.snapshot, [3, 4, 5])
        ring.appendAndEnforceMax(contentsOf: [6, 7], maxCount: 3)
        XCTAssertEqual(ring.snapshot, [5, 6, 7])
    }

    func testAppendAndEnforceMaxBufferPointer() {
        var ring = FloatRingBuffer()
        let src: [Float] = [10, 20, 30, 40]
        src.withUnsafeBufferPointer { buf in
            ring.appendAndEnforceMax(contentsOf: buf, maxCount: 2)
        }
        XCTAssertEqual(ring.count, 2)
        XCTAssertEqual(ring.snapshot, [30, 40])
    }

    func testCopyFirstIntoDestination() {
        var ring = FloatRingBuffer()
        ring.append(contentsOf: [1, 2, 3, 4])
        var dest = [Float](repeating: 0, count: 2)
        dest.withUnsafeMutableBufferPointer { destBuf in
            ring.copyFirst(into: destBuf.baseAddress!, count: 2)
        }
        XCTAssertEqual(dest, [1, 2])
        XCTAssertEqual(ring.count, 4)
    }

    func testCompactDoesNotLoseData() {
        var ring = FloatRingBuffer()
        // Fill and drain to force head > 1024 threshold
        for _ in 0..<5 {
            ring.append(contentsOf: [Float](repeating: 1, count: 500))
            ring.removeFirst(400)
        }
        XCTAssertFalse(ring.isEmpty)
        // snapshot should match withUnsafeBufferPointer
        let snap = ring.snapshot
        let bufSum = ring.withUnsafeBufferPointer { $0.reduce(0, +) }
        XCTAssertEqual(Float(snap.count), bufSum)
    }

    func testAppendSlice() {
        var ring = FloatRingBuffer()
        let full = [1, 2, 3, 4, 5] as [Float]
        ring.append(contentsOf: full[1...3])
        XCTAssertEqual(ring.snapshot, [2, 3, 4])
    }
}
