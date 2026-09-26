import PliApp
import PliUI
import SwiftUI

/// Pli's entry point. The app's code lives in the PliKit package (PliApp, PliUI), where `swift test` covers it.
@main
struct PliApplication: App {
    @NSApplicationDelegateAdaptor(PliShellDelegate.self) private var delegate

    var body: some Scene {
        PliScenes(interface: delegate.model.interface)
    }
}
