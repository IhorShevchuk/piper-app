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
        sh("rm -rf fastlane/test_output && mkdir -p fastlane/test_output")
        captureScreenshots(
            outputDirectory: "fastlane/screenshots/ios"
        )
    }

    func captureMacScreenshotsLane() {
        desc("Generate macOS screenshots for all metadata languages")

        let languages = supportedLanguages()

        sh("rm -rf ~/Library/Caches/tools.fastlane/screenshots")
        sh("rm -rf fastlane/screenshots/macos && mkdir -p fastlane/screenshots/macos")
        sh("rm -rf fastlane/test_output && mkdir -p fastlane/test_output")

        for lang in languages {
            sh("mkdir -p ~/Library/Caches/tools.fastlane")
            sh("mkdir -p ~/Library/Caches/tools.fastlane/screenshots")
            sh("echo \"\(lang)\" > ~/Library/Caches/tools.fastlane/language.txt")
            sh("echo \"\(lang)\" > ~/Library/Caches/tools.fastlane/locale.txt")
            sh("mkdir -p fastlane/screenshots/macos/\(lang)")
            sh("rm -f ~/Library/Caches/tools.fastlane/screenshots/*.png || true")
            sh("rm -rf fastlane/test_output/macos-screenshots-\(lang).xcresult || true")

            otherAction.runTests(
                workspace: "Piper.xcworkspace",
                scheme: "Screenshots",
                destination: "platform=macOS",
                outputDirectory: "fastlane/test_output/macos-screenshots-\(lang)",
                resultBundle: false,
                failBuild: true
            )

            sh("""
                if [ -d ~/Library/Caches/tools.fastlane/screenshots ]; then
                  find ~/Library/Caches/tools.fastlane/screenshots -maxdepth 1 -type f -name "*.png" -exec cp {} fastlane/screenshots/macos/\(lang)/ \\; || true
                  echo "Lang \(lang): $(ls -1 fastlane/screenshots/macos/\(lang) 2>/dev/NULL | wc -l) files"
                fi
                """)
        }

        sh("ls -R fastlane/screenshots/macos || true")
        sh("ls -R fastlane/test_output || true")
    }

    func captureAllScreenshotsLane() {
        desc("Generate iOS + macOS screenshots")
        captureScreenshotsLane()
        captureMacScreenshotsLane()
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
        let platforms = ["ios", "osx"]

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
