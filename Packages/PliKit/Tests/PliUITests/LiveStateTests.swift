import AppKit
import Observation
import PliCore
import Synchronization
import Testing
@testable import PliUI

@MainActor @Suite struct LiveStateTests {
    @Test func onlyWhatChangedIsTouched() {
        let live = LiveState(LiveSnapshot(lidAngle: 104, restAngle: 110))
        let angleFired = Mutex(false), permissionFired = Mutex(false)
        withObservationTracking { _ = live.lidAngle } onChange: { angleFired.withLock { $0 = true } }
        withObservationTracking { _ = live.screenCaptureAllowed } onChange: { permissionFired.withLock { $0 = true } }
        live.apply(LiveSnapshot(lidAngle: 104, restAngle: 110), at: 0)
        #expect(!angleFired.withLock { $0 } && !permissionFired.withLock { $0 })
        live.apply(LiveSnapshot(lidAngle: 103, restAngle: 110), at: 1)
        #expect(angleFired.withLock { $0 } && !permissionFired.withLock { $0 })
        #expect(live.snapshot == LiveSnapshot(lidAngle: 103, restAngle: 110))
    }
}

@Suite struct PanelStatusTests {
    private func status(_ change: (inout PliSettings, inout LiveSnapshot) -> Void = { _, _ in }) -> PanelStatus {
        var settings = PliSettings.default
        var live = LiveSnapshot(lidAngle: 104, restAngle: 110)
        change(&settings, &live)
        return PanelStatus.make(settings: settings, live: live)
    }

    @Test func theStatusLineSaysWhatPliIsDoing() {
        #expect(status().text == "Active · lid at 104°")
        #expect(status { _, live in live.lidAngle = nil }.text == "Active")
        #expect(status { settings, _ in settings.general.enabled = false }.text == "Paused")
        #expect(status { _, live in live.paused = true }.text == "Paused")
        #expect(status { _, live in live.sensorAvailable = false }.text == "No lid sensor")
        #expect(status { _, live in live.screenCaptureAllowed = false }.text == "Permission needed")
        #expect(status { settings, live in live.screenCaptureAllowed = false; settings.general.rendering = .alwaysBasic }.text == "Active · lid at 104°")
    }

    @Test func actionsFollowTheSettingsAndTheMac() {
        #expect(status().canPlayDemo && status().canLock)
        let off = status { settings, _ in settings.general.enabled = false }
        #expect(!off.canPlayDemo && !off.canLock)
        let paused = status { _, live in live.paused = true }
        #expect(!paused.canPlayDemo && paused.canLock)
        let noLock = status { settings, live in live.canLockNow = false; settings.triggers.demoEnabled = false }
        #expect(!noLock.canLock && !noLock.canPlayDemo)
    }

    @Test func permissionActionsAppearOnlyWhenTheyHelp() {
        let missing = status { _, live in live.screenCaptureAllowed = false }
        #expect(missing.needsPermission && !missing.offerRelaunch)
        let asked = status { _, live in live.screenCaptureAllowed = false; live.permissionRequested = true }
        #expect(asked.offerRelaunch)
        let basic = status { settings, live in live.screenCaptureAllowed = false; settings.general.rendering = .alwaysBasic }
        #expect(!basic.needsPermission)
    }
}

@Suite struct MenuBarSymbolTests {
    @Test func theLidMovesIn5DegreeSteps() {
        #expect(MenuBarSymbol.quantize(104) == 105)
        #expect(MenuBarSymbol.quantize(102.4) == 100)
        #expect(MenuBarSymbol.quantize(102.5) == 105)
        #expect(MenuBarSymbol.quantize(-3) == 0)
        #expect(MenuBarSymbol.quantize(200) == 135)
    }

