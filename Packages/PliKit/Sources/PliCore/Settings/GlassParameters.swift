import Foundation

/// An sRGB color with components in 0...1.
public struct RGBColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = RGBColor(red: 1, green: 1, blue: 1)
    /// Brand token Night, #0A0C10.
    public static let night = RGBColor(red: 10.0 / 255, green: 12.0 / 255, blue: 16.0 / 255)

    public func clamped() -> RGBColor {
        RGBColor(red: red.clamped(to: 0...1), green: green.clamped(to: 0...1), blue: blue.clamped(to: 0...1))
    }

    enum CodingKeys: String, CodingKey { case red, green, blue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(red: c.value(.red, default: 1), green: c.value(.green, default: 1), blue: c.value(.blue, default: 1))
        self = clamped()
    }
}

/// Optical settings: the Glass and Perspective groups of the interface (spec 7.4).
public struct GlassParameters: Codable, Hashable, Sendable {
    public var frost: Double
    public var grain: Double
    public var darkening: Double
    public var tintColor: RGBColor
    public var tintAmount: Double
    public var saturation: Double
    public var edgeSheen: Double
    public var prism: Double
    public var eyeDistanceMM: Double
    public var eyeHeight: Double
    public var spatialAnchor: Double
    public var maxTiltDegrees: Double
    public var finalBlackout: Double
    public var edgeSoftnessMM: Double

    public enum Range {
        public static let frost: ClosedRange<Double> = 0...0.25
        public static let grain: ClosedRange<Double> = 0...1
        public static let darkening: ClosedRange<Double> = 0...0.2
        public static let tintAmount: ClosedRange<Double> = 0...1
        public static let saturation: ClosedRange<Double> = 0...2
        public static let edgeSheen: ClosedRange<Double> = 0...1
        public static let prism: ClosedRange<Double> = 0...1
        public static let eyeDistanceMM: ClosedRange<Double> = 250...900
        public static let eyeHeight: ClosedRange<Double> = 0...1
        public static let spatialAnchor: ClosedRange<Double> = 0...1
        public static let maxTiltDegrees: ClosedRange<Double> = 20...75
        public static let finalBlackout: ClosedRange<Double> = 0...0.3
        public static let edgeSoftnessMM: ClosedRange<Double> = 0...12
    }

    public init(
        frost: Double, grain: Double, darkening: Double, tintColor: RGBColor, tintAmount: Double,
        saturation: Double, edgeSheen: Double, prism: Double, eyeDistanceMM: Double, eyeHeight: Double,
        spatialAnchor: Double, maxTiltDegrees: Double, finalBlackout: Double, edgeSoftnessMM: Double
    ) {
        self.frost = frost
        self.grain = grain
        self.darkening = darkening
        self.tintColor = tintColor
        self.tintAmount = tintAmount
        self.saturation = saturation
        self.edgeSheen = edgeSheen
        self.prism = prism
        self.eyeDistanceMM = eyeDistanceMM
        self.eyeHeight = eyeHeight
        self.spatialAnchor = spatialAnchor
        self.maxTiltDegrees = maxTiltDegrees
        self.finalBlackout = finalBlackout
        self.edgeSoftnessMM = edgeSoftnessMM
    }

    /// The Duo preset: Pli's defaults.
    public static let duo = GlassParameters(
        frost: 0.09, grain: 0.30, darkening: 0.05, tintColor: .white, tintAmount: 0,
        saturation: 1, edgeSheen: 0, prism: 0, eyeDistanceMM: 450, eyeHeight: 0.30,
        spatialAnchor: 1, maxTiltDegrees: 50, finalBlackout: 0.12, edgeSoftnessMM: 3
    )

    public func clamped() -> GlassParameters {
        GlassParameters(
            frost: frost.clamped(to: Range.frost),
            grain: grain.clamped(to: Range.grain),
            darkening: darkening.clamped(to: Range.darkening),
            tintColor: tintColor.clamped(),
            tintAmount: tintAmount.clamped(to: Range.tintAmount),
            saturation: saturation.clamped(to: Range.saturation),
            edgeSheen: edgeSheen.clamped(to: Range.edgeSheen),
            prism: prism.clamped(to: Range.prism),
            eyeDistanceMM: eyeDistanceMM.clamped(to: Range.eyeDistanceMM),
            eyeHeight: eyeHeight.clamped(to: Range.eyeHeight),
            spatialAnchor: spatialAnchor.clamped(to: Range.spatialAnchor),
            maxTiltDegrees: maxTiltDegrees.clamped(to: Range.maxTiltDegrees),
            finalBlackout: finalBlackout.clamped(to: Range.finalBlackout),
            edgeSoftnessMM: edgeSoftnessMM.clamped(to: Range.edgeSoftnessMM)
        )
    }

    enum CodingKeys: String, CodingKey {
        case frost, grain, darkening, tintColor, tintAmount, saturation, edgeSheen, prism
        case eyeDistanceMM, eyeHeight, spatialAnchor, maxTiltDegrees, finalBlackout, edgeSoftnessMM
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GlassParameters.duo
        self.init(
            frost: c.value(.frost, default: d.frost),
            grain: c.value(.grain, default: d.grain),
            darkening: c.value(.darkening, default: d.darkening),
            tintColor: c.value(.tintColor, default: d.tintColor),
            tintAmount: c.value(.tintAmount, default: d.tintAmount),
            saturation: c.value(.saturation, default: d.saturation),
            edgeSheen: c.value(.edgeSheen, default: d.edgeSheen),
            prism: c.value(.prism, default: d.prism),
            eyeDistanceMM: c.value(.eyeDistanceMM, default: d.eyeDistanceMM),
            eyeHeight: c.value(.eyeHeight, default: d.eyeHeight),
            spatialAnchor: c.value(.spatialAnchor, default: d.spatialAnchor),
            maxTiltDegrees: c.value(.maxTiltDegrees, default: d.maxTiltDegrees),
            finalBlackout: c.value(.finalBlackout, default: d.finalBlackout),
            edgeSoftnessMM: c.value(.edgeSoftnessMM, default: d.edgeSoftnessMM)
        )
        self = clamped()
    }
}
