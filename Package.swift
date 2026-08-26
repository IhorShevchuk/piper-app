// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Piper",
    dependencies: [
        .package(url: "https://github.com/IhorShevchuk/piper-objc", from: "0.2.36")
    ],
    targets: []  // Tuist uses this only to resolve deps; targets are in Project.swift via .external()
)
