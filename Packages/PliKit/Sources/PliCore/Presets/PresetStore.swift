import Foundation

public enum PresetStoreError: Error, Equatable {
    case builtInPresetIsReadOnly
    case invalidID
    case notFound
}

/// User presets, one JSON file per preset (spec 10.8).
public struct PresetStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Pli/Presets", isDirectory: true)
    }

    /// Every readable preset, sorted by name. Unreadable files, and files whose id is not their name (a copy,
    /// which could not be deleted and would repeat an id), are renamed to `.corrupt`, never deleted.
    public func loadAll() -> [Preset] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var presets: [Preset] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let preset = try? JSONDecoder().decode(Preset.self, from: data),
               Self.isValidID(preset.id), !preset.isBuiltIn,
               file.deletingPathExtension().lastPathComponent == preset.id {
                var clean = preset
                clean.name = Preset.sanitizedName(preset.name)
                presets.append(clean)
            } else {
                setAside(file)
            }
        }
        return presets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func add(name: String, glass: GlassParameters, motion: MotionParameters) throws -> Preset {
        let preset = Preset(id: UUID().uuidString, name: Preset.sanitizedName(name), glass: glass.clamped(), motion: motion.clamped())
        try save(preset)
        return preset
    }

    public func save(_ preset: Preset) throws {
        guard !preset.isBuiltIn else { throw PresetStoreError.builtInPresetIsReadOnly }
        guard Self.isValidID(preset.id) else { throw PresetStoreError.invalidID }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preset).write(to: fileURL(for: preset.id), options: .atomic)
    }

    public func rename(id: String, to name: String) throws -> Preset {
        var preset = try existing(id)
        preset.name = Preset.sanitizedName(name)
        try save(preset)
        return preset
    }

    public func duplicate(_ preset: Preset) throws -> Preset {
        try add(name: Preset.sanitizedName(preset.name + " Copy"), glass: preset.glass, motion: preset.motion)
    }

    public func delete(id: String) throws {
        guard Self.isValidID(id) else { throw PresetStoreError.invalidID }
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { throw PresetStoreError.notFound }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func existing(_ id: String) throws -> Preset {
        guard Self.isValidID(id) else { throw PresetStoreError.invalidID }
        guard let data = try? Data(contentsOf: fileURL(for: id)),
              let preset = try? JSONDecoder().decode(Preset.self, from: data) else { throw PresetStoreError.notFound }
        return preset
    }

    private func fileURL(for id: String) -> URL { directory.appendingPathComponent(id + ".json") }

    private func setAside(_ file: URL) {
        var target = URL(fileURLWithPath: file.path + ".corrupt")
        if FileManager.default.fileExists(atPath: target.path) {
            target = URL(fileURLWithPath: file.path + ".\(Int(Date().timeIntervalSince1970)).corrupt")
        }
        try? FileManager.default.moveItem(at: file, to: target)
    }

    /// Letters, digits and dashes only, so an id can never escape the directory.
    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy { (CharacterSet.alphanumerics.contains($0) || $0 == "-") && $0.isASCII }
    }
}
