// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

@propertyWrapper
struct FileBacked<Value: Codable> {
    private let urlProvider: () -> URL?
    private let defaultValue: Value
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(
        default defaultValue: @autoclosure @escaping () -> Value,
        urlProvider: @escaping () -> URL?,
    ) {
        self.urlProvider = urlProvider
        self.defaultValue = defaultValue()
    }
    
    var wrappedValue: Value {
        get {
            load() ?? defaultValue
        }
        set {
            save(newValue)
        }
    }
}

private extension FileBacked {
    func load() -> Value? {
        guard let url = urlProvider() else {
            Log.error("Path to data file is nil. Returning default.")
            return nil
        }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
            return try decoder.decode(Value.self, from: data)
        } catch {
            Log.error("Failed to load \(Value.self) from \(url): \(error)")
            return nil
        }
    }
    
    func save(_ value: Value) {
        guard let url = urlProvider() else {
            Log.error("Path to data file is nil. Skipping save.")
            return
        }
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
            var attr = try FileManager.default.attributesOfItem(atPath: url.path)
            if attr[.protectionKey] as? String != FileProtectionType.none.rawValue {
                attr[.protectionKey] = FileProtectionType.none.rawValue
                try FileManager.default.setAttributes(attr, ofItemAtPath: url.path)
            }
            Log.debug("Saved \(Value.self) (\(data.count) bytes) to \(url).")
        } catch {
            Log.error("Failed to save \(Value.self) to \(url): \(error)")
        }
    }
}
