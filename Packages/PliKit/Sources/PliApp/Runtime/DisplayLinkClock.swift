import AppKit
import PliSystem
import QuartzCore

/// Frames paced by the target display itself (spec 7.2): a CADisplayLink on that screen, 60 to 120 Hz.
/// It ticks with no Pli window on screen, which the director needs while a capture is pending.
@MainActor
public final class DisplayLinkClock: NSObject, FrameClock {
    private var link: CADisplayLink?
    private var onFrame: (@MainActor () -> Void)?
    public private(set) var isRunning = false

    public override init() {
        super.init()
    }

    public func start(display: CGDirectDisplayID?, maximumRate: Double, onFrame: @escaping @MainActor () -> Void) {
        stop()
        isRunning = true
        self.onFrame = onFrame
        // Without a screen (display asleep or gone), the runtime's 10 Hz stall ticks carry the director.
        guard let screen = display.flatMap(DisplayInfo.screen(for:)) ?? NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(fire(_:)))
        let rate = Float(maximumRate)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, rate), maximum: rate, preferred: rate)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    public func stop() {
        link?.invalidate()
        link = nil
        onFrame = nil
        isRunning = false
    }

    @objc private func fire(_ link: CADisplayLink) {
        onFrame?()
    }
}
