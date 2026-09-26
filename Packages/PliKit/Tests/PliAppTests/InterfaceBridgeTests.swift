import AppKit
import Carbon.HIToolbox
import CoreGraphics
import PliCore
import PliUI
import Testing
@testable import PliApp
@testable import PliSystem

@MainActor @Suite struct RuntimeObservationTests {
    final class Counter {
        var count = 0
    }

    @Test func aLidChangeAtRestIsAnnounced() {
        let h = RuntimeHarness()
        let counter = Counter()
        h.runtime.onStateChange = { counter.count += 1 }
        h.setLid(104)
        #expect(counter.count >= 1)
        #expect(h.runtime.lidAngle == 104)
    }

    @Test func nothingIsAnnouncedWhileNothingHappens() {
        let h = RuntimeHarness()
        let counter = Counter()
        h.runtime.onStateChange = { counter.count += 1 }
        h.run(for: 2)
        #expect(counter.count == 0)
    }

    @Test func aGestureIsAnnouncedFrameByFrame() {
        let h = RuntimeHarness()
        let counter = Counter()
        h.runtime.onStateChange = { counter.count += 1 }
        h.moveLid(to: 40, over: 0.5)
        #expect(counter.count > 30)
    }

    @Test func aPermissionChangeIsAnnounced() {
        let h = RuntimeHarness()
        let counter = Counter()
        h.runtime.onStateChange = { counter.count += 1 }
        h.environment.value.screenCaptureAllowed = false
        h.runtime.handle(.appActivated)
        #expect(counter.count >= 1)
        #expect(!h.runtime.environment.screenCaptureAllowed)
    }
}

@Suite struct LiveSnapshotBuilderTests {
    @Test func aMacBookShowsItsPanelAndLid() {
        let snapshot = LiveSnapshotBuilder.make(environment: .macBook, sensorAvailable: true, lidAngle: 104, rest: 110,
                                                cursorHidingAvailable: true, permissionRequested: false, refused: [.lock])
        #expect(snapshot.lidAngle == 104 && snapshot.restAngle == 110 && !snapshot.paused)
        #expect(abs(snapshot.displayWidthMM - 301.2) < 1e-6)
        #expect(abs(snapshot.displayAspectRatio - 1512.0 / 982.0) < 1e-6)
        #expect(snapshot.refusedShortcuts == [.animatedLock])
    }

    @Test func aClosedMacBookIsPausedAndPreviewsTheExternalDisplay() {
        var external = DisplayDescription.studioDisplay
        external.isMain = true
        let environment = RuntimeEnvironment(displays: [external], isLaptop: true)
        let snapshot = LiveSnapshotBuilder.make(environment: environment, sensorAvailable: true, lidAngle: 5, rest: 110,
                                                cursorHidingAvailable: true, permissionRequested: false, refused: [])
        #expect(snapshot.paused)
        #expect(LiveSnapshotBuilder.previewDisplay(in: environment)?.id == 7)
        #expect(abs(snapshot.displayWidthMM - 597) < 1e-6)
    }

    @Test func withoutASensorThereIsNoAngle() {
        let snapshot = LiveSnapshotBuilder.make(environment: .macBook, sensorAvailable: false, lidAngle: 104, rest: 110,
                                                cursorHidingAvailable: false, permissionRequested: true, refused: [])
        #expect(snapshot.lidAngle == nil && snapshot.restAngle == nil && !snapshot.sensorAvailable)
        #expect(!snapshot.cursorHidingAvailable && snapshot.permissionRequested)
    }

    @Test func noDisplayFallsBackToATypicalPanel() {
        let snapshot = LiveSnapshotBuilder.make(environment: RuntimeEnvironment(displays: [], isLaptop: false), sensorAvailable: false,
                                                lidAngle: nil, rest: nil, cursorHidingAvailable: true, permissionRequested: false, refused: [])
        #expect(snapshot.displayWidthMM == PreviewPicture.fallbackWidthMM && snapshot.paused)
    }

    @Test func loginItemStatusesMapToTheInterface() {
        #expect(LoginItemState(LoginItemStatus.enabled) == .enabled)
        #expect(LoginItemState(LoginItemStatus.disabled) == .disabled)
        #expect(LoginItemState(LoginItemStatus.needsApproval) == .needsApproval)
        #expect(LoginItemState(LoginItemStatus.unavailable) == .unavailable)
    }
}

@MainActor @Suite struct SystemShortcutInterpreterTests {
    @Test func theRecordingRulesAreTheSystemsOwn() {
        let interpreter = SystemShortcutInterpreter()
        #expect(interpreter.interpret(keyCode: 35, modifiers: [.control, .option, .command]) == .combo(.defaultDemo))
        #expect(interpreter.interpret(keyCode: 53, modifiers: []) == .cancel)
        #expect(interpreter.interpret(keyCode: 40, modifiers: []) == .needsModifier)
        #expect(interpreter.interpret(keyCode: 12, modifiers: [.command]) == .appCommand)
    }

    @Test func namedKeysReadTheSameOnEveryLayout() {
        let interpreter = SystemShortcutInterpreter()
        #expect(interpreter.display(KeyCombo(keyCode: UInt32(kVK_Space), modifiers: KeyCombo.control)) == "⌃Space")
        #expect(KeyboardLayout.character(for: UInt32(kVK_Space)) == nil)
    }

    @Test func aLetterShowsWhatTheLayoutTypes() {
        let shown = SystemShortcutInterpreter().display(.defaultDemo)
        #expect(shown.hasPrefix("⌃⌥⌘"))
        let key = shown.dropFirst(3)
        #expect(key.count == 1 && key == key.uppercased())
    }
}
