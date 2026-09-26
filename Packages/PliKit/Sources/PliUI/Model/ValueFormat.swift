import Foundation

/// How a stored number reads in the interface (spec 7.4 and 8.6): Frost and Darkening as a percentage of their
/// range, every other value in its own unit.
public enum ValueUnit: Sendable, Equatable {
    /// Stored as a fraction (0...1, or 0...2 for Saturation), shown times 100 with %.
    case percent
    /// Stored in any range, shown as the percentage of that range.
    case percentOfRange
    case degrees
    case millimeters
    case milliseconds
    case seconds
}

public enum ValueFormat {
    /// The number shown before the unit: a percentage for the two percent units, the stored value otherwise.
    public static func displayNumber(_ value: Double, unit: ValueUnit, range: ClosedRange<Double>) -> Double {
        switch unit {
        case .percent:
            return value * 100
        case .percentOfRange:
            let span = range.upperBound - range.lowerBound
            return span > 0 ? (value - range.lowerBound) / span * 100 : 0
        case .degrees, .millimeters, .milliseconds, .seconds:
            return value
        }
    }

    /// What the value label shows: "36%", "450 mm", "50°", "45 ms", "0.8 s", "0.35 s".
    public static func text(_ value: Double, unit: ValueUnit, range: ClosedRange<Double>, locale: Locale = .current) -> String {
        let number = displayNumber(value, unit: unit, range: range)
        switch unit {
        case .percent, .percentOfRange:
            return (number / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        case .degrees:
            return Strings.degrees(plain(number, fraction: 0...0, locale))
        case .millimeters:
            return Strings.millimeters(plain(number, fraction: 0...1, locale))
        case .milliseconds:
            return Strings.milliseconds(plain(number, fraction: 0...0, locale))
        case .seconds:
            return Strings.seconds(plain(number, fraction: 1...2, locale))
        }
    }

    /// What VoiceOver says: "36%", "450 millimeters", "50 degrees", "45 milliseconds", "0.8 seconds".
    public static func spoken(_ value: Double, unit: ValueUnit, range: ClosedRange<Double>, locale: Locale = .current) -> String {
        let number = displayNumber(value, unit: unit, range: range)
        switch unit {
        case .percent, .percentOfRange:
            return text(value, unit: unit, range: range, locale: locale)
        case .degrees:
            return wide(Measurement(value: number, unit: UnitAngle.degrees), fraction: 0...0, locale)
        case .millimeters:
            return wide(Measurement(value: number, unit: UnitLength.millimeters), fraction: 0...1, locale)
        case .milliseconds:
            return wide(Measurement(value: number, unit: UnitDuration.milliseconds), fraction: 0...0, locale)
        case .seconds:
            return wide(Measurement(value: number, unit: UnitDuration.seconds), fraction: 1...2, locale)
        }
    }

    private static func plain(_ number: Double, fraction: ClosedRange<Int>, _ locale: Locale) -> String {
        number.formatted(.number.precision(.fractionLength(fraction)).grouping(.never).locale(locale))
    }

    private static func wide<U: Dimension>(_ measurement: Measurement<U>, fraction: ClosedRange<Int>, _ locale: Locale) -> String {
        measurement.formatted(.measurement(width: .wide, usage: .asProvided,
                                           numberFormatStyle: .number.precision(.fractionLength(fraction)).locale(locale))
            .locale(locale))
    }
}
