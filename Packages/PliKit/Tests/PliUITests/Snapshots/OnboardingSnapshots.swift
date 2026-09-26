import AppKit
import SwiftUI
import Testing
@testable import PliUI

/// The three steps of the welcome window, in light and dark appearance, and Try It on a Mac without the sensor.
/// Run: PLI_SNAPSHOTS=1 swift test --package-path Packages/PliKit --filter OnboardingSnapshots
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PLI_SNAPSHOTS"] == "1", "set PLI_SNAPSHOTS=1"))
struct OnboardingSnapshots {
    @Test func steps() async throws {
        for appearance in SnapshotFixtures.appearances {
            for step in OnboardingModel.Step.allCases {
                let interface = SnapshotFixtures.interface(live: LiveSnapshot(lidAngle: 72, restAngle: 110, screenCaptureAllowed: false))
                if step != .welcome { interface.onboardingGetStarted() }
                if step == .tryIt { interface.onboardingLater() }
                try await Snapshotter.capture("onboarding-\(step)", size: Theme.Layout.onboardingSize, appearance: appearance) {
                    OnboardingWindow(interface: interface)
                }
            }
        }
        let noSensor = SnapshotFixtures.interface(live: LiveSnapshot(sensorAvailable: false))
        noSensor.onboardingGetStarted()
        try await Snapshotter.capture("onboarding-tryIt-no-sensor", size: Theme.Layout.onboardingSize, appearance: .aqua) {
            OnboardingWindow(interface: noSensor)
        }
    }
}
