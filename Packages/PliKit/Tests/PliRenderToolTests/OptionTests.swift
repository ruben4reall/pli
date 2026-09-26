import Testing
@testable import pli_render

@Suite struct OptionTests {
    @Test func degenerateOptionsAreRefused() {
        let refused: [[String]] = [
            ["--width-mm", "0"], ["--width-mm", "-3"], ["--width-mm", "wide"], ["--width-mm", "inf"],
            ["--steps", ""], ["--steps", "junk"], ["--steps", "0,junk,1"], ["--steps", "0,,1"], ["--steps", "nan"],
        ]
        for extra in refused {
            #expect(throws: ToolError.self, "\(extra)") { try parse(["--test-pattern", "64x48", "/tmp/pli-frames"] + extra) }
        }
    }

    @Test func validOptionsParse() throws {
        let options = try parse(["--test-pattern", "64x48", "/tmp/pli-frames", "--steps", "0, 0.5,1", "--width-mm", "345.6", "--preset", "prism"])
        #expect(options.steps == [0, 0.5, 1])
        #expect(options.widthMM == 345.6)
        #expect(options.preset.id == "prism")
    }
}
