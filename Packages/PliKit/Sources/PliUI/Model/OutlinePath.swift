import SwiftUI

/// SVG path data for the brand's outlines: the absolute M, L, H, V, C and Z commands that
/// `brand/scripts/logo/build.mjs` writes. Anything else gives no path, so a change in the generator shows up in the
/// tests instead of a half-drawn logo.
enum OutlinePath {
    private enum Token: Equatable {
        case command(Character)
        case number(Double)
    }

    static func parse(_ data: String) -> Path? {
        guard let tokens = tokenize(data) else { return nil }
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character?
        var index = 0

        func numbers(_ count: Int) -> [Double]? {
            guard index + count <= tokens.count else { return nil }
            var values: [Double] = []
            for token in tokens[index..<(index + count)] {
                guard case .number(let value) = token else { return nil }
                values.append(value)
            }
            index += count
            return values
        }

        while index < tokens.count {
            if case .command(let letter) = tokens[index] {
                command = letter
                index += 1
                if letter == "Z" {
                    path.closeSubpath()
                    current = start
                    command = nil
                    continue
                }
            }
            switch command {
            case "M":
                guard let v = numbers(2) else { return nil }
                current = CGPoint(x: v[0], y: v[1])
                start = current
                path.move(to: current)
                command = "L"
            case "L":
                guard let v = numbers(2) else { return nil }
                current = CGPoint(x: v[0], y: v[1])
                path.addLine(to: current)
            case "H":
                guard let v = numbers(1) else { return nil }
                current.x = v[0]
                path.addLine(to: current)
            case "V":
                guard let v = numbers(1) else { return nil }
                current.y = v[0]
                path.addLine(to: current)
            case "C":
                guard let v = numbers(6) else { return nil }
                current = CGPoint(x: v[4], y: v[5])
                path.addCurve(to: current, control1: CGPoint(x: v[0], y: v[1]), control2: CGPoint(x: v[2], y: v[3]))
            default:
                return nil
            }
        }
        return path
    }

    /// Commands and numbers. A minus sign starts a new number; spaces and commas separate them.
    private static func tokenize(_ data: String) -> [Token]? {
        var tokens: [Token] = []
        var number = ""
        func flush() -> Bool {
            guard !number.isEmpty else { return true }
            guard let value = Double(number) else { return false }
            tokens.append(.number(value))
            number = ""
            return true
        }
        for character in data {
            if character.isASCII, character.isLetter {
                guard flush() else { return nil }
                tokens.append(.command(character))
            } else if character == "-" {
                guard flush() else { return nil }
                number = "-"
            } else if character.isASCII, character.isNumber || character == "." {
                number.append(character)
            } else if character == " " || character == "," || character.isNewline {
                guard flush() else { return nil }
            } else {
                return nil
            }
        }
        return flush() ? tokens : nil
    }
}
