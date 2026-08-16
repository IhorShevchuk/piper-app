// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

/// Efficient ring buffer to replace ContiguousArray<Float> + removeFirst(O(n))
public struct FloatRingBuffer {
    private var buffer: [Float] = []
    private var head: Int = 0

    public init() {}

    public var count: Int {
        buffer.count - head
    }

    public var isEmpty: Bool {
        count == 0
    }

    public mutating func append(contentsOf newElements: [Float]) {
        buffer.append(contentsOf: newElements)
        maybeCompact()
    }

    public mutating func append(contentsOf newElements: ArraySlice<Float>) {
        buffer.append(contentsOf: newElements)
        maybeCompact()
    }

    public mutating func append(contentsOf newElements: UnsafeBufferPointer<Float>) {
        buffer.append(contentsOf: newElements)
        maybeCompact()
    }

    public mutating func removeFirst(_ countToRemove: Int) {
        precondition(countToRemove <= count, "removeFirst beyond count")
        head += countToRemove
        if head > 1024 && head > buffer.count / 2 {
            compact()
        }
    }

    public mutating func clear() {
        buffer.removeAll(keepingCapacity: true)
        head = 0
    }

    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Float>) throws -> R) rethrows -> R {
        try buffer.withUnsafeBufferPointer { ptr in
            if head >= buffer.count {
                let empty = UnsafeBufferPointer<Float>(start: nil, count: 0)
                return try body(empty)
            }
            let base = ptr.baseAddress!.advanced(by: head)
            let buf = UnsafeBufferPointer(start: base, count: count)
            return try body(buf)
        }
    }

    public func copyFirst(into destination: UnsafeMutablePointer<Float>, count elementsCount: Int) {
        precondition(elementsCount <= count)
        withUnsafeBufferPointer { src in
            guard elementsCount > 0 else { return }
            destination.update(from: src.baseAddress!, count: elementsCount)
        }
    }

    public mutating func appendAndEnforceMax(contentsOf newElements: [Float], maxCount: Int) {
        append(contentsOf: newElements)
        if count > maxCount {
            let overflow = count - maxCount
            removeFirst(overflow)
        }
    }

    public mutating func appendAndEnforceMax(contentsOf newElements: UnsafeBufferPointer<Float>, maxCount: Int) {
        append(contentsOf: newElements)
        if count > maxCount {
            let overflow = count - maxCount
            removeFirst(overflow)
        }
    }

    private mutating func compact() {
        if head > 0 {
            buffer.removeFirst(head)
            head = 0
        }
    }

    private mutating func maybeCompact() {
        if head > 4096 && head * 2 > buffer.count {
            compact()
        }
    }

    public var snapshot: [Float] {
        if isEmpty { return [] }
        return Array(buffer[head..<buffer.count])
    }
}
