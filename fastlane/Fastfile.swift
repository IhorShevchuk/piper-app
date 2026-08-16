import Foundation

class Fastfile: LaneFile {

    func captureScreenshotsLane() {
        desc("Generate iOS screenshots using UI Tests")
        captureScreenshots(
            outputDirectory: "fastlane/screenshots/ios"
        )
    }

    func captureMacScreenshotsLane() {
        desc("Generate macOS screenshots using UI Tests – fastlane snapshot does not officially support macOS, so we run the UITest bundle directly and collect from SnapshotHelper cache")

        // Ensure clean slate
        sh("rm -rf ~/Library/Caches/tools.fastlane/screenshots")
        sh("rm -rf fastlane/screenshots/macos && mkdir -p fastlane/screenshots/macos/en-US")

        // Run the Screenshots scheme for macOS. SnapshotHelper writes to ~/Library/Caches/tools.fastlane/screenshots
        otherAction.runTests(
            workspace: "Piper.xcworkspace",
            scheme: "Screenshots",
            destination: "platform=macOS",
            outputDirectory: "fastlane/test_output/macos-screenshots",
            resultBundle: false,
            failBuild: true
        )

        // Copy out what SnapshotHelper produced
        sh("""
            if [ -d ~/Library/Caches/tools.fastlane/screenshots ]; then
              find ~/Library/Caches/tools.fastlane/screenshots -type f -name "*.png" -exec cp {} fastlane/screenshots/macos/en-US/ \\;
              echo "Copied $(ls -1 fastlane/screenshots/macos/en-US | wc -l) macOS screenshots"
              ls -lh fastlane/screenshots/macos/en-US
            else
              echo "No screenshots found in ~/Library/Caches/tools.fastlane/screenshots – check SnapshotHelper output"
              exit 1
            fi
            """)

        // Also keep a framed ready variant for ASC upload if needed
        sh("mkdir -p fastlane/screenshots/macos && cp -R fastlane/screenshots/macos/en-US fastlane/screenshots/macos/en-US || true")
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
