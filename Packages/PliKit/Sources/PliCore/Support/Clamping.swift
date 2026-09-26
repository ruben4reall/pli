import Foundation

extension Double {
    /// Clamps into `range`; NaN and infinities fall to the lower bound so a corrupt value can never escape a range.
    public func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.lowerBound }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension KeyedDecodingContainer {
    /// Decodes `key`, or returns `fallback` when the key is missing or holds the wrong type.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// Like `value(_:default:)` for optionals: a missing key gives `fallback`, an explicit null gives nil.
    func optionalValue<T: Decodable>(_ key: Key, default fallback: T?) -> T? {
        guard contains(key) else { return fallback }
        if (try? decodeNil(forKey: key)) == true { return nil }
        return (try? decode(T.self, forKey: key)) ?? fallback
    }
}
