import Foundation
import PliCore

extension Fixtures {
    /// A preset store in a fresh temporary folder.
    static func store() -> PresetStore {
        PresetStore(directory: TestPaths.temporaryDirectory("presets"))
    }
}
