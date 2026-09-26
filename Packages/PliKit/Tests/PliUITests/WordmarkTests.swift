import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import PliUI

@Suite struct WordmarkTests {
    static let brandFile = TestPaths.repositoryRoot.appendingPathComponent("brand/wordmark/pli-wordmark-ink.svg")

    private func bounds(_ data: String) throws -> CGRect {
        try #require(OutlinePath.parse(data)).cgPath.boundingBoxOfPath
    }

    private func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1e-6 && abs(a.minY - b.minY) < 1e-6 && abs(a.width - b.width) < 1e-6 && abs(a.height - b.height) < 1e-6
    }

    @Test func theOutlinesFillTheBrandFilesFrame() throws {
        #expect(close(try bounds(WordmarkOutline.letters), CGRect(origin: .zero, size: WordmarkOutline.size)))
    }

    @Test func thePaneDotsTheI() throws {
        #expect(close(try bounds(WordmarkOutline.pane), CGRect(x: 159.5, y: 9, width: 24, height: 19)))
    }

    /// Only what the brand's generator writes is read; anything else gives no path rather than a broken logo.
    @Test func otherPathDataGivesNoPath() {
        #expect(OutlinePath.parse("M0 0Q1 1 2 2") == nil)
        #expect(OutlinePath.parse("M0 0L1") == nil)
        #expect(OutlinePath.parse("m0 0l1 1") == nil)
        #expect(OutlinePath.parse("M0 0Z5") == nil)
        #expect(OutlinePath.parse("M0-1L2-3") != nil)
    }

    @Test func theShapeKeepsItsProportionsInAnyFrame() {
        let box = WordmarkOutline(data: WordmarkOutline.letters).path(in: CGRect(x: 0, y: 0, width: 183.5, height: 368)).cgPath.boundingBoxOfPath
        #expect(close(box, CGRect(x: 0, y: 92, width: 183.5, height: 184)))
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: WordmarkTests.brandFile.path), "brand/wordmark is not merged yet"))
    func theOutlinesMatchTheBrandFile() throws {
        let svg = try String(contentsOf: Self.brandFile, encoding: .utf8)
        let paths = svg.matches(of: /\sd="([^"]*)"/).map { String($0.output.1) }
        #expect(paths == [WordmarkOutline.letters, WordmarkOutline.pane])
    }
}
