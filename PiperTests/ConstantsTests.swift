// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
import UniformTypeIdentifiers
@testable import PiperAppUtils

final class ConstantsTests: XCTestCase {

    func testSpeakerSeparator() {
        XCTAssertEqual(Constants.speakerIdSeparator, "<+>")
    }

    func testModelFileName() {
        XCTAssertEqual(Constants.modelFileName, "model")
        XCTAssertEqual(Constants.modelsFolderName, "models")
        XCTAssertEqual(Constants.modelExtensiom, "onnx")
        XCTAssertEqual(Constants.jsonModelExtension, "json")
    }

    func testFileNameWithExtension() {
        XCTAssertEqual(Constants.modelFileNameWithExtension, "model.onnx")
        XCTAssertEqual(Constants.modelJSONFileNameWithExtension, "model.onnx.json")
        XCTAssertEqual(Constants.modelsJSONFileName, "models.json")
    }

    func testModelFileNameWithExtensionComposes() {
        let expected = "\(Constants.modelFileName).\(Constants.modelExtensiom)"
        XCTAssertEqual(Constants.modelFileNameWithExtension, expected)
        let expectedJson = "\(expected).\(Constants.jsonModelExtension)"
        XCTAssertEqual(Constants.modelJSONFileNameWithExtension, expectedJson)
    }

    func testUTITypes() {
        XCTAssertTrue(Constants.jsonUTI.conforms(to: .json))
        XCTAssertEqual(Constants.jsonUTI, UTType.json)
        // model UTI is derived from extension "onnx", fallback .item if unknown
        XCTAssertNotNil(Constants.modelUTI)
        // on iOS 15+ UTType for unknown extension may still be non-nil; we just check it isn't json
        XCTAssertNotEqual(Constants.modelUTI, .json)
    }

    func testModelUTIExtension() {
        // If system knows "onnx", preferredFilenameExtension should be onnx, else fallback still valid
        let ext = Constants.modelUTI.preferredFilenameExtension ?? Constants.modelExtensiom
        XCTAssertEqual(ext, Constants.modelExtensiom)
    }
}
