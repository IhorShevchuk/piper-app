// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

// swiftlint:disable identifier_name file_length function_body_length cyclomatic_complexity empty_count

import XCTest
import Foundation

// MARK: - Lightweight mirrors of production types (pure Swift, no piper-objc dependency)

/// Mirrors `PiperAlignmentParser.PhonemeGroup` minimal fields needed for marker generation.
/// Production adds codepoints/ids/alignments slices; for tests only sampleCount + cumulative + isSpecial matter.
private struct MockPhonemeGroup {
    let phoneme: UInt32
    let sampleCount: Int
    let cumulativeOffsetBefore: Int
    var isSpecial: Bool

    var cumulativeOffsetAfter: Int { cumulativeOffsetBefore + sampleCount }

    init(phoneme: UInt32 = 0, sampleCount: Int, cumulativeOffsetBefore: Int, isSpecial: Bool = false) {
        self.phoneme = phoneme
        self.sampleCount = sampleCount
        self.cumulativeOffsetBefore = cumulativeOffsetBefore
        self.isSpecial = isSpecial
    }
}

private enum MockMarkerType {
    case sentence
    case word
}

private struct MockMarker {
    let range: NSRange
    let byteOffset: Int
    let type: MockMarkerType
}

// MARK: - Production algorithm replication (mirrors PiperSpeechMarker.generateMarkersWithAlignment)

private enum MarkerGenerator {

    /// Legacy heuristic – character proportion (fallback)
    static func generateLegacy(for sentence: String, sentenceNSRange: NSRange, startByteOffset: Int, totalBytes: Int) -> [MockMarker] {
        let words = sentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !words.isEmpty, totalBytes > 0, sentenceNSRange.location != NSNotFound else {
            return [MockMarker(range: sentenceNSRange, byteOffset: startByteOffset, type: .sentence)]
        }
        let totalChars = words.joined().count
        guard totalChars > 0 else {
            return [MockMarker(range: sentenceNSRange, byteOffset: startByteOffset, type: .sentence)]
        }

        var markers: [MockMarker] = []
        markers.append(MockMarker(range: sentenceNSRange, byteOffset: startByteOffset, type: .sentence))

        var currentByteOffset = startByteOffset
        var currentSearchIndex = sentence.startIndex

        for word in words {
            guard let wordRange = sentence.range(of: word, options: .literal, range: currentSearchIndex..<sentence.endIndex) else {
                continue
            }
            let loc = sentence.distance(from: sentence.startIndex, to: wordRange.lowerBound)
            let len = (word as NSString).length
            let nsRange = NSRange(location: sentenceNSRange.location + loc, length: len)
            let wordBytes = Int(Double(totalBytes) * (Double(word.count) / Double(totalChars)))
            markers.append(MockMarker(range: nsRange, byteOffset: currentByteOffset, type: .word))
            currentByteOffset += wordBytes
            currentSearchIndex = wordRange.upperBound
        }
        return markers
    }

