import Foundation
import Testing
@testable import PliCore

@Suite struct ClampingTests {
    @Test func clampsIntoRange() {
        #expect(5.0.clamped(to: 0...1) == 1)
        #expect((-2.0).clamped(to: 0...1) == 0)
        #expect(0.5.clamped(to: 0...1) == 0.5)
    }

    @Test func nonFiniteValuesFallToTheLowerBound() {
        #expect(Double.nan.clamped(to: 2...3) == 2)
        #expect(Double.infinity.clamped(to: 2...3) == 2)
    }

    private struct Sample: Decodable {
        var number: Double
        var label: String?
        enum CodingKeys: String, CodingKey { case number, label }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            number = c.value(.number, default: 7)
            label = c.optionalValue(.label, default: "fallback")
        }
    }

    @Test func missingOrWrongTypedValuesUseTheDefault() throws {
        let missing = try JSONDecoder().decode(Sample.self, from: Data("{}".utf8))
        #expect(missing.number == 7)
        #expect(missing.label == "fallback")
        let wrong = try JSONDecoder().decode(Sample.self, from: Data(#"{"number":"x","label":5}"#.utf8))
        #expect(wrong.number == 7)
        #expect(wrong.label == "fallback")
    }

    @Test func explicitNullKeepsAnOptionalEmpty() throws {
        let cleared = try JSONDecoder().decode(Sample.self, from: Data(#"{"label":null}"#.utf8))
        #expect(cleared.label == nil)
    }
}
