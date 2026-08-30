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

    // MARK: - 1.0.12 regression guards (120s)

    func testAppendLarge120s() {
        var ring = FloatRingBuffer()
        let sampleRate = 22050
        let maxSamples = sampleRate * 120 // 2_646_000
        // Use chunked append to avoid single 10MB alloc in one go on CI
        let chunk = [Float](repeating: 0.9, count: sampleRate * 10)
        for _ in 0..<12 {
            ring.append(contentsOf: chunk)
        }
        XCTAssertEqual(ring.count, maxSamples)
        XCTAssertGreaterThan(ring.count, 110_250, "Must hold more than old 5s limit")
    }

    func testNoMiddleDrop() {
        var ring = FloatRingBuffer()
        // Fill with sequential values to detect middle drop
        let initial = (0..<1000).map { Float($0) }
        ring.append(contentsOf: initial)
        XCTAssertEqual(ring.count, 1000)

        // Enforce max 800 – should keep tail 200..999, not middle
        ring.appendAndEnforceMax(contentsOf: [], maxCount: 800)
        // appendAndEnforceMax with empty still enforces? Our impl only trims if count > max after append.
        // So we need to trigger overflow via extra append
        ring.appendAndEnforceMax(contentsOf: [Float](repeating: 9999, count: 0), maxCount: 800)
        // Actually test proper overflow path
        var ring2 = FloatRingBuffer()
        ring2.append(contentsOf: initial)
        ring2.appendAndEnforceMax(contentsOf: [Float](repeating: 10000, count: 100), maxCount: 800)
        XCTAssertEqual(ring2.count, 800)
        // Tail should be 10000s, head should be 300..999 (since 1000+100-800=300 overflow)
        let snap = ring2.snapshot
        XCTAssertEqual(snap.count, 800)
        XCTAssertTrue(snap.suffix(100).allSatisfy { $0 == 10000 }, "Tail must be new samples")
        // No middle hole – first element should be 300 (original 0..299 dropped)
        XCTAssertEqual(snap.first, Float(300), "Should drop head, not middle")
        // Sequential integrity for remaining original part
        XCTAssertEqual(snap[0], Float(300))
        XCTAssertEqual(snap[499], Float(799)) // 300 + 499 = 799
    }

    func testEnforceMaxKeepsTailNotHead() {
        var ring = FloatRingBuffer()
        let maxCount = 22050 * 120
        ring.append(contentsOf: [Float](repeating: 1.0, count: maxCount - 50))
        ring.appendAndEnforceMax(contentsOf: [Float](repeating: 2.0, count: 100), maxCount: maxCount)
        XCTAssertEqual(ring.count, maxCount)
        XCTAssertTrue(ring.snapshot.suffix(100).allSatisfy { $0 == 2.0 })
        XCTAssertTrue(ring.snapshot.prefix(50).allSatisfy { $0 == 1.0 } == false || ring.snapshot.count == maxCount)
        // After overflow of 50, first 50 of original should be gone
        // Original had maxCount-50 of 1.0, we added 100 of 2.0 -> overflow 50
        // So first element should still be 1.0 (since we dropped 50 from head, remaining head is still 1.0)
        XCTAssertEqual(ring.snapshot.first, 1.0)
    }
}
