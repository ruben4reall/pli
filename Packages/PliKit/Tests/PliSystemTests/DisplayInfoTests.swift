import CoreGraphics
import Testing
@testable import PliSystem

@Suite struct DisplayInfoTests {
    /// The owner's MacBook Pro 14-inch: 1512 x 982 points at 2x, 301.2 x 195.6 mm.
    let builtIn = DisplayDescription(id: 1, isBuiltIn: true, isMain: true, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                     backingScale: 2, physicalSizeMM: CGSize(width: 301.2, height: 195.6))
    let external = DisplayDescription(id: 7, isBuiltIn: false, isMain: false, frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
                                      backingScale: 2, physicalSizeMM: CGSize(width: 597, height: 336))

    @Test func pixelsFollowTheBackingStore() {
        #expect(builtIn.pixelWidth == 3024 && builtIn.pixelHeight == 1964)
    }

    @Test func densityComesFromThePhysicalWidth() {
        #expect(abs(builtIn.pixelsPerMM - 3024 / 301.2) < 1e-9)
        #expect(abs(external.pixelsPerMM - 5120 / 597.0) < 1e-9)
    }

    @Test func anUnknownSizeFallsBackToATypicalDensity() {
        var unknown = builtIn
        unknown.physicalSizeMM = .zero
        #expect(unknown.pixelsPerMM == 9)
        unknown.physicalSizeMM = CGSize(width: 12, height: 8)   // implausible: a projector reporting nonsense
        #expect(unknown.pixelsPerMM == 9)
    }

    @Test func theBuiltInPanelIsTheTargetEvenWhenAnotherDisplayIsMain() {
        var secondary = builtIn
        secondary.isMain = false
        var main = external
        main.isMain = true
        #expect(DisplayInfo.effectTarget(in: [main, secondary], isLaptop: true)?.id == 1)
    }

    @Test func aDesktopMacUsesItsMainDisplay() {
        var main = external
        main.isMain = true
        let other = DisplayDescription(id: 9, isBuiltIn: false, isMain: false, frame: .zero, backingScale: 1, physicalSizeMM: .zero)
        #expect(DisplayInfo.effectTarget(in: [other, main], isLaptop: false)?.id == 7)
    }

    @Test func aClosedMacBookOnAnExternalDisplayPauses() {
        var main = external
        main.isMain = true
        #expect(DisplayInfo.effectTarget(in: [main], isLaptop: true) == nil)
        #expect(DisplayInfo.effectTarget(in: [], isLaptop: false) == nil)
    }
}
