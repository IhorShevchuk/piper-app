// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

extension FileManager {
    public struct ModelPaths {
        public let model: URL
        public let json: URL
        public let info: ModelInfo?
        public init?(model: URL?, json: URL?) {
            guard let model, let json else {
                return nil
            }
            self.model = model
            self.json = json
            self.info = try? ModelInfo.create(from: json)
        }
        
        public var exist: Bool {
            return FileManager.default.fileExists(atPath: model.path) &&
            FileManager.default.fileExists(atPath: json.path)
        }
        
        public var modelFolder: URL? {
            if self == ModelPaths.engine {
                return nil
            }
            
            let modelParent = model.deletingLastPathComponent()
            let jsonParent = json.deletingLastPathComponent()
            if modelParent == jsonParent {
                return modelParent
            }
            return nil
        }
        
        public static var engine: ModelPaths? {
            return ModelPaths(model: FileManager.Constants.modelURL,
                              json: FileManager.Constants.jsonModelURL)
        }
        
        public static var installNew: ModelPaths? {
            guard let modelsFolder = FileManager.Constants.modelsFolderURL else {
                return nil
            }
            let installNewFolder = modelsFolder.appendingPathComponent(UUID().uuidString)
            return ModelPaths(model: installNewFolder.appendingPathComponent(PiperAppUtils.Constants.modelFileNameWithExtension),
                              json: installNewFolder.appendingPathComponent(PiperAppUtils.Constants.modelJSONFileNameWithExtension))
        }
        
        public var isInstalled: Bool {
            if self == ModelPaths.engine && exist {
                return true
            }
            
            return ModelPaths.installed.contains(self)
        }
        
        @FileBacked<[ModelPaths]>(default: [], urlProvider: {
            Constants.modelsJsonURL
        }) static var installed
        
        public static var installedModels: [ModelPaths] {
            get {
                var result = Set<ModelPaths>()
                if let legacy = ModelPaths.engine,
                    legacy.exist {
                    result.insert(legacy)
                }
                result.formUnion(installed)
                return Array(result)
            }
            set {
                self.installed = newValue
            }
        }
    }
    
    enum Error: Swift.Error {
        case nilModelFolderURL
    }
    
    public var isInstalled: Bool {
        guard let paths = ModelPaths.engine else {
            return false
        }
        return paths.exist
    }
    
    public func createModelPathsFolder(paths: ModelPaths) throws {
        guard let folder = paths.modelFolder else {
            throw Error.nilModelFolderURL
        }
        try createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
    }
}

extension FileManager.ModelPaths: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model.standardizedFileURL == rhs.model.standardizedFileURL &&
        lhs.json.standardizedFileURL == rhs.json.standardizedFileURL &&
        lhs.info == rhs.info
    }
}

extension FileManager.ModelPaths: Codable {
    enum CodingKeys: String, CodingKey {
        case model
        case json
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try values.decode(URL.self, forKey: .model)
        self.json = try values.decode(URL.self, forKey: .json)
        self.info = try? ModelInfo.create(from: self.json)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(model, forKey: .model)
        try values.encode(json, forKey: .json)
    }
}

extension FileManager.ModelPaths: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(model.standardizedFileURL)
        hasher.combine(json.standardizedFileURL)
        hasher.combine(info)
    }
}
