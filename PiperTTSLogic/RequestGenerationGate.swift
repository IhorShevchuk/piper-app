// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

/// Monotonic generation counter that invalidates stale async work.
///
/// Every new speech request (or cancel) bumps the generation. In-flight engine
/// callbacks and render passes capture the generation they started with and
/// drop their work once it no longer matches, so samples from a cancelled
/// request can never leak into the next one.
public final class RequestGenerationGate {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    public init() {}

    /// The latest generation. Thread-safe.
    public var currentGeneration: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    /// Starts a new generation, invalidating all previous ones. Returns the new value.
    @discardableResult
    public func begin() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return generation
    }

    /// Invalidates the current generation without starting a new request.
    public func cancel() {
        begin()
    }

    /// True while `generation` is still the current one.
    public func isCurrent(_ generation: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == self.generation
    }
}
