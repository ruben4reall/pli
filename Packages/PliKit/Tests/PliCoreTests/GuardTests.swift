import Foundation
import Testing

/// Source-level rules from spec 10.9 and 12.3. A failure here is a broken promise, not a style nit.
@Suite struct GuardTests {
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// The repository: the app shell lives in `App/`, two levels above the package.
    static let repositoryRoot = packageRoot.deletingLastPathComponent().deletingLastPathComponent()
    static let privateAPIFile = "/Sources/PliSystem/PrivateAPI.swift"

    static func sources(in directory: String, under root: URL = packageRoot) -> [(path: String, text: String)] {
        let base = root.appendingPathComponent(directory)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).map { (url.path, $0) } }
    }

    /// Shipped code: the package's sources and the app shell.
    static var shipped: [(path: String, text: String)] {
        sources(in: "Sources") + sources(in: "App", under: repositoryRoot)
    }

    @Test func thereAreSourcesToCheck() {
        #expect(Self.sources(in: "Sources").count > 10)
    }

    /// Every import declaration in `text` other than a plain `import Foundation`, whatever its attributes or
    /// access level (`@preconcurrency public import Darwin` counts).
    static func importsOtherThanFoundation(in text: String) -> [String] {
        let modifiers: Set<Substring> = ["public", "package", "internal", "fileprivate", "private"]
        return text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            let words = line.split(separator: " ")
            guard let index = words.firstIndex(of: "import"),
                  words[..<index].allSatisfy({ $0.hasPrefix("@") || modifiers.contains($0) }) else { return nil }
            return line == "import Foundation" ? nil : line
        }
    }

    @Test func theImportCheckSeesEveryKindOfImport() {
        let text = """
        import Foundation
        import Combine
        @preconcurrency import Darwin
        public import simd
        import struct os.OSAllocatedUnfairLock
        // import AppKit
        let important = "import AppKit"
        """
        #expect(Self.importsOtherThanFoundation(in: text) == [
            "import Combine", "@preconcurrency import Darwin", "public import simd", "import struct os.OSAllocatedUnfairLock",
        ])
    }

    @Test func coreStaysFoundationOnly() {
        let files = Self.sources(in: "Sources/PliCore")
        #expect(files.contains { $0.text.contains("import Foundation") })
        for file in files {
            #expect(Self.importsOtherThanFoundation(in: file.text).isEmpty, "\(file.path) imports more than Foundation")
        }
    }

    @Test func noNetworkingAnywhere() {
        for file in Self.shipped {
            for forbidden in ["URLSession", "NWConnection", "import Network", "NSURLConnection", "CFNetwork", "WebSocket"] {
                #expect(!file.text.contains(forbidden), "\(file.path) contains \(forbidden)")
            }
        }
    }

    @Test func onlyTheDeveloperToolWritesImages() {
        for file in Self.shipped where !file.path.contains("/pli-render/") {
            for forbidden in ["CGImageDestination", "tiffRepresentation", "pngData", "representation(using"] {
                #expect(!file.text.contains(forbidden), "\(file.path) writes images: \(forbidden)")
            }
        }
    }

    @Test func privateSymbolsAreResolvedInOneFile() {
        #expect(Self.sources(in: "Sources/PliSystem").contains { $0.path.hasSuffix(Self.privateAPIFile) })
        for file in Self.shipped where !file.path.hasSuffix(Self.privateAPIFile) {
            for forbidden in ["dlopen", "dlsym", "PrivateFrameworks", "RTLD_"] {
                #expect(!file.text.contains(forbidden), "\(file.path) contains \(forbidden)")
            }
        }
    }

    /// The lock screen surface shows the wallpaper and nothing else (spec 5.2, 10.6): its file never names a capture.
    @Test func theLockScreenSurfaceNeverSeesTheDesktop() throws {
        let file = try #require(Self.sources(in: "Sources/PliApp").first { $0.path.hasSuffix("/LockScreenSurface.swift") })
        for forbidden in ["DesktopSnapshot", "ScreenSnapshotter", "ScreenCaptureKit", "SCScreenshotManager"] {
            #expect(!file.text.contains(forbidden), "LockScreenSurface.swift mentions \(forbidden)")
        }
    }

    /// The only shipped file allowed to use Sparkle, the app's only network client (spec 10.9, 12.3).
    static let updaterFile = "/App/SparkleUpdater.swift"

    @Test func onlyTheUpdaterFileUsesSparkle() {
        #expect(Self.shipped.contains { $0.path.hasSuffix(Self.updaterFile) })
        for file in Self.shipped where !file.path.hasSuffix(Self.updaterFile) {
            for forbidden in ["import Sparkle", "SPUUpdater", "SPUStandardUpdaterController", "SPUStandardUserDriver", "SUAppcast", "SUUpdater"] {
                #expect(!file.text.contains(forbidden), "\(file.path) contains \(forbidden)")
            }
        }
    }

    /// One external dependency, Sparkle (spec 10.1): the package depends on nothing, the app on PliKit and Sparkle.
    @Test func theOnlyExternalDependencyIsSparkle() throws {
        let manifest = try String(contentsOf: Self.packageRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(!manifest.contains(".package("), "PliKit must not depend on other packages")
        let project = try String(contentsOf: Self.repositoryRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        let lines = project.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex(of: "packages:"))
        let names = lines[(start + 1)...]
            .prefix { $0.hasPrefix("  ") || $0.isEmpty }
            .filter { $0.hasPrefix("  ") && !$0.hasPrefix("   ") && $0.hasSuffix(":") }
            .map { String($0.trimmingCharacters(in: .whitespaces).dropLast()) }
        #expect(names.sorted() == ["PliKit", "Sparkle"])
        #expect(project.contains("url: https://github.com/sparkle-project/Sparkle"))
    }

    /// No analytics library (spec 12.3).
    @Test func noAnalyticsLibrary() {
        for file in Self.shipped {
            for library in ["Firebase", "Crashlytics", "Mixpanel", "Amplitude", "Segment", "TelemetryDeck", "TelemetryClient",
                            "Sentry", "Bugsnag", "PostHog", "AppCenter", "Countly"] {
                #expect(!file.text.contains("import \(library)"), "\(file.path) imports \(library)")
            }
        }
    }
}