    @Test func withoutASensorTheSymbolIsStill() {
        #expect(MenuBarSymbol.pose(angle: 104, sensorAvailable: false) == .still)
        #expect(MenuBarSymbol.pose(angle: nil, sensorAvailable: true) == .still)
        #expect(MenuBarSymbol.pose(angle: .nan, sensorAvailable: true) == .still)
        #expect(MenuBarSymbol.pose(angle: 61, sensorAvailable: true) == .angle(60))
    }

    @Test func theLidStaysInsideTheCanvasAtEveryAngle() {
        let margin = MenuBarSymbol.lidWidth / 2
        for degrees in stride(from: 0, through: 135, by: 5) {
            let end = MenuBarSymbol.lidEnd(for: .angle(degrees))
            #expect(end.x - margin >= 0 && end.x + margin <= MenuBarSymbol.canvas.width, "x at \(degrees)°")
            #expect(end.y - margin >= 0 && end.y + margin <= MenuBarSymbol.canvas.height, "y at \(degrees)°")
        }
        let upright = MenuBarSymbol.lidEnd(for: .angle(90))
        #expect(abs(upright.x - 9) < 1e-9)
    }

    @MainActor @Test func imagesAreTemplatesWithAnAccessibleName() {
        let image = MenuBarSymbol.image(for: .angle(105))
        #expect(image.isTemplate && image.size == MenuBarSymbol.canvas)
        #expect(image.accessibilityDescription == "Pli, lid at 105°")
        #expect(MenuBarSymbol.image(for: .angle(105)) === image)
        #expect(MenuBarSymbol.image(for: .still).accessibilityDescription == "Pli")
    }
}

@Suite struct SymbolThrottleTests {
    @Test func aChangeAfterAQuietMomentShowsAtOnce() {
        var throttle = SymbolThrottle(shown: .angle(110))
        #expect(throttle.offer(.angle(105), at: 10) == nil)
        #expect(throttle.shown == .angle(105))
    }

    @Test func changesInsideOneThirtiethOfASecondWaitAndTheLastOneWins() {
        var throttle = SymbolThrottle(shown: .angle(110))
        _ = throttle.offer(.angle(105), at: 10)
        let flushAt = throttle.offer(.angle(100), at: 10.01)
        #expect(flushAt == 10 + SymbolThrottle.minimumInterval)
        #expect(throttle.offer(.angle(95), at: 10.02) == nil)
        #expect(throttle.shown == .angle(105))
        #expect(throttle.flush(at: 10.02) == 10 + SymbolThrottle.minimumInterval)
        #expect(throttle.flush(at: flushAt!) == nil)
        #expect(throttle.shown == .angle(95))
    }

    @Test func goingBackToTheShownPoseCancelsTheWait() {
        var throttle = SymbolThrottle(shown: .angle(110))
        _ = throttle.offer(.angle(105), at: 10)
        _ = throttle.offer(.angle(100), at: 10.01)
        _ = throttle.offer(.angle(105), at: 10.02)
        #expect(throttle.flush(at: 11) == nil)
        #expect(throttle.shown == .angle(105))
    }

    /// Spec 8.2: a fast close sends a new angle every 1/120 s; the symbol redraws 30 times per second at most and
    /// ends on the final angle.
    @Test func aFastCloseRedrawsAtMost30TimesPerSecond() {
        var throttle = SymbolThrottle(shown: .angle(110))
        var redraws = 0
        var pendingFlush: Double?
        var last = throttle.shown
        for frame in 0...120 {
            let now = Double(frame) / 120
            if let at = pendingFlush, now >= at { pendingFlush = throttle.flush(at: now) }
            let angle = 110 - Double(frame) * 110 / 120
            if let at = throttle.offer(MenuBarSymbol.pose(angle: angle, sensorAvailable: true), at: now) { pendingFlush = at }
            if throttle.shown != last { redraws += 1; last = throttle.shown }
        }
        if let at = pendingFlush { _ = throttle.flush(at: at) }
        #expect(redraws <= 31)
        #expect(throttle.shown == .angle(0))
    }
}
