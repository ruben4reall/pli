import Foundation
import PliCore

/// One numeric setting of the Style and Motion panes: its name, where it is stored, its range (spec 7.4), its unit
/// and slider step, and whether Basic mode uses it (spec 7.3).
public struct NumericSetting: Identifiable {
    public let id: String
    public let title: String
    public let help: String
    public let keyPath: WritableKeyPath<PliSettings, Double>
    public let range: ClosedRange<Double>
    public let unit: ValueUnit
    public let step: Double
    /// Inactive in Basic mode, dimmed with a note (spec 7.3).
    public let needsCapture: Bool

    public init(id: String, title: String, help: String, keyPath: WritableKeyPath<PliSettings, Double>,
                range: ClosedRange<Double>, unit: ValueUnit, step: Double, needsCapture: Bool) {
        self.id = id
        self.title = title
        self.help = help
        self.keyPath = keyPath
        self.range = range
        self.unit = unit
        self.step = step
        self.needsCapture = needsCapture
    }

    public func text(_ value: Double, locale: Locale = .current) -> String {
        ValueFormat.text(value, unit: unit, range: range, locale: locale)
    }

    public func spoken(_ value: Double, locale: Locale = .current) -> String {
        ValueFormat.spoken(value, unit: unit, range: range, locale: locale)
    }

    /// On the slider's grid (steps counted from the lower bound) and inside the range; NaN and infinities give the
    /// lower bound. Rounded to 1e-9 so 0.3 + 5 x 0.1 reads back as 0.8.
    public func validated(_ value: Double) -> Double {
        guard value.isFinite else { return range.lowerBound }
        let steps = ((value - range.lowerBound) / step).rounded()
        let snapped = (range.lowerBound + steps * step).clamped(to: range)
        return (snapped * 1e9).rounded() / 1e9
    }
}

