// swiftlint:disable all
import XCTest
@testable import PiperTTSLogic

final class AudioResamplerTests: XCTestCase {
    func testSameRatePassthrough() {
        let input: [Float] = [0.1, 0.2, 0.3, 0.4]
        let out = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 22050)
        XCTAssertEqual(out, input)
    }
    func testUpsampleCount() {
        let input = Array(repeating: Float(0.5), count: 100)
        let out = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertEqual(out.count, 138)
    }
    func testDownsampleCount() {
        let input = Array(repeating: Float(0.5), count: 220)
        let out = AudioResampler.resample(input: input, inputRate: 22050, outputRate: 16000)
        let expected = Int((Double(220) * 16000.0 / 22050.0).rounded())
        XCTAssertEqual(out.count, expected)
    }
    func testEmptyInput() {
        let input: [Float] = []
        let out = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertTrue(out.isEmpty)
    }
    func testSingleSampleUpsample() {
        let input: [Float] = [1.0]
        let out = AudioResampler.resample(input: input, inputRate: 16000, outputRate: 22050)
        XCTAssertEqual(out.count, 1)
        XCTAssertTrue(out.allSatisfy { $0 == 1.0 })
    }
    func testBufferOverload() {
        let input: [Float] = [0,1,2,3]
        input.withUnsafeBufferPointer { buf in
            let out = AudioResampler.resampleBuffer(buf, inputRate: 16000, outputRate: 22050)
            XCTAssertEqual(out.count, Int((Double(4) * 22050.0/16000.0).rounded()))
        }
    }
}
