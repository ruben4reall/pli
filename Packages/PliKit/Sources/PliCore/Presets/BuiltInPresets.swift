import Foundation

/// The seven presets of spec table 7.5. Values not listed there are Duo's.
public enum BuiltInPresets {
    public static let duo = Preset(id: "duo", name: "Duo", glass: .duo, motion: .duo)

    public static let subtle: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.05; g.grain = 0.15; g.darkening = 0.025; g.spatialAnchor = 0.7
        g.maxTiltDegrees = 35; g.finalBlackout = 0.10
        var m = MotionParameters.duo
        m.startAngle = 85; m.deadZoneDegrees = 8; m.curve = .smooth
        return Preset(id: "subtle", name: "Subtle", glass: g, motion: m)
    }()

    public static let deepFrost: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.16; g.grain = 0.7; g.darkening = 0.06; g.saturation = 0.85; g.maxTiltDegrees = 55
        var m = MotionParameters.duo
        m.fullFoldAngle = 25
        return Preset(id: "deepFrost", name: "Deep Frost", glass: g, motion: m)
    }()

    public static let night: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.10; g.darkening = 0.12; g.tintColor = .night; g.tintAmount = 0.35
        g.saturation = 0.8; g.finalBlackout = 0.20
        var m = MotionParameters.duo
        m.fullFoldAngle = 30; m.curve = .fastStart
        return Preset(id: "night", name: "Night", glass: g, motion: m)
    }()

    public static let crystal: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.02; g.grain = 0.05; g.darkening = 0.02; g.edgeSheen = 0.6; g.prism = 0.1
        g.eyeDistanceMM = 400; g.maxTiltDegrees = 55; g.finalBlackout = 0.08
        var m = MotionParameters.duo
        m.curve = .smooth
        return Preset(id: "crystal", name: "Crystal", glass: g, motion: m)
    }()

    public static let prism: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.08; g.grain = 0.25; g.darkening = 0.04; g.prism = 0.55; g.edgeSheen = 0.2
        return Preset(id: "prism", name: "Prism", glass: g, motion: .duo)
    }()

    public static let cinema: Preset = {
        var g = GlassParameters.duo
        g.frost = 0.13; g.grain = 0.35; g.darkening = 0.07; g.eyeDistanceMM = 380; g.maxTiltDegrees = 65
        var m = MotionParameters.duo
        m.startAngle = 100; m.deadZoneDegrees = 3; m.fullFoldAngle = 28; m.curve = .fastStart
        return Preset(id: "cinema", name: "Cinema", glass: g, motion: m)
    }()

    public static let all: [Preset] = [duo, subtle, deepFrost, night, crystal, prism, cinema]

    public static func preset(id: String) -> Preset? { all.first { $0.id == id } }

    public static func isBuiltIn(id: String) -> Bool { all.contains { $0.id == id } }
}