/// Every numeric setting, in the order the panes show them.
@MainActor
public enum SettingsCatalog {
    public static let frost = NumericSetting(id: "frost", title: Strings.frost, help: Strings.frostHelp, keyPath: \.glass.frost,
                                             range: GlassParameters.Range.frost, unit: .percentOfRange, step: 0.0025, needsCapture: false)
    public static let grain = NumericSetting(id: "grain", title: Strings.grain, help: Strings.grainHelp, keyPath: \.glass.grain,
                                             range: GlassParameters.Range.grain, unit: .percent, step: 0.01, needsCapture: true)
    public static let darkening = NumericSetting(id: "darkening", title: Strings.darkening, help: Strings.darkeningHelp, keyPath: \.glass.darkening,
                                                 range: GlassParameters.Range.darkening, unit: .percentOfRange, step: 0.001, needsCapture: false)
    public static let tintAmount = NumericSetting(id: "tintAmount", title: Strings.tintAmount, help: Strings.tintHelp, keyPath: \.glass.tintAmount,
                                                  range: GlassParameters.Range.tintAmount, unit: .percent, step: 0.01, needsCapture: true)
    public static let saturation = NumericSetting(id: "saturation", title: Strings.saturation, help: Strings.saturationHelp, keyPath: \.glass.saturation,
                                                  range: GlassParameters.Range.saturation, unit: .percent, step: 0.01, needsCapture: true)
    public static let edgeSheen = NumericSetting(id: "edgeSheen", title: Strings.edgeSheen, help: Strings.edgeSheenHelp, keyPath: \.glass.edgeSheen,
                                                 range: GlassParameters.Range.edgeSheen, unit: .percent, step: 0.01, needsCapture: true)
    public static let prism = NumericSetting(id: "prism", title: Strings.prism, help: Strings.prismHelp, keyPath: \.glass.prism,
                                             range: GlassParameters.Range.prism, unit: .percent, step: 0.01, needsCapture: true)
    public static let eyeDistance = NumericSetting(id: "eyeDistanceMM", title: Strings.eyeDistance, help: Strings.eyeDistanceHelp, keyPath: \.glass.eyeDistanceMM,
                                                   range: GlassParameters.Range.eyeDistanceMM, unit: .millimeters, step: 5, needsCapture: true)
    public static let eyeHeight = NumericSetting(id: "eyeHeight", title: Strings.eyeHeight, help: Strings.eyeHeightHelp, keyPath: \.glass.eyeHeight,
                                                 range: GlassParameters.Range.eyeHeight, unit: .percent, step: 0.01, needsCapture: true)
    public static let spatialAnchor = NumericSetting(id: "spatialAnchor", title: Strings.spatialAnchor, help: Strings.spatialAnchorHelp, keyPath: \.glass.spatialAnchor,
                                                     range: GlassParameters.Range.spatialAnchor, unit: .percent, step: 0.01, needsCapture: true)
    public static let maxTilt = NumericSetting(id: "maxTiltDegrees", title: Strings.maxTilt, help: Strings.maxTiltHelp, keyPath: \.glass.maxTiltDegrees,
                                               range: GlassParameters.Range.maxTiltDegrees, unit: .degrees, step: 1, needsCapture: true)
    public static let finalBlackout = NumericSetting(id: "finalBlackout", title: Strings.finalBlackout, help: Strings.finalBlackoutHelp, keyPath: \.glass.finalBlackout,
                                                     range: GlassParameters.Range.finalBlackout, unit: .percent, step: 0.01, needsCapture: false)
    public static let edgeSoftness = NumericSetting(id: "edgeSoftnessMM", title: Strings.edgeSoftness, help: Strings.edgeSoftnessHelp, keyPath: \.glass.edgeSoftnessMM,
                                                    range: GlassParameters.Range.edgeSoftnessMM, unit: .millimeters, step: 0.5, needsCapture: true)
    public static let startAngle = NumericSetting(id: "startAngle", title: Strings.startAngle, help: Strings.startAngleHelp, keyPath: \.motion.startAngle,
                                                  range: MotionParameters.Range.startAngle, unit: .degrees, step: 1, needsCapture: false)
    public static let startThreshold = NumericSetting(id: "deadZoneDegrees", title: Strings.startThreshold, help: Strings.startThresholdHelp, keyPath: \.motion.deadZoneDegrees,
                                                      range: MotionParameters.Range.deadZoneDegrees, unit: .degrees, step: 1, needsCapture: false)
    public static let fullyFrostedAt = NumericSetting(id: "fullFoldAngle", title: Strings.fullyFrostedAt, help: Strings.fullyFrostedAtHelp, keyPath: \.motion.fullFoldAngle,
                                                      range: MotionParameters.Range.fullFoldAngle, unit: .degrees, step: 1, needsCapture: false)
    public static let smoothing = NumericSetting(id: "smoothingMS", title: Strings.smoothing, help: Strings.smoothingHelp, keyPath: \.motion.smoothingMS,
                                                 range: MotionParameters.Range.smoothingMS, unit: .milliseconds, step: 5, needsCapture: false)
    public static let settleTime = NumericSetting(id: "settleSeconds", title: Strings.settleTime, help: Strings.settleTimeHelp, keyPath: \.motion.settleSeconds,
                                                  range: MotionParameters.Range.settleSeconds, unit: .seconds, step: 0.1, needsCapture: false)
    public static let unlockReveal = NumericSetting(id: "unlockRevealSeconds", title: Strings.unlockReveal, help: Strings.unlockRevealHelp, keyPath: \.motion.unlockRevealSeconds,
                                                    range: MotionParameters.Range.unlockRevealSeconds, unit: .seconds, step: 0.05, needsCapture: false)
    public static let demoFold = NumericSetting(id: "demoFoldSeconds", title: Strings.demoFold, help: Strings.demoFoldHelp, keyPath: \.motion.demoFoldSeconds,
                                                range: MotionParameters.Range.demoFoldSeconds, unit: .seconds, step: 0.05, needsCapture: false)
    public static let demoHold = NumericSetting(id: "demoHoldSeconds", title: Strings.demoHold, help: Strings.demoHoldHelp, keyPath: \.motion.demoHoldSeconds,
                                                range: MotionParameters.Range.demoHoldSeconds, unit: .seconds, step: 0.05, needsCapture: false)
    public static let demoUnfold = NumericSetting(id: "demoUnfoldSeconds", title: Strings.demoUnfold, help: Strings.demoUnfoldHelp, keyPath: \.motion.demoUnfoldSeconds,
                                                  range: MotionParameters.Range.demoUnfoldSeconds, unit: .seconds, step: 0.05, needsCapture: false)
    public static let lockScreenUnfold = NumericSetting(id: "lockScreenUnfoldSeconds", title: Strings.lockScreenUnfold, help: Strings.lockScreenUnfoldHelp, keyPath: \.motion.lockScreenUnfoldSeconds,
                                                        range: MotionParameters.Range.lockScreenUnfoldSeconds, unit: .seconds, step: 0.05, needsCapture: false)

    /// The Glass group, Tint excepted (a color and an amount, drawn as one row).
    public static let glass: [NumericSetting] = [frost, grain, darkening, saturation, edgeSheen, prism]
    public static let perspective: [NumericSetting] = [eyeDistance, eyeHeight, spatialAnchor, maxTilt, finalBlackout, edgeSoftness]
    /// The Motion group's lid settings, Curve excepted (a picker).
    public static let lid: [NumericSetting] = [startAngle, startThreshold, fullyFrostedAt, smoothing, settleTime]
    public static let timing: [NumericSetting] = [unlockReveal, demoFold, demoHold, demoUnfold, lockScreenUnfold]
    public static var all: [NumericSetting] { glass + [tintAmount] + perspective + lid + timing }
}
