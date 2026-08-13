// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public enum Constants {
    public static let speakerIdSeparator = "<+>"
    public static let modelFileName = "model"
    public static let modelsFolderName = "models"
    public static let modelExtensiom = "onnx"
    public static let jsonModelExtension = "json"
    public static var modelFileNameWithExtension: String {
        return "\(modelFileName).\(modelExtensiom)"
    }
    public static var modelJSONFileNameWithExtension: String {
        return "\(modelFileNameWithExtension).\(jsonModelExtension)"
    }

    public static var modelsJSONFileName: String {
        return "\(modelsFolderName).\(jsonModelExtension)"
    }

#if canImport(UniformTypeIdentifiers)
    @available(macOS 11.0, iOS 14.0, *)
    public static var jsonUTI: UTType { .json }
    @available(macOS 11.0, iOS 14.0, *)
    public static var modelUTI: UTType { UTType(filenameExtension: modelExtensiom) ?? .item }
#else
    // Linux / non-Apple fallback – simple string identifiers
    public static let jsonUTI: String = "public.json"
    public static let modelUTI: String = "org.onnx.model"
#endif
}
