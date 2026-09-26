import Foundation
import Testing
@testable import PliCore

@Suite struct PresetTests {
    @Test func builtInsMatchSpecTable() {
        #expect(BuiltInPresets.all.map(\.id) == ["duo", "subtle", "deepFrost", "night", "crystal", "prism", "cinema"])
        #expect(BuiltInPresets.all.map(\.name) == ["Duo", "Subtle", "Deep Frost", "Night", "Crystal", "Prism", "Cinema"])
        #expect(BuiltInPresets.duo.glass == .duo && BuiltInPresets.duo.motion == .duo)
        let subtle = BuiltInPresets.subtle
        #expect(subtle.glass.frost == 0.05 && subtle.glass.spatialAnchor == 0.7 && subtle.glass.maxTiltDegrees == 35)
        #expect(subtle.motion.startAngle == 85 && subtle.motion.deadZoneDegrees == 8 && subtle.motion.curve == .smooth)
        let night = BuiltInPresets.night
        #expect(night.glass.tintColor == .night && night.glass.tintAmount == 0.35 && night.motion.curve == .fastStart)
        let cinema = BuiltInPresets.cinema
        #expect(cinema.glass.maxTiltDegrees == 65 && cinema.motion.startAngle == 100 && cinema.motion.fullFoldAngle == 28)
        #expect(BuiltInPresets.crystal.glass.edgeSheen == 0.6 && BuiltInPresets.prism.glass.prism == 0.55)
        #expect(BuiltInPresets.deepFrost.glass.grain == 0.7 && BuiltInPresets.deepFrost.motion.fullFoldAngle == 25)
    }

    @Test func builtInsAreWithinRanges() {
        for preset in BuiltInPresets.all {
            #expect(preset.glass.clamped() == preset.glass, "\(preset.id) glass out of range")
            #expect(preset.motion.clamped() == preset.motion, "\(preset.id) motion out of range")
        }
    }

    @Test func namesAreSanitized() {
        #expect(Preset.sanitizedName("  Soft\nGlass\t ") == "Soft Glass")
        #expect(Preset.sanitizedName("\u{0007}Bell") == "Bell")
        #expect(Preset.sanitizedName("   ") == "Untitled")
        #expect(Preset.sanitizedName(String(repeating: "é", count: 200)).count == 60)
    }

    @Test func namesStaySmallWhateverTheyCarry() {
        // 60 letters carrying 31,020 combining marks: at most 4 marks per character, 256 UTF-16 units in all.
        let tower = String(repeating: "a" + String(repeating: "\u{0301}", count: 517), count: 60)
        let name = Preset.sanitizedName(tower)
        #expect(name.count <= Preset.maxNameLength)
        #expect(name.utf16.count <= Preset.maxNameUTF16Length)
        #expect(name.allSatisfy { $0.unicodeScalars.filter { $0.properties.generalCategory == .nonspacingMark }.count <= Preset.maxMarksPerCharacter })
        #expect(name.first == Character("a\u{0301}\u{0301}\u{0301}\u{0301}"))
        // Emoji sequences keep their joiners; bidi overrides and a lone joiner still go.
        let family = "Family \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        #expect(Preset.sanitizedName(family) == family)
        #expect(Preset.sanitizedName("a\u{202E}b") == "ab")
        #expect(Preset.sanitizedName("\u{200D}") == "Untitled")
    }

