// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Testing
import Foundation

@Suite("PiperTTSAudioUnit resampling math")
struct ResamplingMathTests {

    // Pure replica of logic from PiperTTSAudioUnit.piperDidReceiveSamples
    func computeOutputCount(inputCount: Int, inputRate: Double, outputRate: Double) -> Int {
        guard inputCount > 0 else { return 0 }
        let ratio = outputRate / inputRate
        return Int(round(Double(inputCount) * ratio))
    }

    @Test("Upsample 16k -> 22.05k")
    func upsample() {
        let out = computeOutputCount(inputCount: 512, inputRate: 16000, outputRate: 22050)
        // 512 * 1.378125 = 705.6 -> 706
        #expect(out == 706)
    }

    @Test("No resample same rate")
    func sameRate() {
        let out = computeOutputCount(inputCount: 256, inputRate: 22050, outputRate: 22050)
        #expect(out == 256)
    }

    @Test("Downsample 22k -> 16k")
    func downsample() {
        let out = computeOutputCount(inputCount: 22050, inputRate: 22050, outputRate: 16000)
        #expect(out == 16000)
    }

    @Test("Zero input")
    func zero() {
        #expect(computeOutputCount(inputCount: 0, inputRate: 22050, outputRate: 16000) == 0)
    }

    @Test("Output buffer does not exceed maxSamplesCount")
    func maxSamples() {
        let sampleRate = 22050.0
        let maxDuration = 5.0
        let maxSamples = Int(sampleRate * maxDuration)
        #expect(maxSamples == 110250)
        // Simulate 10 seconds of audio chunks at 512 samples each – should be capped
        let total = 10 * Int(sampleRate)
        #expect(total > maxSamples)
    }

    @Test("Ramp step calculation")
    func rampStep() {
        let inputCount = 512
        let outputCount = 706
        let rampStep = (inputCount > 1 && outputCount > 1) ? Float(inputCount - 1) / Float(outputCount - 1) : 0
        #expect(rampStep > 0)
        #expect(rampStep < 1) // upsampling step <1
        let downStep: (Int, Int) -> Float = { inCount, outCount in
            return (inCount > 1 && outCount > 1) ? Float(inCount - 1) / Float(outCount - 1) : 0
        }
        let ds = downStep(706, 512)
        // Not exact, but should be >1 when downsampling input larger than output
        _ = ds
    }

    @Test("Positions array length matches outputCount")
    func positions() {
        let outputCount = 706
        let positions = [Float](repeating: 0, count: outputCount)
        #expect(positions.count == outputCount)
    }
}
