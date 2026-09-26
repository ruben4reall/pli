import PliCore
import Testing
@testable import PliApp

@MainActor @Suite struct RuntimeSafeguardTests {
    @Test func aStalledDisplayLinkStillTicks() {
        let h = RuntimeHarness()
        h.clock.stalled = true
        h.snapshotter.behavior = .never
        h.moveLid(to: 60, over: 0.3, hold: 0.5)
        // The capture never lands; with no frames the 250 ms timeout still passes, from the 10 Hz stall ticks.
        #expect(h.phase == .idle)
        #expect(!h.clock.isRunning)
        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func aStuckOverlayIsHiddenWithinTwoSeconds() {
        let h = RuntimeHarness()
        h.surfaces.stuck = [.desktop]
        let start = h.now
        h.setLid(109)   // any event: the runtime notices a visible surface
        h.run(for: 2.0) { _ in 109 }
        let hidden = h.surfaces.time(of: .hideAll) ?? .infinity
        #expect(hidden - start <= 2.0 - DirectorRuntime.watchdogFade)
        #expect(h.surfaces.visibleSurfaces.isEmpty)
        #expect(h.scheduler.pendingCount == 0)
    }

    @Test func stoppingHidesEverythingAndGivesTheCursorBack() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        #expect(h.cursor.hidden)
        h.runtime.stop()
        #expect(h.surfaces.visibleSurfaces.isEmpty && !h.cursor.hidden)
        #expect(!h.clock.isRunning && !h.sensor.running)
        #expect(h.scheduler.pendingCount == 0)   // none of the runtime's timers survive
    }
}
