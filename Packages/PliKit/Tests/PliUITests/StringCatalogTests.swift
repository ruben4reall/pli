import Foundation
import Testing
@testable import PliUI

@Suite struct StringCatalogTests {
    static let stringsFile = TestPaths.packageRoot.appendingPathComponent("Sources/PliUI/Design/Strings.swift")
    static let catalogFile = TestPaths.packageRoot.appendingPathComponent("Sources/PliUI/Resources/Localizable.xcstrings")

    /// Every `String(localized: "…"` key of Strings.swift.
    static func codeKeys() throws -> Set<String> {
        let text = try String(contentsOf: stringsFile, encoding: .utf8)
        return Set(text.matches(of: /String\(localized: "((?:[^"\\]|\\.)*)"/).map {
            String($0.output.1).replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
        })
    }

    static func catalog() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: catalogFile)) as? [String: Any] ?? [:]
    }

    static func catalogKeys() throws -> Set<String> {
        Set((try catalog()["strings"] as? [String: Any] ?? [:]).keys)
    }

    @Test func thereAreStrings() throws {
        #expect(try Self.codeKeys().count > 200)
    }

    @Test func everyStringIsInTheCatalog() throws {
        let missing = try Self.codeKeys().subtracting(Self.catalogKeys())
        #expect(missing.isEmpty, "add to Localizable.xcstrings: \(missing.sorted())")
    }

    @Test func theCatalogHasNoStaleKeys() throws {
        let stale = try Self.catalogKeys().subtracting(Self.codeKeys())
        #expect(stale.isEmpty, "remove from Localizable.xcstrings: \(stale.sorted())")
    }

    @Test func theSourceLanguageIsEnglish() throws {
        #expect(try Self.catalog()["sourceLanguage"] as? String == "en")
    }

    @Test func noVisibleStringHasAnEmDash() throws {
        for key in try Self.codeKeys() {
            #expect(!key.contains("\u{2014}"), "em dash in \(key)")
        }
    }

    /// A literal % outside a format specifier would be read as one by `String(format:)`.
    @Test func percentSignsAreFormatSpecifiersOnly() throws {
        for key in try Self.codeKeys() {
            let stripped = key.replacingOccurrences(of: "%lld", with: "").replacingOccurrences(of: "%@", with: "")
            #expect(!stripped.contains("%"), "stray % in \(key)")
        }
    }

    @Test func formatStringsFillIn() {
        #expect(Strings.statusActive(lidAt: 104) == "Active · lid at 104°")
        #expect(Strings.modifiedPreset("Duo") == "Duo (Modified)")
        #expect(Strings.millimeters("450") == "450 mm")
        #expect(Strings.stepOf(2, 3) == "Step 2 of 3")
    }

    /// Views take their words from Strings, never from a literal, so the catalog stays complete.
    @Test func viewsTakeTheirWordsFromStrings() {
        let forbidden = /(\b(Text|Button|Label|Toggle|Section|Picker|LabeledContent|Link|Menu|Stepper|Slider|ColorPicker|TextField|Window|MenuBarExtra|GroupBox)\(\s*"|\.(help|navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|confirmationDialog|alert)\(\s*")/
        let files = TestPaths.sources(in: "Sources/PliUI").filter { !$0.path.hasSuffix("/Design/Strings.swift") }
        #expect(!files.isEmpty)
        for file in files {
            #expect(file.text.firstMatch(of: forbidden) == nil, "\(file.path) writes a user-facing literal: add it to Strings.swift")
        }
    }
}
