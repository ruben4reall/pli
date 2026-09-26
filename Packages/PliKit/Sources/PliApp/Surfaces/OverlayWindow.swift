import AppKit

/// A borderless, click-through panel above everything (spec 5.6, 10.6): it never takes the mouse, the keyboard or
/// focus, sits on every Space and above full-screen apps, and is ordered out whenever it is hidden.
final class OverlayWindow: NSPanel {
    private var fadeGeneration = 0

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isMovable = false
        isExcludedFromWindowsMenu = true
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Full opacity at once, cancelling a fade in progress.
    func present() {
        fadeGeneration += 1
        alphaValue = 1
        orderFrontRegardless()
    }

    /// Fades out over `fade` seconds, then orders out: a transparent window left on screen still costs compositing.
    func dismiss(fade: Double, completion: @escaping @MainActor () -> Void) {
        fadeGeneration += 1
        let generation = fadeGeneration
        guard fade > 0, isVisible else {
            alphaValue = 0
            orderOut(nil)
            completion()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fade
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.fadeGeneration == generation else { return }
                self.orderOut(nil)
                completion()
            }
        })
    }
}
