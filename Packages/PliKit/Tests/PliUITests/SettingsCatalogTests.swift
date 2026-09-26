import Foundation
import PliCore
import Testing
@testable import PliUI

@MainActor @Suite struct SettingsCatalogTests {
    let english = Locale(identifier: "en_US")

    @Test func frostAndDarkeningReadAsAPercentageOfTheirRange() {
        #expect(SettingsCatalog.frost.text(0.09, locale: english) == "36%")
        #expect(SettingsCatalog.frost.text(0.25, locale: english) == "100%")
        #expect(SettingsCatalog.darkening.text(0.05, locale: english) == "25%")
        #expect(SettingsCatalog.darkening.text(0, locale: english) == "0%")
    }

    @Test func everyOtherValueShowsItsOwnUnit() {
        #expect(SettingsCatalog.grain.text(0.3, locale: english) == "30%")
        #expect(SettingsCatalog.saturation.text(2, locale: english) == "200%")
        #expect(SettingsCatalog.eyeDistance.text(450, locale: english) == "450 mm")
        #expect(SettingsCatalog.edgeSoftness.text(2.5, locale: english) == "2.5 mm")
        #expect(SettingsCatalog.maxTilt.text(50, locale: english) == "50°")
        #expect(SettingsCatalog.smoothing.text(45, locale: english) == "45 ms")
        #expect(SettingsCatalog.settleTime.text(0.8, locale: english) == "0.8 s")
        #expect(SettingsCatalog.demoHold.text(0.35, locale: english) == "0.35 s")
        #expect(SettingsCatalog.demoUnfold.text(1.0, locale: english) == "1.0 s")
    }

    @Test func voiceOverHearsUnitsInFull() {
        #expect(SettingsCatalog.eyeDistance.spoken(450, locale: english) == "450 millimeters")
        #expect(SettingsCatalog.maxTilt.spoken(50, locale: english) == "50 degrees")
        #expect(SettingsCatalog.smoothing.spoken(45, locale: english) == "45 milliseconds")
        #expect(SettingsCatalog.settleTime.spoken(0.8, locale: english) == "0.8 seconds")
        #expect(SettingsCatalog.frost.spoken(0.09, locale: english) == "36%")
    }

    @Test func valuesSnapToTheSliderGridInsideTheRange() {
        #expect(SettingsCatalog.eyeDistance.validated(452.4) == 450)
        #expect(SettingsCatalog.eyeDistance.validated(10_000) == 900)
        #expect(SettingsCatalog.settleTime.validated(0.84) == 0.8)
        #expect(SettingsCatalog.startAngle.validated(-4) == 40)
        #expect(SettingsCatalog.frost.validated(.nan) == 0)
        #expect(SettingsCatalog.demoHold.validated(.infinity) == 0)
    }

    @Test func rangesComeFromTheEngine() {
        #expect(SettingsCatalog.startAngle.range == 40...130)
        #expect(SettingsCatalog.demoFold.range == 0.3...2)
        #expect(SettingsCatalog.demoHold.range == 0...1)
        #expect(SettingsCatalog.finalBlackout.range == 0...0.3)
    }

    /// A slider must not move a built-in preset's value the first time it is touched.
    @Test func everyBuiltInValueSitsOnItsSliderGrid() {
        for preset in BuiltInPresets.all {
            var settings = PliSettings.default
            settings.glass = preset.glass
            settings.motion = preset.motion
            for setting in SettingsCatalog.all {
                let value = settings[keyPath: setting.keyPath]
                #expect(abs(setting.validated(value) - value) < 1e-9, "\(preset.id).\(setting.id) = \(value) is off the grid")
            }
        }
    }

    /// Spec 7.3: Grain, the Perspective group but Final Blackout, Prism, Edge Sheen, Tint and Saturation need a capture.
    @Test func basicModeDimsExactlyTheSettingsOfSpec73() {
        let dimmed = Set(SettingsCatalog.all.filter(\.needsCapture).map(\.id))
        #expect(dimmed == ["grain", "tintAmount", "saturation", "edgeSheen", "prism", "eyeDistanceMM", "eyeHeight",
                           "spatialAnchor", "maxTiltDegrees", "edgeSoftnessMM"])
    }

    /// The sliders have no `step:` (it would draw a tick per step): the arrow keys move 5% of the range, so every grid
    /// step must be at most that, or a keyboard move would snap back to where it started.
    @Test func anArrowKeyMoveAlwaysReachesTheNextValue() {
        for setting in SettingsCatalog.all {
            let span = setting.range.upperBound - setting.range.lowerBound
            #expect(setting.step <= span * 0.05 + 1e-12, "\(setting.id): step \(setting.step) is over 5% of its range")
            #expect(setting.validated(setting.range.lowerBound + span * 0.05) > setting.range.lowerBound, "\(setting.id)")
        }
    }

    @Test func idsAreUnique() {
        let ids = SettingsCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
