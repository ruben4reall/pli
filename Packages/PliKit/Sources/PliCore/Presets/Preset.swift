import Foundation

/// A named look: the Glass, Perspective and Motion groups (spec 7.5).
public struct Preset: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var glass: GlassParameters
    public var motion: MotionParameters

    public static let maxNameLength = 60
    /// Combining marks kept on one character: enough for any script, too few to stack a name into a tower.
    public static let maxMarksPerCharacter = 4
    /// A bound on a name's size whatever its characters.
    public static let maxNameUTF16Length = 256

    public init(id: String, name: String, glass: GlassParameters, motion: MotionParameters) {
        self.id = id
        self.name = name
        self.glass = glass
        self.motion = motion
    }

    public var isBuiltIn: Bool { BuiltInPresets.isBuiltIn(id: id) }

    public func matches(glass: GlassParameters, motion: MotionParameters) -> Bool {
        self.glass == glass && self.motion == motion
    }

    /// One line, no control or format characters (but the joiner of emoji sequences), single spaces, at most
    /// 60 characters of at most 4 combining marks each and 256 UTF-16 code units in all, never empty.
    public static func sanitizedName(_ raw: String) -> String {
        let spaced = raw.unicodeScalars.map { scalar -> String in
            if CharacterSet.newlines.contains(scalar) || scalar == "\t" { return " " }
            if scalar == zeroWidthJoiner { return String(scalar) }
            if CharacterSet.controlCharacters.contains(scalar) { return "" }
            return String(scalar)
        }.joined()
        let collapsed = spaced.split(whereSeparator: { $0 == " " }).joined(separator: " ")
        var name = ""
        var units = 0
        for character in collapsed.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength) {
            guard let kept = limitingMarks(character) else { continue }
            let size = kept.utf16.count
            guard units + size <= maxNameUTF16Length else { break }
            name += kept
            units += size
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private static let zeroWidthJoiner: Unicode.Scalar = "\u{200D}"

    /// The character with its first `maxMarksPerCharacter` combining marks, or nil if only joiners are left.
    private static func limitingMarks(_ character: Character) -> String? {
        var marks = 0
        var kept = String.UnicodeScalarView()
        for scalar in character.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .enclosingMark:
                marks += 1
                if marks > maxMarksPerCharacter { continue }
            default:
                break
            }
            kept.append(scalar)
        }
        guard kept.contains(where: { $0 != zeroWidthJoiner }) else { return nil }
        return String(kept)
    }
}
