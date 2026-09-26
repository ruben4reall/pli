import AppKit
import PliCore
import SwiftUI
import Testing
@testable import PliUI

/// Every tab of the Settings window at its own height (Noir: dark whatever the system appearance), with the lid
/// followed, simulated, without a sensor, and without the Screen Recording permission.
/// Run: PLI_SNAPSHOTS=1 swift test --package-path Packages/PliKit --filter SettingsWindowSnapshots
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PLI_SNAPSHOTS"] == "1", "set PLI_SNAPSHOTS=1"))
struct SettingsWindowSnapshots {
    static func fitting(_ interface: InterfaceModel) -> CGSize {
        NSHostingView(rootView: SettingsWindow(interface: interface)).fittingSize
    }

    @Test func everyTab() async throws {
        for pane in SettingsPane.allCases {
            let interface = SnapshotFixtures.interface(live: LiveSnapshot(lidAngle: 62, restAngle: 110))
            interface.pane = pane
            interface.preview.setFollowLid(true)
            try await Snapshotter.capture("noir-\(pane.rawValue)", size: Self.fitting(interface), appearance: .darkAqua) {
                SettingsWindow(interface: interface)
            }
        }
    }

    @Test func lookAtSeveralAngles() async throws {
        for angle in [110.0, 75, 40] {
            let interface = SnapshotFixtures.interface()
            interface.preview.setGhost(angle: angle)
            try await Snapshotter.capture("noir-look-\(Int(angle))", size: Self.fitting(interface), appearance: .darkAqua) {
                SettingsWindow(interface: interface)
            }
        }
    }

    @Test func withoutSensorOrPermission() async throws {
        let interface = SnapshotFixtures.interface(live: LiveSnapshot(lidAngle: nil, restAngle: nil, sensorAvailable: false,
                                                                      screenCaptureAllowed: false))
        for pane in [SettingsPane.look, .general] {
            interface.pane = pane
            try await Snapshotter.capture("noir-\(pane.rawValue)-limited", size: Self.fitting(interface), appearance: .darkAqua) {
                SettingsWindow(interface: interface)
            }
        }
    }
}

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PLI_SNAPSHOTS"] == "1", "set PLI_SNAPSHOTS=1"))
struct SheetSnapshots {
    @Test func fineTuneAndTiming() async throws {
        let interface = SnapshotFixtures.interface()
        try await Snapshotter.capture("noir-fine-tune", size: CGSize(width: 600, height: 640), appearance: .darkAqua) {
            FineTuneSheet(interface: interface)
        }
        try await Snapshotter.capture("noir-timing", size: CGSize(width: 600, height: 640), appearance: .darkAqua) {
            TimingSheet(interface: interface)
        }
    }
}
