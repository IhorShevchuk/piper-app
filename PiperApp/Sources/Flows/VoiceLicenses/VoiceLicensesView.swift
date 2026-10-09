// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct VoiceLicensesView: View {

    @StateObject var hostModel: VoiceLicensesHostModel

    @ViewBuilder
    private func voiceRow(_ voice: Voice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(voice.name.capitalized + " " + voice.quality)
                .font(.headline)
            Text("\("voice_license".localized): \(voice.license ?? "license_unknown".localized)")
            if let modelLicense = voice.modelLicense {
                Text("\("model_license".localized): \(modelLicense)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let trainingData = voice.trainingData {
                Text("\("training_data".localized): \(trainingData.license ?? "license_unknown".localized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let urlString = trainingData.url,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    Link(urlString, destination: url)
                        .font(.caption)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        Group {
            if hostModel.viewModel.showLoadingIndicator {
                ProgressView()
            } else if hostModel.viewModel.showError || hostModel.viewModel.voices.isEmpty {
                // Fail soft: a catalog load failure shows the same empty
                // state as an empty catalog instead of an error screen.
                Text("no_voices")
            } else {
                List {
                    ForEach(hostModel.viewModel.voices, id: \.key) { voice in
                        voiceRow(voice)
                    }
                }
            }
        }
        .navigationTitle("voice_licenses")
    }
}
