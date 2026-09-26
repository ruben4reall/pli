import Foundation
import PliCore
import Testing
import UniformTypeIdentifiers
@testable import PliUI

@MainActor @Suite struct PresetTransferTests {
    @Test func aFileRoundTrips() throws {
        let url = try Fixtures.pliFile(try PresetFile.encode(BuiltInPresets.prism))
        let preset = try PresetTransfer.read(from: url)
        #expect(preset.name == "Prism" && preset.glass == BuiltInPresets.prism.glass && preset.motion == BuiltInPresets.prism.motion)
        #expect(!preset.isBuiltIn)
    }

    @Test func errorsBecomeSentences() throws {
        let cases: [(Data, String)] = [
            (Data("hello".utf8), "This preset file is damaged and cannot be opened."),
            (Data(#"{"format":"other","version":1}"#.utf8), "This file is not a Pli preset."),
            (Data(#"{"format":"pli-preset","version":2}"#.utf8), "This preset was made by a newer version of Pli. Update Pli to open it."),
            (Data(#"{"format":"pli-preset","version":0}"#.utf8), "This preset file is damaged and cannot be opened."),
            (Data(#"{"format":5,"version":1}"#.utf8), "This file is not a Pli preset."),   // wrong-typed header: PresetFileError.notAPliPreset
        ]
        for (data, message) in cases {
            let url = try Fixtures.pliFile(data)
            #expect(throws: PresetTransfer.Failure.self) { try PresetTransfer.read(from: url) }
            do {
                _ = try PresetTransfer.read(from: url)
            } catch {
                #expect(PresetTransfer.message(for: error) == message)
            }
        }
    }

    @Test func aFileOver64KBIsRefusedBeforeItIsRead() throws {
        let url = try Fixtures.pliFile(Data(count: PresetFile.maxBytes + 1))
        #expect(throws: PresetTransfer.Failure.tooLarge) { try PresetTransfer.read(from: url) }
        #expect(PresetTransfer.message(for: PresetTransfer.Failure.tooLarge) == "This file is larger than 64 KB, so it is not a Pli preset.")
    }

    @Test func aMissingFileIsUnreadable() {
        let url = TestPaths.temporaryDirectory("missing").appendingPathComponent("Gone.pli")
        #expect(throws: PresetTransfer.Failure.unreadable) { try PresetTransfer.read(from: url) }
    }

    @Test func aStrangersValuesAreClampedAndTheNameCleaned() throws {
        let wild = #"{"format":"pli-preset","version":1,"name":"A\nB","glass":{"frost":99},"motion":{"startAngle":1000}}"#
        let preset = try PresetTransfer.read(from: try Fixtures.pliFile(Data(wild.utf8)))
        #expect(preset.name == "A B" && preset.glass.frost == 0.25 && preset.motion.startAngle == 130)
    }

    @Test func storeErrorsReadAsASaveFailure() {
        #expect(PresetTransfer.message(for: PresetStoreError.invalidID) == "Pli could not save this preset.")
    }

    @Test func exportFileNamesAvoidSlashesAndColons() {
        #expect(PresetTransfer.fileName(for: "Night / Day: 2") == "Night - Day- 2")
        #expect(PresetTransfer.fileName(for: " ..") == "Pli Preset")
    }

    @Test func theDocumentWritesAPliFile() throws {
        let document = PresetDocument(preset: BuiltInPresets.crystal)
        #expect(PresetDocument.readableContentTypes == [.pliPreset])
        #expect(UTType.pliPreset.identifier == "ch.rubencatalao.pli.preset")
        let data = try PresetFile.encode(document.preset)
        #expect(try PresetFile.decode(data).glass == BuiltInPresets.crystal.glass)
    }
}
