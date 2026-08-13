// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import ProjectDescription

// MARK: - Common Constants

let projectName = "Piper"
let appName = "\(projectName)App"
let sharedUtilsName = "\(projectName)AppUtils"
let screenshotTargetName = "Screenshots"
let ttsExtensionName = "\(projectName)TTS"
let buildScriptPath = "\(appName)/BuildScripts"
let configsPath = "\(buildScriptPath)/Configs"

let defaultSettings: DefaultSettings = .recommended(excluding:
                                                        [
                                                            "CODE_SIGN_IDENTITY",
                                                            "PROVISIONING_PROFILE_SPECIFIER",
                                                            "ENABLE_HARDENED_RUNTIME"
                                                        ]
)
// MARK: - Destinations

let destinations: ProjectDescription.Destinations = [
    .iPhone,
    .iPad,
    .mac
]

// MARK: - Entitlements

let sharedAppGroupName = "group.pipertts.data"
let extensionEntitlements: [String: Plist.Value] = [
    "com.apple.security.application-groups": .array([
        .string(sharedAppGroupName)
    ]),
    "inter-app-audio": .boolean(true)
]
let appEntitlements: [String: Plist.Value] = [
    "com.apple.security.app-sandbox": .boolean(true),
    "com.apple.security.application-groups": .array([
        .string(sharedAppGroupName)
    ]),
    "inter-app-audio": .boolean(true),
    "com.apple.security.network.client": .boolean(true)
]

// MARK: - Project

let project = Project(
    name: projectName,
    organizationName: "Ihor Shevchuk",
    targets: [
        .target(
            name: projectName,
            destinations: destinations,
            product: .app,
            bundleId: "$(APP_BUNDLE_IDENTIFIER)",
            infoPlist: "\(appName)/Resources/Info.plist",
            sources: ["\(appName)/Sources/**"],
            resources: [
                "\(appName)/Resources/Localization/*",
                "\(appName)/Resources/Assets.xcassets"
            ],
            entitlements: .dictionary(appEntitlements),
            scripts: [
                .pre(script: """
                             mise run lint --fix
                             """,
                     name: "Run SwiftLint Autocorrector"),
                .post(script: """
                              mise run lint
                              """,
                      name: "Run SwiftLint Analyzer")
            ],
            dependencies: [
                .target(name: sharedUtilsName, status: .required),
                .target(name: ttsExtensionName, status: .required)
            ],
            settings: .settings(configurations:
                                    [
                                        .debug(name: "Debug",
                                               xcconfig: "\(configsPath)/app_debug.xcconfig"),
                                        .release(name: "Release",
                                                 xcconfig: "\(configsPath)/app_release.xcconfig")
                                    ],
                                defaultSettings: defaultSettings),
            additionalFiles: [
                "\(buildScriptPath)/Linting/**"
            ]
        ),
        .target(name: ttsExtensionName,
                destinations: destinations,
                product: .appExtension,
                bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER)",
                infoPlist: "\(ttsExtensionName)/Info.plist",
                sources: ["\(ttsExtensionName)/**"],
                entitlements: .dictionary(extensionEntitlements),
                dependencies: [
                    .target(name: sharedUtilsName, status: .required),
                    .external(name: "espeak-ng-data"),
                    .external(name: "piper-objc"),
                    .sdk(name: "c++", type: .library, status: .required)
                ], settings: .settings(configurations: [
                    .debug(name: "Debug",
                           xcconfig: "\(configsPath)/extension_debug.xcconfig"),
                    .release(name: "Release",
                             xcconfig: "\(configsPath)/extension_release.xcconfig")
                ]),
               ),
        .target(name: sharedUtilsName,
                destinations: destinations,
                product: .staticFramework,
                bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER)",
                sources: ["\(sharedUtilsName)/**"],
                settings: .settings(configurations: [
                    .debug(name: "Debug",
                           xcconfig: "\(configsPath)/utils_debug.xcconfig"),
                    .release(name: "Release",
                             xcconfig: "\(configsPath)/utils_release.xcconfig")
                ],
                                    defaultSettings: .recommended(excluding: [
                                        "DEFINES_MODULE"
                                    ]))
               ),
        .target(name: "\(screenshotTargetName)",
                destinations: destinations,
                product: .uiTests,
                bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER)",
                sources: [
                    "\(screenshotTargetName)/**",
                    "fastlane/SnapshotHelper.swift"
                ],
                dependencies: [
                    .target(name: projectName)
                ]
        )
    ],
)
