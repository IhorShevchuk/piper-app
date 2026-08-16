// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperTTSLogic

final class AudioResamplerTests: XCTestCase {

    func testPassthroughSameRate() {
        let input: [Float] = [0, 1, 2, 3]
        let out = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 22050)
        XCTAssertEqual(out, input)
    }

    func testResampleCountChangesWithRate() {
        let input = [Float](repeating: 1.0, count: 100)
        let out = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 16000)
        XCTAssertEqual(out.count, Int((Double(100) * 16000.0 / 22050.0).rounded()))
    }

    func testEmptyInput() {
        let out = AudioResampler.resample(input: [], inputRate: 22050, outputRate: 16000)
        XCTAssertTrue(out.isEmpty)
    }

    func testSingleSample() {
        let out = AudioResampler.resample(input: [0.5], inputRate: 22050, outputRate: 16000)
        XCTAssertFalse(out.isEmpty)
        XCTAssertTrue(out.allSatisfy { $0 == 0.5 })
    }

    func testResampleBufferPassthroughNoCopySemantics() {
        let arr: [Float] = [1, 2, 3, 4]
        arr.withUnsafeBufferPointer { buf in
            let out = AudioResampler.resampleBuffer(buf, inputRate: 22050, outputRate: 22050)
            XCTAssertEqual(out, arr)
        }
    }

    func testResampleBufferEmpty() {
        let empty = [Float]().withUnsafeBufferPointer { buf in
            AudioResampler.resampleBuffer(buf, inputRate: 22050, outputRate: 16000)
        }
        XCTAssertTrue(empty.isEmpty)
    }

    func testResampleBufferSingleSample() {
        let src: [Float] = [0.7]
        let out = src.withUnsafeBufferPointer { buf in
            AudioResampler.resampleBuffer(buf, inputRate: 8000, outputRate: 16000)
        }
        XCTAssertFalse(out.isEmpty)
        XCTAssertTrue(out.allSatisfy { $0 == 0.7 })
    }

    func testResampleBufferUprateAndDownrate() {
        let src = [Float](repeating: 0.5, count: 10)
        src.withUnsafeBufferPointer { buf in
            let up = AudioResampler.resampleBuffer(buf, inputRate: 16000, outputRate: 22050)
            let down = AudioResampler.resampleBuffer(buf, inputRate: 22050, outputRate: 16000)
            XCTAssertEqual(up.count, Int((Double(10) * 22050.0 / 16000.0).rounded()))
            XCTAssertEqual(down.count, Int((Double(10) * 16000.0 / 22050.0).rounded()))
        }
    }
}
