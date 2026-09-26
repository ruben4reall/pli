import Foundation

extension Fixtures {
    /// A file on disk with these contents.
    static func pliFile(_ contents: Data, name: String = "Preset.pli") throws -> URL {
        let directory = TestPaths.temporaryDirectory("files")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url)
        return url
    }
}
