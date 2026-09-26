import Foundation
import PliCore
@testable import PliUI

/// Records what the interface asks of the app.
@MainActor final class FakeServices: InterfaceServices {
    private(set) var applied: [(settings: PliSettings, persist: Bool)] = []
    private(set) var calls: [String] = []
    private(set) var suspensions: [Bool] = []
    private(set) var regularApp: [Bool] = []
    private(set) var pictureRequests: [@MainActor (PreviewPicture?) -> Void] = []
    var openAtLogin: LoginItemState = .disabled
    var loginError: Error?
    var supportsAutomaticUpdateChecks = false
    var automaticallyChecksForUpdates = false

    func apply(_ settings: PliSettings, persist: Bool) { applied.append((settings, persist)) }
    func refresh() { calls.append("refresh") }
    func playDemo() { calls.append("playDemo") }
    func lockWithPli() { calls.append("lockWithPli") }
    func requestScreenRecording() { calls.append("requestScreenRecording") }
    func openScreenRecordingSettings() { calls.append("openScreenRecordingSettings") }
    func relaunch() { calls.append("relaunch") }
    func openLoginItemsSettings() { calls.append("openLoginItemsSettings") }
    func checkForUpdates() { calls.append("checkForUpdates") }
    func suspendShortcuts(_ suspended: Bool) { suspensions.append(suspended) }
    func setRegularApp(_ regular: Bool) { regularApp.append(regular) }
    func open(_ url: URL) { calls.append("open \(url.absoluteString)") }
    func quit() { calls.append("quit") }

    func setOpenAtLogin(_ enabled: Bool) throws {
        if let loginError { throw loginError }
        openAtLogin = enabled ? .enabled : .disabled
    }

    func requestPreviewPicture(_ completion: @escaping @MainActor (PreviewPicture?) -> Void) {
        pictureRequests.append(completion)
    }
}
