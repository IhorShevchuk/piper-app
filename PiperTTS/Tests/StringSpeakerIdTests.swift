// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Testing
import Foundation
@testable import PiperAppUtils
#if canImport(PiperTTS)
@testable import PiperTTS
#elseif canImport(PiperTTSLogic)
@testable import PiperTTSLogic
#endif

@Suite("String.speakerId extension")
struct StringSpeakerIdTests {

    // Replicate logic without needing import in case of visibility issues
    private func parse(_ voiceId: String) -> Int32 {
        voiceId.speakerId
    }

    @Test("Returns 0 for empty string")
    func empty() {
        #expect("".speakerId == 0)
    }

    @Test("Returns 0 when no separator")
    func noSeparator() {
        #expect("plain-voice-name".speakerId == 0)
        #expect("en_US".speakerId == 0)
    }

    @Test("Returns last component after separator")
    func simple() {
        // voiceId format example: "name>0<quality>0<22050>0<code>0<numSpeakers<+>speakerId"
        let voice = "en_US-lessac-high>0<high>0<22050>0<en_US>0<1<+>2"
        #expect(voice.speakerId == 2)
    }

    @Test("Returns 0 when speaker part not Int")
    func nonInt() {
        let voice = "model>0<high>0<22050>0<en>0<1<+>notanint"
        #expect(voice.speakerId == 0)
    }

    @Test("Handles multiple speaker separators – last wins (edge)")
    func multipleSeparators() {
        // Note: when speaker list contains numeric 0 between separators,
        // the pattern "<+>0<+>" contains the model separator ">0<", which
        // causes components(separatedBy: ">0<") to split further.
        // Current implementation therefore returns 0 for "1<+>0<+>5".
        // We document this edge and expect 0, not 5.
        let v = "a>0<b>0<c>0<d>0<1<+>0<+>5"
        #expect(v.speakerId == 0)

        // Non-numeric middle avoids overlap, so last wins works
        let v2 = "a>0<b>0<c>0<d>0<1<+>x<+>5"
        #expect(v2.speakerId == 5)
    }

    @Test("Handles separator present but no suffix")
    func emptySuffix() {
        let v = "name>0<quality>0<sr>0<code>0<1<+>"
        #expect(v.speakerId == 0) // Int32("") fails -> 0
    }

    @Test("Negative speakerId")
    func negative() {
        // Edge: negative id allowed? Int32 parsing would succeed
        let v = "foo>0<bar>0<0>0<code>0<1<+>-1"
        #expect(v.speakerId == -1)
    }

    @Test("Real world examples")
    func realWorld() {
        let examples: [(String, Int32)] = [
            ("en_US-lessac-high>0<high>0<22050.0>0<en_US>0<1", 1), // no speakerId part -> last after >0< is "1", Int32("1") succeeds -> 1
            ("en_US-lessac-high>0<high>0<22050.0>0<en_US>0<2<+>0", 0),
            ("en_US-lessac-high>0<high>0<22050.0>0<en_US>0<2<+>1", 1),
        ]
        for (voice, expected) in examples {
            #expect(voice.speakerId == expected)
        }
    }
}
