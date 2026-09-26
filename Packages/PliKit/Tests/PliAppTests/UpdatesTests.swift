import Testing
@testable import PliApp

/// Plays Sparkle: state that changes, then the notification.
@MainActor
private final class FakeUpdater: UpdateChecking {
    var canCheckForUpdates = true
    var automaticallyChecksForUpdates = false
    var pendingUpdateVersion: String?
    var onChange: (@MainActor () -> Void)?
    private(set) var checks = 0

    func checkForUpdates() {
        checks += 1
    }

    func change(_ edit: (FakeUpdater) -> Void) {
        edit(self)
        onChange?()
    }
}

@MainActor @Suite struct UpdatesModelTests {
    @Test func startsFromTheUpdatersState() {
        let updater = FakeUpdater()
        updater.automaticallyChecksForUpdates = true
        updater.pendingUpdateVersion = "1.0.1"
        let model = UpdatesModel(updater: updater)
        #expect(model.canCheckForUpdates && model.automaticallyChecksForUpdates)
        #expect(model.pendingUpdateVersion == "1.0.1")
    }

    @Test func followsTheUpdaterWhenItChanges() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater)
        updater.change { $0.canCheckForUpdates = false }            // a check is running
        #expect(!model.canCheckForUpdates)
        updater.change { $0.automaticallyChecksForUpdates = true }  // the second-launch question was answered
        #expect(model.automaticallyChecksForUpdates)
    }

    @Test func checkingReachesTheUpdaterOnlyWhenItCan() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater)
        model.checkForUpdates()
        #expect(updater.checks == 1)
        updater.change { $0.canCheckForUpdates = false }
        model.checkForUpdates()
        #expect(updater.checks == 1)
    }

    @Test func theSwitchWritesThroughToTheUpdater() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater)
        model.setAutomaticChecks(true)
        #expect(updater.automaticallyChecksForUpdates && model.automaticallyChecksForUpdates)
        model.setAutomaticChecks(false)
        #expect(!updater.automaticallyChecksForUpdates && !model.automaticallyChecksForUpdates)
    }

    @Test func theMenuItemNamesAWaitingUpdate() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater)
        #expect(model.menuTitle == "Check for Updates…")
        updater.change { $0.pendingUpdateVersion = "1.0.1" }
        #expect(model.menuTitle == "Update to Pli 1.0.1…")
        updater.change { $0.pendingUpdateVersion = nil }
        #expect(model.menuTitle == "Check for Updates…")
        #expect(!model.menuTitle.contains("\u{2014}"))
    }

    @Test func aModelLetsGoOfItself() {
        let updater = FakeUpdater()
        weak var released: UpdatesModel?
        do {
            let model = UpdatesModel(updater: updater)
            released = model
        }
        #expect(released == nil)                             // onChange holds the model weakly
        updater.change { $0.canCheckForUpdates = false }     // and a late notification is harmless
    }
}

@MainActor @Suite struct NoUpdatesTests {
    @Test func aBuildWithoutAnUpdaterNeverChecks() {
        let none = NoUpdates()
        #expect(!none.canCheckForUpdates && !none.automaticallyChecksForUpdates && none.pendingUpdateVersion == nil)
        none.automaticallyChecksForUpdates = true
        #expect(!none.automaticallyChecksForUpdates)
        let model = UpdatesModel(updater: none)
        model.checkForUpdates()
        model.setAutomaticChecks(true)
        #expect(!model.canCheckForUpdates && !model.automaticallyChecksForUpdates)
    }

    @Test func thePackagesDelegateHasNoUpdater() {
        #expect(PliAppDelegate().makeUpdater() is NoUpdates)
    }
}
