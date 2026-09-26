import AppKit
import PliCore
import PliRender
import SwiftUI

/// The real renderer drawing the fold on a picture of the screen (spec 8.3). It draws when an input or its size
/// changes, and at the display's rate only while a `TimelineView` plays an animation.
struct GlassPreview: NSViewRepresentable {
    let renderer: GlassRenderer?
    let picture: PreviewPicture?
    let progress: Double
    let parameters: GlassParameters
    let reduceMotion: Bool

    func makeNSView(context: Context) -> PreviewHostView {
        PreviewHostView(renderer: renderer)
    }

    func updateNSView(_ view: PreviewHostView, context: Context) {
        view.update(picture: picture, progress: progress, parameters: parameters, reduceMotion: reduceMotion)
    }
}

/// Holds a `GlassSurfaceView` (a final class) and redraws it on every change of size or input. The picture is mapped
/// without a copy and its blur pyramid built at half resolution, plenty for a preview.
final class PreviewHostView: NSView {
    private let surface: GlassSurfaceView?
    private var picture: PreviewPicture?
    private var progress = 0.0
    private var parameters = GlassParameters.duo
    private var reduceMotion = false

    init(renderer: GlassRenderer?) {
        surface = renderer.flatMap { try? GlassSurfaceView(renderer: $0) }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Theme.Palette.night.nsColor().cgColor
        if let surface { addSubview(surface) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        surface?.frame = bounds
        redraw()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        redraw()
    }

    func update(picture: PreviewPicture?, progress: Double, parameters: GlassParameters, reduceMotion: Bool) {
        if picture !== self.picture {
            self.picture = picture
            if let picture {
                try? surface?.setSource(picture.pixelBuffer, halfResolution: true)
            } else {
                surface?.clearSource()
            }
        }
        self.progress = progress
        self.parameters = parameters
        self.reduceMotion = reduceMotion
        redraw()
    }

    private func redraw() {
        guard let surface, window != nil, bounds.width >= 1, bounds.height >= 1 else { return }
        let widthMM = picture?.displayWidthMM ?? PreviewPicture.fallbackWidthMM
        surface.draw(progress: progress, parameters: parameters, pixelsPerMM: Double(surface.drawableSize.width) / widthMM,
                     reduceMotion: reduceMotion)
    }
}

/// The large preview and its caption (spec 8.3). The timeline runs only while Play Fold or Play Unfold plays.
struct PreviewStage: View {
    let interface: InterfaceModel
    var maxHeight: CGFloat = 260

    var body: some View {
        let preview = interface.preview
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: nil, paused: !preview.isPlaying)) { context in
                GlassPreview(renderer: interface.renderer.renderer, picture: preview.picture,
                             progress: interface.previewProgress(at: context.date.timeIntervalSinceReferenceDate),
                             parameters: interface.settings.glass, reduceMotion: interface.previewReduceMotion)
            }
            .aspectRatio(preview.picture?.aspectRatio ?? interface.live.displayAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(Text(Strings.previewAccessibility))
            .accessibilityAddTraits(.isImage)
            if let picture = preview.picture {
                Footnote(picture.kind == .screen ? Strings.previewOfScreen : Strings.previewOnWallpaper)
            }
        }
    }
}

/// A preset drawn by the real renderer, still, on the same picture as the large preview.
struct PresetThumbnail: View {
    /// A fold far enough to show the glass, before the final blackout begins.
    static let progress = 0.55

    let renderer: PreviewRenderer
    let picture: PreviewPicture?
    let parameters: GlassParameters
    var width: CGFloat = Theme.Layout.presetTileWidth
    var cornerRadius: CGFloat = Theme.Radius.small
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?

    struct Key: Equatable {
        var picture: ObjectIdentifier?
        var parameters: GlassParameters
        var scale: CGFloat
    }

    var body: some View {
        let height = (width / CGFloat(picture?.aspectRatio ?? 1512.0 / 982.0)).rounded()
        ZStack {
            Theme.Colors.night
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: Key(picture: picture.map(ObjectIdentifier.init), parameters: parameters, scale: displayScale)) {
            guard let picture else {
                image = nil
                return
            }
            image = renderer.still(of: picture, progress: Self.progress, parameters: parameters,
                                   pixelWidth: Int(width * displayScale), pixelHeight: Int(height * displayScale))
        }
    }
}
