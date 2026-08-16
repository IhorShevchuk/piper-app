// swiftlint:disable all
import XCTest
@testable import PiperTTSLogic

final class FloatRingBufferTests: XCTestCase {
    func testAppendAndCount() {
        var rb = FloatRingBuffer()
        XCTAssertTrue(rb.isEmpty)
        rb.append(contentsOf: [1,2,3])
        XCTAssertEqual(rb.count, 3)
        XCTAssertFalse(rb.isEmpty)
    }
    func testRemoveFirstAdvancesHead() {
        var rb = FloatRingBuffer()
        rb.append(contentsOf: [1,2,3,4,5])
        rb.removeFirst(2)
        XCTAssertEqual(rb.count, 3)
        XCTAssertEqual(rb.snapshot, [3,4,5])
    }
    func testWithUnsafePointer() {
        var rb = FloatRingBuffer()
        rb.append(contentsOf: [10,20,30])
        let sum = rb.withUnsafeBufferPointer { ptr in ptr.reduce(Float(0), +) }
        XCTAssertEqual(sum, 60)
    }
    func testClear() {
        var rb = FloatRingBuffer()
        rb.append(contentsOf: [1,2,3])
        rb.clear()
        XCTAssertTrue(rb.isEmpty)
        XCTAssertEqual(rb.count, 0)
        XCTAssertEqual(rb.snapshot, [])
    }
    func testMaxEnforceKeepsNewest() {
        var rb = FloatRingBuffer()
        rb.append(contentsOf: [1,2,3,4,5])
        rb.appendAndEnforceMax(contentsOf: [6,7,8], maxCount: 5)
        XCTAssertEqual(rb.count, 5)
        XCTAssertEqual(rb.snapshot, [4,5,6,7,8])
    }
    func testLargeAppendRemoveEfficiency() {
        var rb = FloatRingBuffer()
        let large = Array(repeating: Float(0.5), count: 10000)
        rb.append(contentsOf: large)
        XCTAssertEqual(rb.count, 10000)
        rb.removeFirst(9990)
        XCTAssertEqual(rb.count, 10)
        rb.append(contentsOf: [1,2,3])
        XCTAssertEqual(rb.count, 13)
        XCTAssertEqual(rb.snapshot.prefix(10).allSatisfy { $0 == 0.5 }, true)
    }
    func testAppendUnsafeBuffer() {
        var rb = FloatRingBuffer()
        let arr: [Float] = [9,8,7]
        arr.withUnsafeBufferPointer { ptr in rb.append(contentsOf: ptr) }
        XCTAssertEqual(rb.snapshot, [9,8,7])
    }
}
