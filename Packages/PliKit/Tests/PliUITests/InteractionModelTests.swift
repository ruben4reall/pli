import AppKit
import PliCore
import Testing
@testable import PliUI

@MainActor @Suite struct ShortcutRecorderTests {
    /// What the recorder asked of the app: suspending the global shortcuts, playing the demo (it never should).
    final class Services {
        var suspensions: [Bool] = []
        var calls: [String] = []
    }

    // Key codes: P 0x23, L 0x25, K 0x28, Q 0x0C, Esc 53.
    private func recorder() -> (ShortcutRecorderModel, SettingsEditor, Services) {
        let services = Services()
        let editor = SettingsEditor(settings: .default) { _, _ in }
        let recorder = ShortcutRecorderModel(editor: editor, interpreter: FakeInterpreter()) { services.suspensions.append($0) }
        return (recorder, editor, services)
    }

    @Test func aNewShortcutIsSavedUndoablyAndTheGlobalOnesComeBack() {
        let (recorder, editor, services) = recorder()
        let undo = Fixtures.undoManager()
        recorder.begin(.demo)
        #expect(services.suspensions == [true] && recorder.recording == .demo)
        #expect(recorder.key(keyCode: 0x28, modifiers: [.command, .option], undoManager: undo))
        #expect(editor.settings.triggers.demoShortcut == KeyCombo(keyCode: 0x28, modifiers: KeyCombo.command | KeyCombo.option))
        #expect(recorder.recording == nil && services.suspensions == [true, false])
        #expect(recorder.display(for: .demo) == "⌥⌘K")
        undo.undo()
        #expect(editor.settings.triggers.demoShortcut == .defaultDemo)
    }

    @Test func escKeepsTheCurrentShortcut() {
        let (recorder, editor, services) = recorder()
        recorder.begin(.animatedLock)
        #expect(recorder.key(keyCode: 53, modifiers: [], undoManager: nil))
        #expect(editor.settings.triggers.animatedLockShortcut == .defaultLock && services.suspensions == [true, false])
    }

    @Test func refusedKeysSayWhyAndKeepRecording() {
        let (recorder, _, _) = recorder()
        recorder.begin(.demo)
        #expect(!recorder.key(keyCode: 0x28, modifiers: [], undoManager: nil))
        #expect(recorder.problem == ShortcutProblem(action: .demo, text: "Use ⌘, ⌃ or ⌥ with a key."))
        #expect(!recorder.key(keyCode: 0x0C, modifiers: [.command], undoManager: nil))
        #expect(recorder.problem?.text == "Apps use ⌘ and a letter for their own commands. Add ⌃ or ⌥.")
        #expect(recorder.recording == .demo)
    }

    /// Review Focus: the other action's shortcut is refused with its name, and nothing is saved.
    @Test func theOtherActionsShortcutIsRefused() {
        let (recorder, editor, _) = recorder()
        recorder.begin(.demo)
        #expect(!recorder.key(keyCode: 0x25, modifiers: [.control, .option, .command], undoManager: nil))
        #expect(recorder.problem?.text == "Already used by Animated Lock.")
        #expect(editor.settings.triggers.demoShortcut == .defaultDemo)
    }

    /// Review Focus: typing the current shortcut while recording records it; the global shortcuts are suspended, so
    /// the demo does not play.
    @Test func recordingTheCurrentShortcutKeepsItWithoutPlayingTheDemo() {
        let (recorder, editor, services) = recorder()
        recorder.begin(.demo)
        #expect(recorder.key(keyCode: 0x23, modifiers: [.control, .option, .command], undoManager: nil))
        #expect(editor.settings.triggers.demoShortcut == .defaultDemo)
        #expect(!services.calls.contains("playDemo") && services.suspensions == [true, false])
    }

    @Test func clearingRemovesTheShortcut() {
        let (recorder, editor, _) = recorder()
        recorder.clear(.animatedLock, undoManager: nil)
        #expect(editor.settings.triggers.animatedLockShortcut == nil && recorder.display(for: .animatedLock) == nil)
    }

    @Test func switchingRecordersSuspendsOnce() {
        let (recorder, _, services) = recorder()
        recorder.begin(.demo)
        recorder.begin(.animatedLock)
        recorder.cancel()
        recorder.cancel()
        #expect(services.suspensions == [true, false])
    }
}

@MainActor @Suite struct OnboardingModelTests {
    @Test func getStartedAsksForThePermissionUnlessItIsThere() {
        let onboarding = OnboardingModel()
        onboarding.getStarted(screenCaptureAllowed: false)
        #expect(onboarding.step == .permission)
        onboarding.restart()
        onboarding.getStarted(screenCaptureAllowed: true)
        #expect(onboarding.step == .tryIt)
    }

    @Test func theGrantIsDetectedByItself() {
        let onboarding = OnboardingModel()
        onboarding.getStarted(screenCaptureAllowed: false)
        onboarding.allowRequested()
        #expect(onboarding.waitingForPermission)
        onboarding.permissionChanged(allowed: true)
        #expect(onboarding.step == .tryIt && !onboarding.waitingForPermission)
    }

    @Test func laterMovesOnWithoutThePermission() {
        let onboarding = OnboardingModel()
        onboarding.getStarted(screenCaptureAllowed: false)
        onboarding.later()
        #expect(onboarding.step == .tryIt)
    }

    @Test func aGrantOutsideThePermissionStepChangesNothing() {
        let onboarding = OnboardingModel()
        onboarding.permissionChanged(allowed: true)
        #expect(onboarding.step == .welcome)
    }

    @Test func openAtLoginIsCheckedByDefault() {
        let onboarding = OnboardingModel()
        onboarding.openAtLogin = false
        onboarding.restart()
        #expect(onboarding.openAtLogin)
    }
}

@MainActor @Suite struct WindowRouterTests {
    @Test func pliIsARegularAppWhileAWindowIsOpen() {
        let router = WindowRouter()
        #expect(router.didOpen(.settings) == true)
        #expect(router.didOpen(.onboarding) == nil)
        #expect(router.didClose(.settings) == nil)
        #expect(router.didClose(.onboarding) == false)
        #expect(router.didClose(.onboarding) == nil)
    }

    @Test func everyRequestIsNew() {
        let router = WindowRouter()
        router.open(.settings)
        let first = router.request
        router.open(.settings)
        #expect(router.request != first && router.request?.window == .settings)
        #expect(PliWindow.settings.id == "pli-settings")
    }
}
