import CoreGraphics
import Metal
import PliCore
import PliRender
import Testing
@testable import PliUI

@MainActor @Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a GPU"))
struct PreviewRendererTests {
    /// Blue, green and red of the pixel at (x, y), 0 to 255.
    private func pixel(_ image: CGImage, x: Int, y: Int) -> (Int, Int, Int) {
        let data = image.dataProvider!.data! as Data
        let offset = y * image.bytesPerRow + x * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]))
    }

    @Test func anOpenLidShowsThePictureItself() throws {
        let renderer = PreviewRenderer(renderer: try GlassRenderer())
        let image = try #require(renderer.still(of: Fixtures.picture(width: 64, height: 40, gray: 128), progress: 0,
                                                parameters: .duo, pixelWidth: 64, pixelHeight: 40))
        #expect(image.width == 64 && image.height == 40)
        let (b, g, r) = pixel(image, x: 32, y: 20)
        #expect(abs(b - 128) <= 2 && abs(g - 128) <= 2 && abs(r - 128) <= 2)
    }

    @Test func aFullFoldIsBlack() throws {
        let renderer = PreviewRenderer(renderer: try GlassRenderer())
        let image = try #require(renderer.still(of: Fixtures.picture(width: 64, height: 40, gray: 200), progress: 1,
                                                parameters: .duo, pixelWidth: 64, pixelHeight: 40))
        let (b, g, r) = pixel(image, x: 32, y: 20)
        #expect(b <= 2 && g <= 2 && r <= 2)
    }

    @Test func oneMiniatureStillFrostsTowardTheTop() throws {
        let renderer = PreviewRenderer(renderer: try GlassRenderer())
        let picture = Fixtures.picture(width: 96, height: 60, gray: 180)
        let image = try #require(renderer.still(of: picture, progress: 0.6, parameters: .duo, pixelWidth: 96, pixelHeight: 60))
        let top = pixel(image, x: 48, y: 4).0, bottom = pixel(image, x: 48, y: 56).0
        #expect(top < bottom)
        #expect(renderer.still(of: picture, progress: 0.3, parameters: .duo, pixelWidth: 96, pixelHeight: 60) != nil)
    }

    @Test func withoutMetalThereIsNoStill() {
        let renderer = PreviewRenderer(renderer: nil)
        #expect(renderer.still(of: Fixtures.picture(), progress: 0.5, parameters: .duo, pixelWidth: 8, pixelHeight: 5) == nil)
    }
}