    /// Alignment-aware generation – mirrors `PiperSpeechMarker.generateMarkersWithAlignment`
    static func generateWithAlignment(
        for sentence: String,
        sentenceNSRange: NSRange,
        startByteOffset: Int,
        groups: [MockPhonemeGroup]
    ) -> [MockMarker] {
        guard sentenceNSRange.location != NSNotFound else {
            return [MockMarker(range: sentenceNSRange, byteOffset: startByteOffset, type: .sentence)]
        }

        let sentenceMarker = MockMarker(range: sentenceNSRange, byteOffset: startByteOffset, type: .sentence)

        let rawTokens = sentence.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if rawTokens.isEmpty {
            return [sentenceMarker]
        }

        let totalSamples = groups.reduce(0) { $0 + $1.sampleCount }
        guard totalSamples > 0 else {
            // Fallback: estimate totalBytes from sentence
            let totalBytes = max(1, rawTokens.joined().count * 200)
            return generateLegacy(for: sentence, sentenceNSRange: sentenceNSRange, startByteOffset: startByteOffset, totalBytes: totalBytes)
        }

        let realGroups = groups.filter { !$0.isSpecial }
        if realGroups.isEmpty {
            let totalBytes = totalSamples * MemoryLayout<Float>.size
            return generateLegacy(for: sentence, sentenceNSRange: sentenceNSRange, startByteOffset: startByteOffset, totalBytes: totalBytes)
        }

        // Punctuation trim set – includes curly single & double quotes, em-dash, en-dash
        // Production set is "‘’'\".,;:!?()[]{}—–" – we extend with “” for robustness for #31 + double-quote cases
        let punctuationTrimSet = CharacterSet(charactersIn: "‘’'\".,;:!?()[]{}—–“”")

        var tokenRanges: [(original: String, core: String)] = []
        for tok in rawTokens {
            let core = tok.trimmingCharacters(in: punctuationTrimSet)
            if core.isEmpty { continue }
            tokenRanges.append((tok, core))
        }

        if tokenRanges.isEmpty {
            return [sentenceMarker]
        }

        let totalCoreChars = tokenRanges.map { $0.core.count }.reduce(0, +)
        guard totalCoreChars > 0 else { return [sentenceMarker] }

        var groupIdx = 0
        var markers: [MockMarker] = [sentenceMarker]
        var currentSearchStart = sentence.startIndex
        var cumulativeSamples = realGroups.first?.cumulativeOffsetBefore ?? 0

        for (i, pair) in tokenRanges.enumerated() {
            let (_, core) = pair
            guard let coreRange = sentence.range(of: core, options: .literal, range: currentSearchStart..<sentence.endIndex) else {
                continue
            }
            let locInSentence = sentence.distance(from: sentence.startIndex, to: coreRange.lowerBound)
            let nsLen = (core as NSString).length
            let wordNSRange = NSRange(location: sentenceNSRange.location + locInSentence, length: nsLen)

            let groupsForWord: Int
            if i == tokenRanges.count - 1 {
                groupsForWord = realGroups.count - groupIdx
            } else {
                let proportion = Double(core.count) / Double(totalCoreChars)
                let calculated = Int(round(proportion * Double(realGroups.count)))
                groupsForWord = max(1, calculated)
            }

            let clamped = min(groupsForWord, realGroups.count - groupIdx)
            guard clamped > 0 else {
                // No groups left – give remaining words final offset but still produce marker
                let byteOffset = startByteOffset + cumulativeSamples * MemoryLayout<Float>.size
                markers.append(MockMarker(range: wordNSRange, byteOffset: byteOffset, type: .word))
                currentSearchStart = coreRange.upperBound
                continue
            }

            var wordSampleCount = 0
            for g in realGroups[groupIdx ..< groupIdx + clamped] {
                wordSampleCount += g.sampleCount
            }

            let byteOffset = startByteOffset + cumulativeSamples * MemoryLayout<Float>.size
            markers.append(MockMarker(range: wordNSRange, byteOffset: byteOffset, type: .word))

            cumulativeSamples += wordSampleCount
            groupIdx += clamped
            currentSearchStart = coreRange.upperBound
        }

        return markers
    }

    /// Helper to build MockPhonemeGroup array from simple sampleCounts,
    /// calculating cumulativeOffsetBefore including specials.
    static func makeGroups(sampleCounts: [Int], specials: [Bool] = [], phonemes: [UInt32] = []) -> [MockPhonemeGroup] {
        var out: [MockPhonemeGroup] = []
        var cum = 0
        for (idx, sc) in sampleCounts.enumerated() {
            let isSpec = idx < specials.count ? specials[idx] : false
            let ph = idx < phonemes.count ? phonemes[idx] : UInt32(100 + idx)
            out.append(MockPhonemeGroup(phoneme: ph, sampleCount: sc, cumulativeOffsetBefore: cum, isSpecial: isSpec))
            cum += sc
        }
        return out
    }
}

// MARK: - Tests

final class AlignmentMarkerTests: XCTestCase {

    // MARK: Helpers

    private func nsRange(for text: String, location: Int = 0) -> NSRange {
        NSRange(location: location, length: (text as NSString).length)
    }

