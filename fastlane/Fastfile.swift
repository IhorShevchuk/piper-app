import Foundation

class Fastfile: LaneFile {

    private func supportedLanguages() -> [String] {
        let fm = FileManager.default
        let metaPath = "fastlane/metadata"
        if let items = try? fm.contentsOfDirectory(atPath: metaPath) {
            return items.filter { name in
                var isDir: ObjCBool = false
                let full = (metaPath as NSString).appendingPathComponent(name)
                return fm.fileExists(atPath: full, isDirectory: &isDir) && isDir.boolValue
            }.sorted()
        }
        return ["en-US"]
    }

    func captureScreenshotsLane() {
        desc("Generate iOS screenshots using UI Tests – languages from fastlane/metadata")
        sh(command: "rm -rf fastlane/test_output && mkdir -p fastlane/test_output")
        let languages = supportedLanguages()
        captureScreenshots(
            languages: languages,
            outputDirectory: "fastlane/screenshots/ios"
        )
    }

    func updateReleaseNotesLane(withOptions options: [String: String]?) {
        desc("Update the 'What's New' text in App Store Connect using the metadata files. Pass `appVersion` as a parameter.")

        guard let appVersion = options?["appVersion"] else {
            fatalError("""
            Missing required parameter 'appVersion'.
            Usage: fastlane updateReleaseNotes appVersion:"1.2.3"
            """)
        }

        guard let appIdentifier = options?["appIdentifier"] else {
            fatalError("""
            Missing required parameter 'appIdentifier'.
            Usage: fastlane updateReleaseNotes appIdentifier:"com.app.id"
            """)
        }

        guard let keyContent = options?["apiKeyPath"] else {
            fatalError("""
            Missing required parameter 'apiKeyPath'.
            Usage: fastlane updateReleaseNotes apiKeyPath:"path/to/key.json"
            """)
        }

        let skipPreview = Bool(options?["skipPreview"] ?? "") ?? false
        let uploadScreenshots = Bool(options?["uploadScreenshots"] ?? "false") ?? false
        let platformOption = options?["platform"]?.lowercased() ?? "all"

        let platforms: [String]
        switch platformOption {
        case "ios":
            platforms = ["ios"]
        case "osx", "macos", "mac":
            platforms = ["osx"]
        default:
            platforms = ["ios", "osx"]
        }

        for platform in platforms {
            uploadToAppStore(
                apiKeyPath: .userDefined(keyContent),
                appIdentifier: .userDefined(appIdentifier),
                appVersion: .userDefined(appVersion),
                platform: platform,
                metadataPath: "./fastlane/metadata",
                skipBinaryUpload: true,
                skipScreenshots: .userDefined(!uploadScreenshots),
                skipMetadata: false,
                force: .userDefined(skipPreview),
                overwriteScreenshots: false,
                runPrecheckBeforeSubmit: false,
            )
        }
    }
}
