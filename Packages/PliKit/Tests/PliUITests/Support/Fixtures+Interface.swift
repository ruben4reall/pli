import CoreVideo
import Foundation
import PliCore
@testable import PliUI

extension Fixtures {
    /// An interface on a fresh preset folder, connected to a fake app. The Mac has a sensor and every permission,
    /// lid at 104°, rest at 110°, unless `live` says otherwise.
    @MainActor static func interface(settings: PliSettings = .default,
                                     live: LiveSnapshot = LiveSnapshot(lidAngle: 104, restAngle: 110),
                                     clock: @escaping @MainActor () -> Double = { 0 }) -> (InterfaceModel, FakeServices) {
        let interface = InterfaceModel(settings: settings, presetStore: store(), renderer: nil, interpreter: FakeInterpreter(),
                                       live: live, clock: clock)
        let services = FakeServices()
        interface.connect(services)
        return (interface, services)
    }

    /// A tiny IOSurface-backed picture of a uniform gray.
    static func picture(_ kind: PreviewPicture.Kind = .screen, width: Int = 8, height: Int = 5, gray: UInt8 = 128) -> PreviewPicture {
        let attributes: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary,
                                           kCVPixelBufferMetalCompatibilityKey: true]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixels)
        for y in 0..<height {
            for x in 0..<width {
                let pixel = base + y * bytesPerRow + x * 4
                pixel[0] = gray; pixel[1] = gray; pixel[2] = gray; pixel[3] = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(pixels, [])
        return PreviewPicture(pixelBuffer: pixels, kind: kind, displayWidthMM: 301.2)
    }
}
