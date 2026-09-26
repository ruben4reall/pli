import Foundation
import PliCore
import Testing
@testable import PliUI

@MainActor @Suite struct SettingsEditorTests {
    final class Commits {
        var log: [(settings: PliSettings, persist: Bool)] = []
    }

    final class Clock {
        var now = 0.0
    }

    private func editor(_ commits: Commits = Commits(), clock: Clock = Clock()) -> SettingsEditor {
        SettingsEditor(settings: .default, clock: { clock.now }) { settings, persist in commits.log.append((settings, persist)) }
    }

    @Test func aChangeIsAppliedSavedAndUndoable() {
        let commits = Commits(), undo = Fixtures.undoManager()
        let editor = editor(commits)
        editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: undo)
        #expect(editor.settings.glass.frost == 0.2)
        #expect(commits.log.last?.persist == true)
        #expect(undo.undoActionName == "Frost")
        undo.undo()
        #expect(editor.settings.glass.frost == 0.09)
        #expect(commits.log.last?.settings.glass.frost == 0.09)
        undo.redo()
        #expect(editor.settings.glass.frost == 0.2)
    }

    @Test func eachChangeIsItsOwnStep() {
        let undo = Fixtures.undoManager()
        let editor = editor()
        editor.set(\.glass.frost, to: 0.1, action: "Frost", undoManager: undo)
        editor.set(\.glass.grain, to: 0.5, action: "Grain", undoManager: undo)
        undo.undo()
        #expect(editor.settings.glass.grain == 0.3 && editor.settings.glass.frost == 0.1)
        undo.undo()
        #expect(editor.settings.glass.frost == 0.09)
    }

    @Test func settingTheSameValueDoesNothing() {
        let commits = Commits(), undo = Fixtures.undoManager()
        let editor = editor(commits)
        editor.set(\.glass.frost, to: 0.09, action: "Frost", undoManager: undo)
        #expect(commits.log.isEmpty && !undo.canUndo)
    }

    @Test func aDragIsOneUndoStepSavedOnce() {
        let commits = Commits(), undo = Fixtures.undoManager()
        let editor = editor(commits)
        editor.beginContinuous(\.glass.frost)
        for value in [0.1, 0.12, 0.15, 0.18] { editor.slide(\.glass.frost, to: value, action: "Frost", undoManager: undo) }
        #expect(commits.log.count == 4 && commits.log.allSatisfy { !$0.persist })
        editor.endContinuous(action: "Frost", undoManager: undo)
        #expect(commits.log.last?.persist == true && commits.log.count == 5)
        #expect(undo.undoCount == 1)
        undo.undo()
        #expect(editor.settings.glass.frost == 0.09)
    }

    @Test func aDragThatEndsWhereItStartedLeavesNoStep() {
        let undo = Fixtures.undoManager()
        let editor = editor()
        editor.beginContinuous(\.glass.frost)
        editor.slide(\.glass.frost, to: 0.2, action: "Frost", undoManager: undo)
        editor.slide(\.glass.frost, to: 0.09, action: "Frost", undoManager: undo)
        editor.endContinuous(action: "Frost", undoManager: undo)
        #expect(!undo.canUndo)
    }

    /// Review Focus: a slider moved with the arrow keys has no drag, and must still be undoable, in one step per burst.
    @Test func keyboardSliderChangesCoalesceIntoOneStep() {
        let undo = Fixtures.undoManager(), clock = Clock()
        let editor = editor(clock: clock)
        for (time, value) in [(0.0, 0.1), (0.2, 0.11), (0.4, 0.12)] {
            clock.now = time
            editor.slide(\.glass.frost, to: value, action: "Frost", undoManager: undo)
        }
        clock.now = 5
        editor.slide(\.glass.frost, to: 0.2, action: "Frost", undoManager: undo)
        #expect(undo.undoCount == 2)
        undo.undo()
        #expect(editor.settings.glass.frost == 0.12)
        undo.undo()
        #expect(editor.settings.glass.frost == 0.09)
    }

    @Test func undoRestoresOneSettingAndLeavesOtherChangesAlone() {
        let undo = Fixtures.undoManager()
        let editor = editor()
        editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: undo)
        editor.setQuietly(\.general.enabled, to: false)
        undo.undo()
        #expect(editor.settings.glass.frost == 0.09)
        #expect(!editor.settings.general.enabled)
    }

    @Test func quietChangesAreSavedButNotUndoable() {
        let commits = Commits(), undo = Fixtures.undoManager()
        let editor = editor(commits)
        editor.setQuietly(\.general.hasCompletedOnboarding, to: true)
        #expect(editor.settings.general.hasCompletedOnboarding && commits.log.last?.persist == true && !undo.canUndo)
    }

    @Test func outOfRangeValuesAreClampedBeforeTheyReachTheApp() {
        let commits = Commits()
        let editor = editor(commits)
        editor.set(\.glass.frost, to: 9, action: "Frost", undoManager: nil)
        #expect(editor.settings.glass.frost == 0.25)
        #expect(commits.log.last?.settings.glass.frost == 0.25)
    }

    @Test func aLookIsOneValue() {
        let undo = Fixtures.undoManager()
        let editor = editor()
        editor.set(\.look, to: Look(preset: BuiltInPresets.night), action: "Choose Preset", undoManager: undo)
        #expect(editor.settings.activePresetID == "night" && editor.settings.glass == BuiltInPresets.night.glass)
        undo.undo()
        #expect(editor.settings.activePresetID == "duo" && editor.settings.motion == .duo)
    }

    @Test func groupResetsTouchOnlyTheirGroup() {
        var edited = GlassParameters.duo
        edited.frost = 0.2
        edited.eyeDistanceMM = 800
        let glassReset = edited.withGlassGroup(of: .duo)
        #expect(glassReset.frost == 0.09 && glassReset.eyeDistanceMM == 800)
        let perspectiveReset = edited.withPerspectiveGroup(of: .duo)
        #expect(perspectiveReset.frost == 0.2 && perspectiveReset.eyeDistanceMM == 450)
    }
}
