import Foundation

public enum PresetFileError: Error, Equatable {
    case tooLarge
    case invalidJSON
    case notAPliPreset
    case unsupportedVersion(Int)
}

/// The shareable `.pli` file (spec 10.8).
public enum PresetFile {
    public static let format = "pli-preset"
    public static let version = 1
    public static let maxBytes = 65_536
    public static let fileExtension = "pli"
    public static let typeIdentifier = "ch.rubencatalao.pli.preset"

    private struct Envelope: Codable {
        var format: String
        var version: Int
        var name: String
        var glass: GlassParameters
        var motion: MotionParameters
    }

    /// Wrong-typed fields read as missing, so a stranger's file always ends in a `PresetFileError`.
    private struct Header: Decodable {
        var format: String?
        var version: Int?

        enum CodingKeys: String, CodingKey { case format, version }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            format = try? c.decodeIfPresent(String.self, forKey: .format)
            version = try? c.decodeIfPresent(Int.self, forKey: .version)
        }
    }

    public static func encode(_ preset: Preset) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(format: format, version: version, name: preset.name, glass: preset.glass, motion: preset.motion))
    }

    /// Validates, sanitizes and clamps a file, and gives it a fresh id.
    public static func decode(_ data: Data) throws -> Preset {
        guard data.count <= maxBytes else { throw PresetFileError.tooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data), object is [String: Any] else {
            throw PresetFileError.invalidJSON
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw PresetFileError.invalidJSON }
        guard header.format == format else { throw PresetFileError.notAPliPreset }
        let fileVersion = header.version ?? 0
        guard fileVersion <= version, fileVersion >= 1 else { throw PresetFileError.unsupportedVersion(fileVersion) }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else { throw PresetFileError.invalidJSON }
        return Preset(id: UUID().uuidString, name: Preset.sanitizedName(body.name ?? "Untitled"), glass: body.glass, motion: body.motion)
    }

    /// Tolerant body: missing groups take Duo's values, and the groups clamp themselves.
    private struct Body: Decodable {
        var name: String?
        var glass: GlassParameters
        var motion: MotionParameters

        enum CodingKeys: String, CodingKey { case name, glass, motion }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil
            glass = c.value(.glass, default: .duo)
            motion = c.value(.motion, default: .duo)
        }
    }
}