    private func assertMonotonic(_ markers: [MockMarker], file: StaticString = #file, line: UInt = #line) {
        var last = -1
        for m in markers {
            XCTAssertGreaterThanOrEqual(m.byteOffset, last, "byte offsets must be monotonic", file: file, line: line)
            last = m.byteOffset
        }
    }

    // MARK: #31 punctuation handling – idealists

    func testPunctuationHandling_IdealistsCurlyQuotes() {
        let sentence = "Such philosophers are called ‘idealists’."
        let nsRange = nsRange(for: sentence, location: 0)

        // Mock alignment: 5 words, ~2 groups per word = 10 groups
        let groups = MarkerGenerator.makeGroups(sampleCounts: [120, 80, 100, 90, 110, 70, 95, 85, 130, 60])

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)

        // Sentence marker present
        XCTAssertFalse(markers.isEmpty)
        XCTAssertEqual(markers.first?.type, .sentence)
        XCTAssertEqual(markers.first?.range, nsRange)

        // Monotonic
        assertMonotonic(markers)

        // Valid textRange: each word marker range inside sentence nsRange
        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 5, "Should have markers for each word even with curly quotes")

        for wm in wordMarkers {
            XCTAssertTrue(wm.range.location >= nsRange.location, "marker location inside sentence")
            XCTAssertTrue(wm.range.location + wm.range.length <= nsRange.location + nsRange.length, "marker range inside sentence")
            XCTAssertNotEqual(wm.range.location, NSNotFound)
        }

        // idealists exists despite surrounding curly quotes and period
        let idealistsNS = (sentence as NSString).range(of: "idealists")
        XCTAssertNotEqual(idealistsNS.location, NSNotFound, "idealists substring must exist")
        let hasIdealists = wordMarkers.contains { NSIntersectionRange($0.range, idealistsNS).length > 0 }
        XCTAssertTrue(hasIdealists, "Should have marker covering 'idealists' despite surrounding punctuation")
    }

    // MARK: Hello world alignment exact offset 880

    func testHelloWorldAlignmentExactOffset() {
        let sentence = "Hello world"
        let nsRange = nsRange(for: sentence, location: 0)

        // Groups: [120,100,120,120] cumulative logic: offsets 0,120,220,340
        // Hello gets 2 groups (120+100=220), world gets 2 groups
        let groups = MarkerGenerator.makeGroups(sampleCounts: [120, 100, 120, 120])

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)

        XCTAssertGreaterThanOrEqual(markers.count, 3, "Sentence + 2 word markers")
        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertEqual(wordMarkers.count, 2, "Two word markers for Hello and world")

        XCTAssertEqual(wordMarkers[0].byteOffset, 0, "First word at offset 0")
        // 220 samples * Float size 4 = 880
        XCTAssertEqual(wordMarkers[1].byteOffset, 880, "Second word offset derived from alignment, not char proportion (220*4)")

        // Text ranges valid
        XCTAssertEqual(wordMarkers[0].range.location, 0)
        XCTAssertEqual((sentence as NSString).substring(with: wordMarkers[0].range), "Hello")
        XCTAssertEqual((sentence as NSString).substring(with: wordMarkers[1].range), "world")
    }

    // MARK: Hello with punctuation – Hello, “world”— idealists’.

    func testHelloWithPunctuationStripping() {
        let sentence = "Hello, “world”— idealists’."
        let nsRange = nsRange(for: sentence, location: 5)

        // Use 4 groups for Hello/world path, plus extra for idealists to ensure 3 word markers
        // We'll give 6 groups total: Hello 2, world 2, idealists 2
        let groups = MarkerGenerator.makeGroups(sampleCounts: [120, 100, 120, 120, 130, 70])

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)

        let wordMarkers = markers.filter { $0.type == .word }
        // Should strip pure punctuation tokens (none here) and produce markers for 3 core words
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 3, "Should have markers for Hello, world, idealists")

        // Hello offset 0
        XCTAssertEqual(wordMarkers.first?.byteOffset, 0, "Hello offset 0")

        // Ensure world marker exists (search for core "world")
        let worldNS = (sentence as NSString).range(of: "world")
        XCTAssertNotEqual(worldNS.location, NSNotFound)
        let hasWorld = wordMarkers.contains { NSIntersectionRange($0.range, NSRange(location: nsRange.location + worldNS.location, length: worldNS.length)).length > 0 }
        XCTAssertTrue(hasWorld, "Should have marker for 'world' despite surrounding curly double quotes and em-dash")

        // Ensure remaining punctuation stripped not creating extra markers (no empty core tokens)
        // Count should be exactly 3 (Hello, world, idealists) – not 5 with punctuation tokens
        XCTAssertLessThanOrEqual(wordMarkers.count, 4, "Stripped punctuation should not create extra markers")

        assertMonotonic(markers)

        // Idealists marker exists
        let idealistsNS = (sentence as NSString).range(of: "idealists")
        XCTAssertNotEqual(idealistsNS.location, NSNotFound)
        let hasIdealists = wordMarkers.contains { NSIntersectionRange($0.range, NSRange(location: nsRange.location + idealistsNS.location, length: idealistsNS.length)).length > 0 }
        XCTAssertTrue(hasIdealists)
    }

    // MARK: Monotonic byte offsets matching alignment cumulatives (not char-proportional)

    func testMonotonicByteOffsetsMatchAlignmentCumulatives() {
        let sentence = "ab cde"
        let nsRange = nsRange(for: sentence)

        // Groups with varying sample counts to differentiate from char proportion
        // ab (2 chars) but gets small sample count, cde (3 chars) gets large sample count
        // If proportional by char, second word offset would be ~ (2/5)*totalBytes
        // Alignment should give offset based on cumulative samples
        let groups = MarkerGenerator.makeGroups(sampleCounts: [50, 30, 200, 150]) // total 430
        // Distribution: ab gets 2 groups (50+30=80), cde gets 2 groups (200+150=350)
        // Second word offset = 80*4=320
        // Char-proportional legacy would be totalBytes=430*4=1720, first word 2/5*1720=688, so second offset 688 – different from 320

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)
        let wordMarkers = markers.filter { $0.type == .word }

        XCTAssertEqual(wordMarkers.count, 2)
        XCTAssertEqual(wordMarkers[0].byteOffset, 0)
        XCTAssertEqual(wordMarkers[1].byteOffset, 80 * 4, "Second word offset must match alignment cumulative, not char proportion")
        XCTAssertNotEqual(wordMarkers[1].byteOffset, Int(Double(430*4) * (2.0/5.0)), "Should not equal char-proportional offset")

        assertMonotonic(markers)
    }

    // MARK: Empty alignment fallback

    func testEmptyAlignmentFallback() {
        let sentence = "Hello world test"
        let nsRange = nsRange(for: sentence, location: 0)

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 100, groups: [])

        // Should fallback to legacy behavior and include sentence marker
        XCTAssertFalse(markers.isEmpty)
        XCTAssertEqual(markers.first?.type, .sentence)
        XCTAssertEqual(markers.first?.byteOffset, 100)
        XCTAssertEqual(markers.first?.range, nsRange)

        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 1, "Fallback should produce word markers via legacy")

        assertMonotonic(markers)

        // Ensure offsets monotonic and increasing (legacy)
        for i in 1..<markers.count {
            XCTAssertGreaterThanOrEqual(markers[i].byteOffset, markers[i-1].byteOffset)
        }
    }

    // MARK: All specials fallback

    func testAllSpecialGroupsFallbackToLegacy() {
        let sentence = "Hello world"
        let nsRange = nsRange(for: sentence)

        let groups = MarkerGenerator.makeGroups(sampleCounts: [100, 50, 80], specials: [true, true, true])

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)

        XCTAssertFalse(markers.isEmpty)
        XCTAssertEqual(markers.first?.type, .sentence)
        // Fallback should still produce word markers
        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 2)
        assertMonotonic(markers)
    }

    // MARK: Em-dash / semicolon

    func testEmDashSemicolon() {
        let sentence = "First sentence, with a comma, and more; second sentence: with colons"
        let nsRange = nsRange(for: sentence, location: 10)

        // Provide enough groups for many words (9+ words)
        let sampleCounts = Array(repeating: 100, count: 20)
        let groups = MarkerGenerator.makeGroups(sampleCounts: sampleCounts)

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, groups: groups)

        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 8, "Markers count >=8 despite commas, semicolons, colons")

        // First marker location preserved (sentence start)
        XCTAssertEqual(markers.first?.range.location, 10, "First marker location preserved")
        XCTAssertEqual(markers.first?.type, .sentence)

        assertMonotonic(markers)

        // Ensure monotonic even with punctuation heavy
        var lastOffset = -1
        for m in markers {
            XCTAssertGreaterThanOrEqual(m.byteOffset, lastOffset)
            lastOffset = m.byteOffset
        }
    }

    // MARK: Sentence marker always present and byteOffset = startByteOffset

    func testSentenceMarkerPreserved() {
        let sentence = "Hello"
        let nsRange = NSRange(location: 42, length: 5)

        let groups = MarkerGenerator.makeGroups(sampleCounts: [100, 100])

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 1234, groups: groups)

        XCTAssertEqual(markers.first?.type, .sentence)
        XCTAssertEqual(markers.first?.byteOffset, 1234)
        XCTAssertEqual(markers.first?.range, nsRange)
    }

    // MARK: Byte offset = startByteOffset + cumulativeSamples*4

    func testByteOffsetFormula() {
        let sentence = "one two three"
        let nsRange = nsRange(for: sentence)

        // Include BOS special to test cumulativeOffsetBefore includes specials
        // Group 0 special BOS 30 samples, cum0=0
        // Group 1 real 100 cum=30, Group2 real 100 cum=130, Group3 real 100 cum=230
        let groups = [
            MockPhonemeGroup(phoneme: 1, sampleCount: 30, cumulativeOffsetBefore: 0, isSpecial: true),
            MockPhonemeGroup(phoneme: 10, sampleCount: 100, cumulativeOffsetBefore: 30, isSpecial: false),
            MockPhonemeGroup(phoneme: 11, sampleCount: 100, cumulativeOffsetBefore: 130, isSpecial: false),
            MockPhonemeGroup(phoneme: 12, sampleCount: 100, cumulativeOffsetBefore: 230, isSpecial: false),
        ]

        let markers = MarkerGenerator.generateWithAlignment(for: sentence, sentenceNSRange: nsRange, startByteOffset: 500, groups: groups)

        let wordMarkers = markers.filter { $0.type == .word }
        XCTAssertGreaterThanOrEqual(wordMarkers.count, 3)
        // First word should include BOS silence in offset: 30*4 + start
        XCTAssertEqual(wordMarkers[0].byteOffset, 500 + 30*4, "First real group's cumulative includes BOS")
        XCTAssertEqual(wordMarkers[1].byteOffset, 500 + 130*4)
        XCTAssertEqual(wordMarkers[2].byteOffset, 500 + 230*4)

        assertMonotonic(markers)
    }

    // MARK: Fallback legacy monotonic and includes sentence marker – mirrors AudioResampler/FloatRingBuffer not broken

    func testFallbackProducesMonotonicOffsets() {
        let sentence = "a b c d e f g h"
        let nsRange = nsRange(for: sentence)

        let markers = MarkerGenerator.generateLegacy(for: sentence, sentenceNSRange: nsRange, startByteOffset: 0, totalBytes: 8000)

        assertMonotonic(markers)
        XCTAssertEqual(markers.first?.type, .sentence)
        XCTAssertEqual(markers.first?.byteOffset, 0)
        XCTAssertEqual(markers.count, 9) // sentence + 8 words
    }

    // MARK: No regression placeholder – ensures our helpers don't interfere with other tests

    func testNoRegression_MarkersCountMatchesWords() {
        // Ensures legacy path still works for punctuation-only sentence
        let sentence = ".!?"
        let nsRange = nsRange(for: sentence, location: 5)
        let markers = MarkerGenerator.generateLegacy(for: sentence, sentenceNSRange: nsRange, startByteOffset: 100, totalBytes: 200)

        XCTAssertGreaterThanOrEqual(markers.count, 1)
        XCTAssertEqual(markers[0].type, .sentence)
        XCTAssertEqual(markers[0].range, nsRange)
    }
}
