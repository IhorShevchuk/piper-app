// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk
//
// Tuist XcodeProj-based SPM integration: declare dependencies here, then reference in
// Project.swift via .external(name: "ProductName"). Run `mise run install` then `mise run generate` to resolve.

import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

#if os(Linux)
let piperDependencies: [Package.Dependency] = []
#else
let piperDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/IhorShevchuk/piper-objc", from: "0.2.30")
]
#endif

let package = Package(
    name: "Piper",
    platforms: [.iOS(.v15), .macOS(.v12)],
    dependencies: piperDependencies,
    targets: [
        // Minimal target for Linux `swift test` verification – excludes AVFoundation/iOS-only files
        // Module name matches production `PiperAppUtils` so `import PiperAppUtils` works
        .target(
            name: "PiperAppUtils",
            dependencies: [],
            path: "PiperAppUtils",
            exclude: [
                "AVAudioFormat+Utils.swift",
                "AVSpeechSynthesisProviderRequest.swift",
                "AVSpeechSynthesisProviderVoice+Utils.swift",
                "Logger.swift",
                "FileManager",
                "Tests"
            ],
            sources: [
                "API/Language.swift",
                "API/Audio.swift",
                "API/ModelInfo.swift",
                "API/MessageChannelKeys.swift",
                "Constants.swift"
            ]
        ),
        .testTarget(
            name: "PiperAppUtilsTests",
            dependencies: ["PiperAppUtils"],
            path: "PiperAppUtils/Tests"
        ),
        // For TTS pure logic we test via standalone target without needing PiperTTS framework (which needs AVFoundation)
        .target(
            name: "PiperTTSLogic",
            dependencies: ["PiperAppUtils"],
            path: "PiperTTS/Sources/Extension"
        ),
        .testTarget(
            name: "PiperTTSTests",
            dependencies: ["PiperAppUtils", "PiperTTSLogic"],
            path: "PiperTTS/Tests"
        )
    ]  // Tuist uses this only to resolve deps; targets are in Project.swift via .external()
)
