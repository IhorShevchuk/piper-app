<p align="center">
  <a href="https://apps.apple.com/us/app/piper-neural-tts/id6759636010">
    <img src="PiperApp/Resources/piper_apple_app_logo.png" width="130"><br>
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" width="180">
  </a>
</p>

<h3 align="center">
  Piper is now available on the App Store! 🎉<br>
  Experience high-quality <b>offline neural text-to-speech</b> directly on your device.<br><br>
  Want to try the latest features early?<br>
  Join the <a href="https://testflight.apple.com/join/Adkg5F5H">TestFlight Beta</a> 🚀
</h3>

<p align="center">
  <a href="https://testflight.apple.com/join/Adkg5F5H">
    <img src="https://camo.githubusercontent.com/f8394f7cf70cc272e627e53e2d46241bc3fc83f145ee9e95a09a248efa2e72e8/68747470733a2f2f616e6f746865726c656e732e6170702f74657374666c696768742d62616467652e706e67" width="180">
  </a>
</p>

[![Build](https://github.com/IhorShevchuk/piper-app/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/IhorShevchuk/piper-app/actions/workflows/build.yml)

# 📥 Cloning & Building Piper

## System Requirements

* iOS 18.0+
* macOS 13.3+
* Xcode 26+
* `mise`

---

## Getting the Sources

```bash
git clone https://github.com/IhorShevchuk/piper-app.git
cd piper-app
```

---

## Install Toolchain (via mise)

Piper uses `mise` to manage development tools.

Install mise

```bash
curl https://mise.run | sh
```

Then install tools:

```bash
mise install
```

This installs:

* Tuist
* SwiftLint

---

## Generate the Xcode Project

Piper uses **Tuist** with Swift Package Manager for dependencies. First resolve SPM dependencies, then generate the workspace:

```bash
mise run install
mise run generate
```

Open the generated `Piper.xcworkspace` in Xcode.

```bash
open Piper.xcworkspace 
```

> **Note:** Run `mise run install` whenever `Package.swift` or dependencies change. Otherwise `mise run generate` alone is sufficient.

### Available Mise Tasks

| Task | Description |
|------|-------------|
| `mise run install` | Resolve SPM dependencies (`Package.swift`) |
| `mise run generate` | Generate Xcode project |
| `mise run build <number> [simulator\|device]` | Build from command line (for CI) |
| `mise run lint [--fix]` | Run SwiftLint |

---

# 📱 Running the App

## Simulator

1. Open the generated workspace
2. Select an iOS Simulator
3. Build & Run `Piper`

---

## Physical Device

1. Open the generated workspace
2. Select your device
3. Configure code signing for:
   * `Piper`
   * `PiperTTS`

---

# 🧪 Testing

Piper now includes unit tests in `PiperTests` targeting `PiperAppUtils` core logic.

## Run Tests in Xcode

1. Generate project: `mise run generate`
2. Open `Piper.xcworkspace`
3. Product → Test (⌘U) or select the `PiperTests` scheme

## Run Tests from CLI

macOS (works over SSH / CI without keychain):

```bash
mise run generate
xcodebuild test -workspace Piper.xcworkspace -scheme Piper -destination 'platform=macOS' -only-testing:PiperTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

iOS Simulator (requires simulator runtime):

```bash
xcodebuild test -workspace Piper.xcworkspace -scheme Piper -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PiperTests
```

Or with Tuist:

```bash
tuist test --test-targets PiperTests
```

39 tests currently – 6 Constants, 12 ModelPaths, 5 Language/Audio, 7 Logger, 9 ModelInfo – all passing as of 2026-08-15 on Xcode 26.6.

## What’s Tested

- `Constants` – file naming, UTI correctness, extension composition
- `FileManager.ModelPaths` – equality & hash (standardized URLs), folder derivation, existence checks, `Equatable`/`Codable`, installNew nil handling, installed checks
- `ModelInfo` – decoding with / without speakers, voiceId generation, equality, `nil` file handling, malformed voiceId handling
- `Language` / `Audio` – decoding, Equatable/Hashable, country/language fallback
- `Logger` – level ordering, allCases, logLevel getter/setter, masked logging logic

The `PiperTests` target is defined in `Project.swift` as `.unitTests` with `bundleId: dev.ihor-shevchuk.piper.tests` and `CODE_SIGNING_ALLOWED=NO`, depends only on `PiperAppUtils`, so it runs fast without needing the TTS engine or model files.

---

## Project Structure

* `PiperApp` – Main iOS/macOS app
* `PiperTTS` – Audio Unit extension
* `PiperAppUtils` – Shared utilities, model management, constants
* `PiperTests` – Unit tests for `PiperAppUtils`
* `Screenshots` – UI tests for App Store screenshots

## License

MIT – see `LICENSE-MIT`, GPL-3.0 for bundled resources
