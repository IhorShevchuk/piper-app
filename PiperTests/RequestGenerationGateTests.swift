// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperTTSLogic

final class RequestGenerationGateTests: XCTestCase {

    func testInitialGenerationIsZero() {
        let gate = RequestGenerationGate()
        XCTAssertEqual(gate.currentGeneration, 0)
        XCTAssertTrue(gate.isCurrent(0))
    }

    func testBeginReturnsIncreasingGenerations() {
        let gate = RequestGenerationGate()
        let first = gate.begin()
        let second = gate.begin()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertGreaterThan(second, first)
    }

    func testBeginInvalidatesPreviousGeneration() {
        let gate = RequestGenerationGate()
        let stale = gate.begin()
        let current = gate.begin()
        XCTAssertFalse(gate.isCurrent(stale))
        XCTAssertTrue(gate.isCurrent(current))
        XCTAssertEqual(gate.currentGeneration, current)
    }

    func testCancelInvalidatesCurrentGeneration() {
        let gate = RequestGenerationGate()
        let active = gate.begin()
        XCTAssertTrue(gate.isCurrent(active))
        gate.cancel()
        XCTAssertFalse(gate.isCurrent(active))
    }

    func testCancelWithoutBeginIsSafe() {
        let gate = RequestGenerationGate()
        gate.cancel()
        XCTAssertEqual(gate.currentGeneration, 1)
        XCTAssertTrue(gate.isCurrent(1))
    }

    func testStaleCallbackDroppedAfterCancelAndNewBegin() {
        // Simulates the rapid-navigation race: request 1 starts, the user moves on
        // (cancel), request 2 starts. Late callbacks tagged with request 1's
        // generation must be rejected so stale samples never reach the new request.
        let gate = RequestGenerationGate()
        let firstRequest = gate.begin()
        gate.cancel()
        let secondRequest = gate.begin()
        XCTAssertFalse(gate.isCurrent(firstRequest))
        XCTAssertTrue(gate.isCurrent(secondRequest))
        XCTAssertEqual(gate.currentGeneration, secondRequest)
    }

    func testConcurrentBeginKeepsMonotonicCount() {
        let gate = RequestGenerationGate()
        let iterations = 1000
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            gate.begin()
        }
        XCTAssertEqual(gate.currentGeneration, UInt64(iterations))
    }

    func testConcurrentReadsNeverCrash() {
        let gate = RequestGenerationGate()
        let current = gate.begin()
        DispatchQueue.concurrentPerform(iterations: 500) { _ in
            _ = gate.isCurrent(current)
            _ = gate.currentGeneration
        }
        XCTAssertTrue(gate.isCurrent(current))
    }
}
