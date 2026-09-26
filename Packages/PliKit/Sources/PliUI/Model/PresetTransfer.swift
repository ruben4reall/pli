import Foundation
import PliCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// `.pli` files (spec 10.8), declared as an exported type in the app's Info.plist.
    public static let pliPreset = UTType(exportedAs: PresetFile.typeIdentifier, conformingTo: .json)
}

/// Reads `.pli` files and says what went wrong in words a person understands (spec 10.8).
public enum PresetTransfer {
    public enum Failure: Error, Equatable {
        case tooLarge
        case notAPreset
        case damaged
        case newerVersion
        case unreadable
    }

    /// Reads, validates, sanitizes and clamps a file. A file over 64 KB is refused before it is read.
    public static func read(from url: URL) throws -> Preset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size <= PresetFile.maxBytes else { throw Failure.tooLarge }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw Failure.unreadable
        }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> Preset {
        do {
            return try PresetFile.decode(data)
        } catch let error as PresetFileError {
            switch error {
            case .tooLarge: throw Failure.tooLarge
            case .invalidJSON: throw Failure.damaged
            case .notAPliPreset: throw Failure.notAPreset
            case .unsupportedVersion(let version): throw version > PresetFile.version ? Failure.newerVersion : Failure.damaged
            }
        } catch {
            throw Failure.damaged
        }
    }

    /// One sentence for any error of an import, an export or a preset change.
    public static func message(for error: Error) -> String {
        switch error {
        case Failure.tooLarge: Strings.importTooLarge
        case Failure.notAPreset: Strings.importNotAPreset
        case Failure.damaged: Strings.importDamaged
        case Failure.newerVersion: Strings.importNewerVersion
        case Failure.unreadable: Strings.importUnreadable
        case is PresetStoreError: Strings.presetSaveFailed
        default: Strings.presetSaveFailed
        }
    }

    /// A file name for an export: the preset's name without the characters macOS keeps out of file names.
    public static func fileName(for name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return trimmed.isEmpty ? Strings.presetFileType : trimmed
    }
}

/// A preset as a document for the Export… save panel.
public struct PresetDocument: FileDocument {
    public static let readableContentTypes: [UTType] = [.pliPreset]

    public var preset: Preset

    public init(preset: Preset) {
        self.preset = preset
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw PresetTransfer.Failure.unreadable }
        preset = try PresetTransfer.decode(data)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PresetFile.encode(preset))
    }
}
