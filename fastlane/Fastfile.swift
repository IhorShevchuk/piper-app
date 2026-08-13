import Foundation

class Fastfile: LaneFile {

    func captureScreenshotsLane() {
        desc("Generate screenshots for the app using UI Tests")
        captureScreenshots(
            outputDirectory: "fastlane/screenshots"
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
