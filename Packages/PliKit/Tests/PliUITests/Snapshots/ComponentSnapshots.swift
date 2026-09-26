import AppKit
import SwiftUI
import Testing
@testable import PliUI

/// The shared rows and the live preview, in light and dark appearance.
/// Run: PLI_SNAPSHOTS=1 swift test --package-path Packages/PliKit --filter ComponentSnapshots
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PLI_SNAPSHOTS"] == "1", "set PLI_SNAPSHOTS=1"))
struct ComponentSnapshots {
    @Test func rowsAndPreview() async throws {
        for appearance in SnapshotFixtures.appearances {
            let interface = SnapshotFixtures.interface()
            try await Snapshotter.capture("components", size: CGSize(width: 640, height: 640), appearance: appearance) {
                Form {
                    Section { PreviewStage(interface: interface, maxHeight: 220) }
                    Section {
                        SettingSlider(setting: SettingsCatalog.frost, editor: interface.editor)
                        SettingSlider(setting: SettingsCatalog.eyeDistance, editor: interface.editor)
                        SettingSlider(setting: SettingsCatalog.settleTime, editor: interface.editor, disabled: true)
                        TintRow(editor: interface.editor)
                    } footer: {
                        ResetFooter(title: Strings.resetGlass, note: Strings.requiresScreenRecording) {}
                    }
                    Section { BannerRow(banner: Banner(text: Strings.importedPreset("Evening"), isProblem: false)) {} }
                }
                .formStyle(.grouped)
            }
        }
    }
}
