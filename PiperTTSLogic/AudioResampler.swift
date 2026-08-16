// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Accelerate
import Foundation

public enum AudioResampler {
    public static func resample(input: [Float], inputRate: Double, outputRate: Double) -> [Float] {
        guard inputRate != outputRate, !input.isEmpty else { return input }
        let ratio = outputRate / inputRate
        let outCount = Int((Double(input.count) * ratio).rounded())
        guard outCount > 0 else { return [] }
        if input.count == 1 {
            return [Float](repeating: input[0], count: outCount)
        }
        if outCount == 1 {
            return [input[0]]
        }
        var output = [Float](repeating: 0, count: outCount)
        var start: Float = 0
        var positions = [Float](repeating: 0, count: outCount)
        var step = Float(input.count - 1) / Float(outCount - 1)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(outCount))
        output.withUnsafeMutableBufferPointer { outPtr in
            positions.withUnsafeBufferPointer { posPtr in
                input.withUnsafeBufferPointer { inPtr in
                    vDSP_vlint(
                        inPtr.baseAddress!,
                        posPtr.baseAddress!,
                        1,
                        outPtr.baseAddress!,
                        1,
                        vDSP_Length(outCount),
                        vDSP_Length(input.count)
                    )
                }
            }
        }
        return output
    }

    public static func resampleBuffer(_ buf: UnsafeBufferPointer<Float>, inputRate: Double, outputRate: Double) -> [Float] {
        if inputRate == outputRate { return Array(buf) }
        return resample(input: Array(buf), inputRate: inputRate, outputRate: outputRate)
    }

    public static func resampleInto(input: [Float], inputRate: Double, outputRate: Double, outBuffer: inout [Float]) {
        outBuffer = resample(input: input, inputRate: inputRate, outputRate: outputRate)
    }
}
