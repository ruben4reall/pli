import Foundation

/// Size of the surface being drawn, and how many of its pixels make one millimeter.
public struct GlassGeometry: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var pixelsPerMM: Double

    public init(width: Double, height: Double, pixelsPerMM: Double) {
        self.width = width
        self.height = height
        self.pixelsPerMM = pixelsPerMM
    }
}

/// The optical model's inputs for one frame, in pixels. Shared by the CPU reference and the GPU.
public struct DerivedOptics: Sendable, Equatable {
    public var tiltRadians: Double
    public var eyeDistancePx: Double
    public var eyeX: Double
    public var eyeY: Double
    public var frost: Double
    public var maxBlurPx: Double
    public var darkeningPerPx: Double
    public var spatialAnchor: Double
    public var edgeSoftnessPx: Double
    public var blackout: Double
}

/// Where one output pixel looks, how blurred and how dark it is.
public struct GlassSample: Sendable, Equatable {
    public var sourceX: Double
    public var sourceY: Double
    public var blurRadius: Double
    public var attenuation: Double
    public var coverage: Double
    public var isBlack: Bool
}

/// CPU reference of spec 7.1. The Metal shader in PliRender implements the same formulas.
public enum GlassOptics {
    public static let maxBlurMM = 18.0

    public static func derive(progress: Double, parameters g: GlassParameters, geometry: GlassGeometry, reduceMotion: Bool) -> DerivedOptics {
        let p = progress.clamped(to: 0...1)
        let rho = geometry.pixelsPerMM
        return DerivedOptics(
            tiltRadians: p * g.maxTiltDegrees * .pi / 180,
            eyeDistancePx: g.eyeDistanceMM * rho,
            eyeX: geometry.width / 2,
            eyeY: g.eyeHeight * geometry.height,
            frost: g.frost,
            maxBlurPx: maxBlurMM * rho,
            darkeningPerPx: g.darkening / rho,
            spatialAnchor: reduceMotion ? 0 : g.spatialAnchor,
            edgeSoftnessPx: g.edgeSoftnessMM * rho,
            blackout: blackout(progress: p, amount: g.finalBlackout)
        )
    }

    /// `1 − smoothstep(1 − b, 1, p)`; an amount of 0 means no blackout.
    public static func blackout(progress p: Double, amount b: Double) -> Double {
        guard b > 1e-4 else { return 1 }
        let t = ((p - (1 - b)) / b).clamped(to: 0...1)
        return 1 - t * t * (3 - 2 * t)
    }

    /// Sample for the output pixel at (x, y), pixel centers at .5.
    public static func sample(x: Double, y: Double, optics o: DerivedOptics, geometry: GlassGeometry) -> GlassSample {
        let width = geometry.width
        let height = geometry.height
        let d = height - y
        let gx = x
        let gy = height - d * cos(o.tiltRadians)
        let z = d * sin(o.tiltRadians)
        let depth = o.eyeDistancePx - z
        guard depth > 1 else {
            return GlassSample(sourceX: x, sourceY: y, blurRadius: 0, attenuation: 0, coverage: 0, isBlack: true)
        }
        let scale = o.eyeDistancePx / depth
        let qx = o.eyeX + (gx - o.eyeX) * scale
        let qy = o.eyeY + (gy - o.eyeY) * scale
        let sx = x + o.spatialAnchor * (qx - x)
        let sy = y + o.spatialAnchor * (qy - y)
        let radius = min(o.frost * z, o.maxBlurPx)
        let outsideX = max(max(-sx, sx - width), 0)
        let outsideY = max(max(-sy, sy - height), 0)
        let outside = (outsideX * outsideX + outsideY * outsideY).squareRoot()
        let coverage = (1 - outside / max(o.edgeSoftnessPx + radius, 1)).clamped(to: 0...1)
        let attenuation = max(1 - o.darkeningPerPx * radius, 0) * o.blackout
        return GlassSample(sourceX: sx, sourceY: sy, blurRadius: radius, attenuation: attenuation, coverage: coverage, isBlack: coverage <= 0)
    }
}
