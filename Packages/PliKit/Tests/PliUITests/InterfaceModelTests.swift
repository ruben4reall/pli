import Foundation
import PliCore
import Testing
@testable import PliUI

@MainActor @Suite struct InterfaceModelTests {
    @Test func choosingAPresetReachesTheAppAndCanBeUndone() {
        let (interface, services) = Fixtures.interface()
        let undo = Fixtures.undoManager()
        interface.choose(BuiltInPresets.cinema, undoManager: undo)
        #expect(services.applied.last?.settings.activePresetID == "cinema" && services.applied.last?.persist == true)
        #expect(interface.presetState.title == "Cinema")
        undo.undo()
        #expect(interface.settings.activePresetID == "duo" && interface.presetState.title == "Duo")
    }

    @Test func resetRestoresTheActivePresetAndEachGroupAlone() {
        let (interface, _) = Fixtures.interface()
        interface.choose(BuiltInPresets.night, undoManager: nil)
        interface.editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: nil)
        interface.editor.set(\.glass.maxTiltDegrees, to: 70, action: "Max Tilt", undoManager: nil)
        interface.editor.set(\.motion.startAngle, to: 120, action: "Start Angle", undoManager: nil)
        #expect(interface.presetState.title == "Night (Modified)")
        interface.resetGlass(undoManager: nil)
        #expect(interface.settings.glass.frost == BuiltInPresets.night.glass.frost && interface.settings.glass.maxTiltDegrees == 70)
        interface.resetPerspective(undoManager: nil)
        #expect(interface.settings.glass.maxTiltDegrees == BuiltInPresets.night.glass.maxTiltDegrees)
        interface.resetMotion(undoManager: nil)
        #expect(interface.presetState.title == "Night")
        interface.editor.set(\.glass.grain, to: 0.9, action: "Grain", undoManager: nil)
        interface.resetToPreset(undoManager: nil)
        #expect(!interface.presetState.isModified)
    }

    @Test func savingAsAPresetMakesItActive() {
        let (interface, _) = Fixtures.interface()
        interface.editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: nil)
        #expect(interface.saveAsPreset(named: "Mine") == nil)
        #expect(interface.presetState.title == "Mine" && !interface.presetState.preset.isBuiltIn)
    }

    /// Review Focus: deleting the preset in use keeps the look, and the label falls back to Duo.
    @Test func deletingThePresetInUseKeepsTheLook() {
        let (interface, _) = Fixtures.interface()
        interface.editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: nil)
        interface.saveAsPreset(named: "Mine")
        let mine = interface.presetState.preset
        #expect(interface.deletePreset(mine) == nil)
        #expect(interface.settings.glass.frost == 0.2 && interface.presetState.title == "Duo (Modified)")
    }

    @Test func aFailedPresetChangeSaysSoInTheBanner() {
        let (interface, _) = Fixtures.interface()
        let gone = Preset(id: "5B3A6C1E-0000-4000-8000-000000000000", name: "Gone", glass: .duo, motion: .duo)
        #expect(interface.renamePreset(gone, to: "New") == "Pli could not save this preset.")
        #expect(interface.banner == Banner(text: "Pli could not save this preset.", isProblem: true))
    }

    @Test func importingAddsChoosesAndSaysSo() throws {
        let (interface, _) = Fixtures.interface()
        var preset = BuiltInPresets.night
        preset.name = "Evening"
        let url = try Fixtures.pliFile(try PresetFile.encode(preset))
        interface.importPresets(from: [url], undoManager: nil)
        #expect(interface.presets.userPresets.map(\.name) == ["Evening"])
        #expect(interface.presetState.title == "Evening")
        #expect(interface.banner == Banner(text: "Imported “Evening”.", isProblem: false))
    }

    @Test func aBadFileSaysWhatIsWrongAndChangesNothing() throws {
        let (interface, _) = Fixtures.interface()
        interface.importPresets(from: [try Fixtures.pliFile(Data("{nope".utf8))], undoManager: nil)
        #expect(interface.banner == Banner(text: "This preset file is damaged and cannot be opened.", isProblem: true))
        #expect(interface.presets.userPresets.isEmpty && interface.settings.activePresetID == "duo")
    }

    /// Review Focus: a `.pli` double-clicked in Finder, even as it launches Pli, is imported once and shown in Style.
    @Test func openingAPliFileFromFinderShowsItInStyle() throws {
        let (interface, _) = Fixtures.interface()
        let url = try Fixtures.pliFile(try PresetFile.encode(BuiltInPresets.crystal), name: "Glass.pli")
        let other = try Fixtures.pliFile(Data("not a preset".utf8), name: "notes.txt")
        interface.openPresetFiles([url, other])
        #expect(interface.presets.userPresets.count == 1)
        #expect(interface.pane == .look && interface.windows.request?.window == .settings)
    }

    @Test func exportUsesTheNameTheStylePaneShows() {
        let (interface, _) = Fixtures.interface()
        interface.editor.set(\.glass.frost, to: 0.2, action: "Frost", undoManager: nil)
        let document = interface.exportDocument()
        #expect(document.preset.name == "Duo (Modified)" && document.preset.glass.frost == 0.2)
        #expect(interface.exportDocument(for: BuiltInPresets.deepFrost).preset.name == "Deep Frost")
    }

    @Test func settingsMakePliARegularAppAndLoadAPicture() {
        let (interface, services) = Fixtures.interface()
        interface.settingsDidOpen()
        #expect(services.regularApp == [true] && services.pictureRequests.count == 1 && services.calls == ["refresh"])
        services.pictureRequests[0](Fixtures.picture())
        #expect(interface.preview.picture?.kind == .screen)
        interface.settingsDidClose()
        #expect(services.regularApp == [true, false] && interface.preview.picture == nil)
    }

    /// Review Focus: a capture that arrives after Settings closed is dropped, never kept in memory.
    @Test func aLatePictureAfterCloseIsDropped() {
        let (interface, services) = Fixtures.interface()
        interface.settingsDidOpen()
        interface.settingsDidClose()
        services.pictureRequests[0](Fixtures.picture())
        #expect(interface.preview.picture == nil)
    }

    @Test func aGrantWhileSettingsIsOpenSwapsTheWallpaperForTheScreen() {
        let (interface, services) = Fixtures.interface(live: LiveSnapshot(screenCaptureAllowed: false))
        interface.settingsDidOpen()
        services.pictureRequests[0](Fixtures.picture(.wallpaper))
        interface.receive(LiveSnapshot(screenCaptureAllowed: true), at: 1)
        #expect(services.pictureRequests.count == 2)
        services.pictureRequests[1](Fixtures.picture(.screen))
        #expect(interface.preview.picture?.kind == .screen)
    }

    @Test func theGrantMovesOnboardingOn() {
        let (interface, services) = Fixtures.interface(live: LiveSnapshot(screenCaptureAllowed: false))
        interface.onboardingGetStarted()
        interface.onboardingAllow()
        #expect(services.calls == ["requestScreenRecording"] && interface.onboarding.step == .permission)
        interface.panelDidOpen()
        #expect(services.calls.last == "refresh")
        interface.receive(LiveSnapshot(screenCaptureAllowed: true), at: 1)
        #expect(interface.onboarding.step == .tryIt)
    }

    @Test func finishingOnboardingOpensAtLoginAndIsRemembered() {
        let (interface, services) = Fixtures.interface()
        interface.onboardingFinish()
        #expect(services.openAtLogin == .enabled && interface.loginItem == .enabled)
        #expect(interface.settings.general.hasCompletedOnboarding && !interface.showsOnboardingAtLaunch)
    }

    @Test func closingTheWelcomeWindowCountsAsSeen() {
        let (interface, services) = Fixtures.interface()
        interface.onboardingDidOpen()
        interface.onboardingDidClose()
        #expect(interface.settings.general.hasCompletedOnboarding && services.regularApp == [true, false])
        #expect(services.openAtLogin == .disabled)
    }

    @Test func aRefusedLoginItemSaysSo() {
        let (interface, services) = Fixtures.interface()
        services.loginError = CocoaError(.featureUnsupported)
        interface.setOpenAtLogin(true)
        #expect(interface.loginProblem == "macOS did not let Pli open at login." && interface.loginItem == .disabled)
    }

    /// Spec 8.1: with the symbol dragged out of the menu bar, Settings opens; relaunching Pli opens it too.
    @Test func withoutTheMenuBarSymbolSettingsStaysReachable() {
        let (interface, _) = Fixtures.interface()
        interface.menuBarSymbolRemoved()
        #expect(!interface.settings.general.showInMenuBar)
        #expect(interface.windows.request?.window == .settings && interface.pane == .general)
        interface.editor.setQuietly(\.general.hasCompletedOnboarding, to: true)
        let before = interface.windows.request
        interface.reopen()
        #expect(interface.windows.request != before && interface.windows.request?.window == .settings)
    }

    @Test func aFirstLaunchReopenShowsTheWelcome() {
        let (interface, _) = Fixtures.interface()
        interface.reopen()
        #expect(interface.windows.request?.window == .onboarding)
    }

    @Test func basicModeReasons() {
        let (allowed, _) = Fixtures.interface()
        #expect(allowed.basicModeReason == nil)
        let (missing, _) = Fixtures.interface(live: LiveSnapshot(screenCaptureAllowed: false))
        #expect(missing.basicModeReason == .permissionMissing && missing.basicModeReason?.note == "Requires Screen Recording permission")
        var settings = PliSettings.default
        settings.general.rendering = .alwaysBasic
        let (basic, _) = Fixtures.interface(settings: settings)
        #expect(basic.basicModeReason?.note == "Not used in Basic mode")
    }

    @Test func aShortcutMacOSRefusedIsShownUnderItsRecorder() {
        let (interface, _) = Fixtures.interface(live: LiveSnapshot(refusedShortcuts: [.animatedLock]))
        #expect(interface.shortcutProblem(for: .animatedLock) == "Another app already uses this shortcut. Choose another one.")
        #expect(interface.shortcutProblem(for: .demo) == nil)
    }

    @Test func theProtractorMarksFollowTheEditedMotion() {
        let (interface, _) = Fixtures.interface()
        interface.editor.set(\.motion.fullFoldAngle, to: 30, action: "Fully Frosted At", undoManager: nil)
        #expect(interface.protractorMarks == ProtractorMarks(rest: 110, start: 90, fullyFrosted: 30))
    }
}
