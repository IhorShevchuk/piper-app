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
        var step = Float(input.count - 1) / Float(outCount - 1)
        var positions = [Float](repeating: 0, count: outCount)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(outCount))
        output.withUnsafeMutableBufferPointer { outPtr in
            positions.withUnsafeBufferPointer { posPtr in
                input.withUnsafeBufferPointer { inPtr in
                    if let inBase = inPtr.baseAddress, let posBase = posPtr.baseAddress, let outBase = outPtr.baseAddress {
                        vDSP_vlint(
                            inBase,
                            posBase,
                            1,
                            outBase,
                            1,
                            vDSP_Length(outCount),
                            vDSP_Length(input.count)
                        )
                    }
                }
            }
        }
        return output
    }

    // Optimized to avoid Array(buf) copy when no resampling or when resampling
    public static func resampleBuffer(_ buf: UnsafeBufferPointer<Float>, inputRate: Double, outputRate: Double) -> [Float] {
        if inputRate == outputRate {
            if buf.isEmpty { return [] }
            return Array(buf)
        }
        guard !buf.isEmpty else { return [] }
        let inputCount = buf.count
        let ratio = outputRate / inputRate
        let outCount = Int((Double(inputCount) * ratio).rounded())
        guard outCount > 0 else { return [] }
        if inputCount == 1 {
            return [Float](repeating: buf[0], count: outCount)
        }
        if outCount == 1 {
            return [buf[0]]
        }
        var output = [Float](repeating: 0, count: outCount)
        var start: Float = 0
        var step = Float(inputCount - 1) / Float(outCount - 1)
        var positions = [Float](repeating: 0, count: outCount)
        vDSP_vramp(&start, &step, &positions, 1, vDSP_Length(outCount))
        output.withUnsafeMutableBufferPointer { outPtr in
            positions.withUnsafeBufferPointer { posPtr in
                if let inBase = buf.baseAddress, let posBase = posPtr.baseAddress, let outBase = outPtr.baseAddress {
                    vDSP_vlint(
                        inBase,
                        posBase,
                        1,
                        outBase,
                        1,
                        vDSP_Length(outCount),
                        vDSP_Length(inputCount)
                    )
                }
            }
        }
        return output
    }

    public static func resampleInto(input: [Float], inputRate: Double, outputRate: Double, outBuffer: inout [Float]) {
        outBuffer = resample(input: input, inputRate: inputRate, outputRate: outputRate)
    }
}
