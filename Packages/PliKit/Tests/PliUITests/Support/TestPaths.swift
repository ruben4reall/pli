import Foundation

/// Where the package and the repository are, for tests that read source files.
enum TestPaths {
    static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let repositoryRoot = packageRoot.deletingLastPathComponent().deletingLastPathComponent()

    static func sources(in directory: String) -> [(path: String, text: String)] {
        let base = packageRoot.appendingPathComponent(directory)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).map { (url.path, $0) } }
    }

    static func temporaryDirectory(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pli-ui-\(name)-\(UUID().uuidString)", isDirectory: true)
    }
}

/// Test objects; each task's support file adds its own.
enum Fixtures {}
