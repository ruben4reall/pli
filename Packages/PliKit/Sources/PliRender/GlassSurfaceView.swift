import AppKit
import CoreVideo
import Metal
import PliCore
import QuartzCore

/// The view that shows the frosted glass (spec 7.2): a CAMetalLayer in Display P3, bgra8Unorm, no EDR.
///
/// In the overlay, the runtime's frame tick calls `draw(...)` directly, so a frame shows the angle read in that
/// same tick. Standalone users (the settings preview) pace it with the view's own display link through
/// `startDisplayLink(_:)`.
@MainActor
public final class GlassSurfaceView: NSView {
    public let renderer: GlassRenderer
    private let importer: PixelBufferImporter
    private let metalLayer = CAMetalLayer()
    private var source: PreparedSource?
    private var displayLink: CADisplayLink?
    private var frameHandler: (@MainActor (CFTimeInterval) -> Void)?

    public init(renderer: GlassRenderer, frame: NSRect = .zero) throws {
        self.renderer = renderer
        importer = try PixelBufferImporter(device: renderer.device)
        super.init(frame: frame)
        metalLayer.device = renderer.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        metalLayer.wantsExtendedDynamicRangeContent = false
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = false
        metalLayer.maximumDrawableCount = 3
        metalLayer.allowsNextDrawableTimeout = true
        wantsLayer = true
        updateDrawableSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func makeBackingLayer() -> CALayer { metalLayer }

    public override var isOpaque: Bool { false }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopDisplayLink() }
        updateDrawableSize()
    }

    /// Pixels of the drawable: the view's bounds at its window's backing scale.
    public var drawableSize: CGSize { metalLayer.drawableSize }
    public var hasSource: Bool { source != nil }

    /// Takes a new picture: maps it without a copy and builds its blur pyramid on the GPU. The pyramid is queued
    /// before any later frame on the same queue, so the next `draw` can use it at once.
    public func setSource(_ pixelBuffer: CVPixelBuffer, halfResolution: Bool) throws {
        let mapped = try importer.texture(for: pixelBuffer)
        guard let buffer = renderer.commandQueue.makeCommandBuffer() else { throw RenderError.allocationFailed }
        let prepared = try renderer.prepare(mapped.texture, halfResolution: halfResolution, commandBuffer: buffer)
        buffer.addCompletedHandler { _ in withExtendedLifetime(mapped) {} }
        buffer.commit()
        source = prepared
    }

    /// Lets the picture go (spec 7.2: released 1 s after returning to rest).
    public func clearSource() {
        source = nil
    }

    /// Draws one frame now; without a picture, black. False when no drawable was available.
    @discardableResult
    public func draw(progress: Double, parameters: GlassParameters, pixelsPerMM: Double,
                     quality: RenderQuality = .full, reduceMotion: Bool = false) -> Bool {
        let size = metalLayer.drawableSize
        guard size.width >= 1, size.height >= 1,
              let drawable = metalLayer.nextDrawable(),
              let buffer = renderer.commandQueue.makeCommandBuffer() else { return false }
        if let source {
            let geometry = GlassGeometry(width: Double(size.width), height: Double(size.height), pixelsPerMM: pixelsPerMM)
            let frame = GlassFrame(progress: progress, parameters: parameters, geometry: geometry, quality: quality, reduceMotion: reduceMotion)
            do {
                try renderer.encode(frame, source: source, target: drawable.texture, commandBuffer: buffer)
            } catch {
                return false
            }
        } else if !clear(drawable.texture, alpha: 1, into: buffer) {
            return false
        }
        buffer.present(drawable)
        buffer.commit()
        return true
    }

    /// Presents a fully transparent frame, so an old picture can never flash when the view is shown again.
    public func presentClear() {
        guard metalLayer.drawableSize.width >= 1, let drawable = metalLayer.nextDrawable(),
              let buffer = renderer.commandQueue.makeCommandBuffer(),
              clear(drawable.texture, alpha: 0, into: buffer) else { return }
        buffer.present(drawable)
        buffer.commit()
    }

    /// Standalone pacing: calls `handler` on every refresh of the display this view is on, up to 120 Hz.
    public func startDisplayLink(_ handler: @escaping @MainActor (CFTimeInterval) -> Void) {
        stopDisplayLink()
        frameHandler = handler
        let link = displayLink(target: self, selector: #selector(displayLinkFired(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        frameHandler = nil
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        frameHandler?(link.targetTimestamp)
    }

    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        metalLayer.contentsScale = scale
        let size = CGSize(width: max(bounds.width * scale, 1), height: max(bounds.height * scale, 1))
        if metalLayer.drawableSize != size { metalLayer.drawableSize = size }
    }

    private func clear(_ texture: MTLTexture, alpha: Double, into buffer: MTLCommandBuffer) -> Bool {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: alpha)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.endEncoding()
        return true
    }
}