    private func tempStore() -> PresetStore {
        PresetStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("pli-presets-\(UUID().uuidString)"))
    }

    @Test func storeAddsRenamesDuplicatesAndDeletes() throws {
        let store = tempStore()
        #expect(store.loadAll().isEmpty)
        let mine = try store.add(name: "Mine", glass: .duo, motion: .duo)
        #expect(!mine.isBuiltIn)
        #expect(store.loadAll() == [mine])
        let renamed = try store.rename(id: mine.id, to: "  Zed ")
        #expect(renamed.name == "Zed")
        let copy = try store.duplicate(renamed)
        #expect(copy.name == "Zed Copy" && copy.id != renamed.id)
        #expect(store.loadAll().map(\.name) == ["Zed", "Zed Copy"])
        try store.delete(id: renamed.id)
        #expect(store.loadAll() == [copy])
        #expect(throws: PresetStoreError.notFound) { try store.delete(id: renamed.id) }
    }

    @Test func storeRefusesBuiltInsAndBadIDs() throws {
        let store = tempStore()
        #expect(throws: PresetStoreError.builtInPresetIsReadOnly) { try store.save(BuiltInPresets.duo) }
        let evil = Preset(id: "../escape", name: "Evil", glass: .duo, motion: .duo)
        #expect(throws: PresetStoreError.invalidID) { try store.save(evil) }
    }

    @Test func corruptFilesAreSetAsideNotDeleted() throws {
        let store = tempStore()
        let good = try store.add(name: "Good", glass: .duo, motion: .duo)
        let bad = store.directory.appendingPathComponent("broken.json")
        try Data("{nope".utf8).write(to: bad)
        #expect(store.loadAll() == [good])
        #expect(!FileManager.default.fileExists(atPath: bad.path))
        #expect(FileManager.default.fileExists(atPath: bad.path + ".corrupt"))
    }

    @Test func aFileWhoseIDIsNotItsNameIsSetAside() throws {
        let store = tempStore()
        let mine = try store.add(name: "Mine", glass: .duo, motion: .duo)
        let original = store.directory.appendingPathComponent(mine.id + ".json")
        let copy = store.directory.appendingPathComponent("\(mine.id) copy.json")   // copied in the Finder
        try FileManager.default.copyItem(at: original, to: copy)
        #expect(store.loadAll() == [mine])
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(FileManager.default.fileExists(atPath: copy.path + ".corrupt"))
        for preset in store.loadAll() { try store.delete(id: preset.id) }   // every listed preset can be deleted
        #expect(store.loadAll().isEmpty)
    }

    @Test func pliFilesRoundTripWithAFreshID() throws {
        let data = try PresetFile.encode(BuiltInPresets.night)
        let imported = try PresetFile.decode(data)
        #expect(imported.name == "Night")
        #expect(imported.glass == BuiltInPresets.night.glass && imported.motion == BuiltInPresets.night.motion)
        #expect(imported.id != "night" && UUID(uuidString: imported.id) != nil)
    }

    @Test func strangersFilesAreValidated() throws {
        #expect(throws: PresetFileError.invalidJSON) { try PresetFile.decode(Data("hello".utf8)) }
        #expect(throws: PresetFileError.notAPliPreset) { try PresetFile.decode(Data(#"{"format":"other","version":1}"#.utf8)) }
        #expect(throws: PresetFileError.unsupportedVersion(2)) { try PresetFile.decode(Data(#"{"format":"pli-preset","version":2}"#.utf8)) }
        #expect(throws: PresetFileError.tooLarge) { try PresetFile.decode(Data(count: PresetFile.maxBytes + 1)) }
        // Wrong-typed header fields: a typed error, never a raw DecodingError.
        #expect(throws: PresetFileError.notAPliPreset) { try PresetFile.decode(Data(#"{"format":5,"version":1}"#.utf8)) }
        #expect(throws: PresetFileError.notAPliPreset) { try PresetFile.decode(Data(#"{"format":["pli-preset"],"version":1}"#.utf8)) }
        #expect(throws: PresetFileError.unsupportedVersion(0)) { try PresetFile.decode(Data(#"{"format":"pli-preset","version":"1"}"#.utf8)) }
        #expect(throws: PresetFileError.unsupportedVersion(0)) { try PresetFile.decode(Data(#"{"format":"pli-preset","version":1.5}"#.utf8)) }
        #expect(throws: PresetFileError.unsupportedVersion(0)) { try PresetFile.decode(Data(#"{"format":"pli-preset","version":99999999999999999999}"#.utf8)) }
        let wild = #"{"format":"pli-preset","version":1,"name":"A\nB\u0000C","glass":{"frost":99,"maxTiltDegrees":-5},"motion":{"startAngle":1000}}"#
        let p = try PresetFile.decode(Data(wild.utf8))
        #expect(p.name == "A BC")   // the newline becomes a space, the NUL is dropped
        #expect(p.glass.frost == 0.25 && p.glass.maxTiltDegrees == 20 && p.motion.startAngle == 130)
    }
}
