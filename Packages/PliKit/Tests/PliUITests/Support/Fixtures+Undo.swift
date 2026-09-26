import Foundation

extension Fixtures {
    /// An undo manager that groups only what the editor groups, as a window's does one event at a time.
    @MainActor static func undoManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }
}
