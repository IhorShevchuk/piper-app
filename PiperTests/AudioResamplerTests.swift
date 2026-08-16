// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperTTSLogic

final class AudioResamplerTests: XCTestCase {
    func testSameRatePassthrough() {
        let input: [Float] = [0.1, 0.2, 0.3, 0.4]
        let output = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 22050)
        XCTAssertEqual(output, input)
    }

    func testUpsampleCount() {
        let input = Array(repeating: Float(0.5), count: 100)
        let output = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertEqual(output.count, 138)
    }

    func testDownsampleCount() {
        let input = Array(repeating: Float(0.5), count: 220)
        let output = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 16000)
        let expected = Int((Double(220) * 16000.0 / 22050.0).rounded())
        XCTAssertEqual(output.count, expected)
    }

    func testEmptyInput() {
        let input: [Float] = []
        let output = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertTrue(output.isEmpty)
    }

    func testSingleSampleUpsample() {
        let input: [Float] = [1.0]
        let output = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertEqual(output.count, 1)
        XCTAssertTrue(output.allSatisfy { $0 == 1.0 })
    }

    func testBufferOverload() {
        let input: [Float] = [0, 1, 2, 3]
        input.withUnsafeBufferPointer { buffer in
            let output = AudioResampler.resampleBuffer(buffer, inputRate: 16000, outputRate: 22050)
            XCTAssertEqual(output.count, Int((Double(4) * 22050.0 / 16000.0).rounded()))
        }
    }
}
