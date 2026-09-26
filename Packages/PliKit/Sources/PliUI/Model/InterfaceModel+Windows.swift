import Foundation
import PliCore

/// The menu bar symbol, the windows and the activation policy (spec 8.1), onboarding (spec 8.5), the previews, and
/// the actions the interface hands to the app.
extension InterfaceModel {
    /// The symbol was dragged out of the menu bar: saved as hidden, and Settings opens so Pli can be found again.
    public func menuBarSymbolRemoved() {
        guard editor.settings.general.showInMenuBar else { return }
        editor.setQuietly(\.general.showInMenuBar, to: false)
        if !windows.isOpen(.settings) {
            pane = .general
            windows.open(.settings)
        }
    }

    /// Pli opened again from Finder or Spotlight (spec 8.1).
    public func reopen() {
        windows.open(editor.settings.general.hasCompletedOnboarding ? .settings : .onboarding)
    }

    /// The panel opened: the permission and the displays are read again, so its status line is current.
    public func panelDidOpen() {
        relay.services?.refresh()
    }

    public func settingsDidOpen() {
        relay.services?.refresh()
        if let regular = windows.didOpen(.settings) { relay.services?.setRegularApp(regular) }
        requestPreviewPicture()
        refreshLoginItem()
    }

    /// The window closed: the picture is let go at once, and an answer still on its way is dropped (spec 10.9).
    public func settingsDidClose() {
        if let regular = windows.didClose(.settings) { relay.services?.setRegularApp(regular) }
        pictureRequest += 1
        preview.setPicture(nil)
        renderer.release()
        recorder.cancel()
        banner = nil
    }

    public func onboardingDidOpen() {
        if let regular = windows.didOpen(.onboarding) { relay.services?.setRegularApp(regular) }
    }

    /// Closing the welcome window, finished or not, counts as seen: Show Welcome Again brings it back.
    public func onboardingDidClose() {
        if let regular = windows.didClose(.onboarding) { relay.services?.setRegularApp(regular) }
        editor.setQuietly(\.general.hasCompletedOnboarding, to: true)
    }

    // MARK: - Onboarding (spec 8.5)

    public func onboardingGetStarted() {
        onboarding.getStarted(screenCaptureAllowed: live.screenCaptureAllowed)
    }

    public func onboardingAllow() {
        onboarding.allowRequested()
        relay.services?.requestScreenRecording()
    }

    public func onboardingLater() {
        onboarding.later()
    }

    public func onboardingFinish() {
        if onboarding.openAtLogin { setOpenAtLogin(true) }
        editor.setQuietly(\.general.hasCompletedOnboarding, to: true)
    }

    public func showWelcome() {
        onboarding.restart()
        windows.open(.onboarding)
    }

    // MARK: - Previews

    public func playPreview(_ direction: TimedAnimation.Direction) {
        let start = preview.play(direction, motion: editor.settings.motion, reduceMotion: previewReduceMotion, at: clock())
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(start.duration))
            self?.preview.finishPlayback(start.playback)
        }
    }

    func requestPreviewPicture() {
        pictureRequest += 1
        let request = pictureRequest
        relay.services?.requestPreviewPicture { [weak self] picture in
            guard let self, request == self.pictureRequest, self.windows.isOpen(.settings) else { return }
            self.preview.setPicture(picture)
        }
    }

    // MARK: - Services

    public func playDemo() { relay.services?.playDemo() }
    public func lockWithPli() { relay.services?.lockWithPli() }
    public func checkForUpdates() { relay.services?.checkForUpdates() }
    public func requestScreenRecording() { relay.services?.requestScreenRecording() }
    public func openScreenRecordingSettings() { relay.services?.openScreenRecordingSettings() }
    public func openLoginItemsSettings() { relay.services?.openLoginItemsSettings() }
    public func relaunch() { relay.services?.relaunch() }
    public func quit() { relay.services?.quit() }
    public func open(_ url: URL) { relay.services?.open(url) }

    public var supportsAutomaticUpdateChecks: Bool { relay.services?.supportsAutomaticUpdateChecks ?? false }

    public var automaticallyChecksForUpdates: Bool {
        get { relay.services?.automaticallyChecksForUpdates ?? false }
        set { relay.services?.automaticallyChecksForUpdates = newValue }
    }

    public func refreshLoginItem() {
        if let services = relay.services { loginItem = services.openAtLogin }
    }

    public func setOpenAtLogin(_ enabled: Bool) {
        guard let services = relay.services else { return }
        do {
            try services.setOpenAtLogin(enabled)
            loginProblem = nil
        } catch {
            loginProblem = Strings.loginFailed
        }
        loginItem = services.openAtLogin
    }
}
