import AppKit
import SwiftUI
import Testing
@testable import PliUI

/// The menu bar panel in its states and the menu bar symbol at each pose, in light and dark appearance.
/// Run: PLI_SNAPSHOTS=1 swift test --package-path Packages/PliKit --filter PanelSnapshots
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PLI_SNAPSHOTS"] == "1", "set PLI_SNAPSHOTS=1"))
struct PanelSnapshots {
    @Test func panelStates() async throws {
        let states: [(String, LiveSnapshot)] = [
            ("panel", LiveSnapshot(lidAngle: 104, restAngle: 110)),
            ("panel-permission", LiveSnapshot(lidAngle: 104, restAngle: 110, screenCaptureAllowed: false, permissionRequested: true)),
            ("panel-no-sensor", LiveSnapshot(sensorAvailable: false)),
        ]
        for appearance in SnapshotFixtures.appearances {
            for (name, live) in states {
                let interface = SnapshotFixtures.interface(live: live)
                try await Snapshotter.capture(name, size: CGSize(width: Theme.Layout.panelWidth, height: 1), appearance: appearance, chrome: .panel) {
                    MenuBarPanel(interface: interface)
                }
            }
        }
    }

    @Test func menuBarSymbols() async throws {
        let poses: [MenuBarSymbol.Pose] = [.angle(0), .angle(45), .angle(90), .angle(110), .angle(135), .still]
        for appearance in SnapshotFixtures.appearances {
            try await Snapshotter.capture("menu-bar-symbols", size: CGSize(width: 460, height: 150), appearance: appearance) {
                VStack(spacing: 16) {
                    HStack(spacing: 26) {
                        ForEach(poses, id: \.self) { pose in
                            Image(nsImage: MenuBarSymbol.image(for: pose))
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(poses, id: \.self) { pose in
                            Image(nsImage: MenuBarSymbol.image(for: pose))
                                .resizable()
                                .interpolation(.none)
                                .frame(width: MenuBarSymbol.canvas.width * 3, height: MenuBarSymbol.canvas.height * 3)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.bar)
            }
        }
    }
}
