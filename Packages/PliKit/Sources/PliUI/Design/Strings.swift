import Foundation
import PliCore

/// Every word the interface shows (spec 8.6). Each one is a key of `Resources/Localizable.xcstrings`, so another
/// language needs no code change, and views never write a user-facing literal: `StringCatalogTests` checks both.
/// Strings with a value use a format key (`%lld`, `%@`) filled with `String(format:)`.
public enum Strings {
    // MARK: Pli

    public static let appName = String(localized: "Pli", bundle: .module)
    public static let tagline = String(localized: "The iPhone Duo fold, on your MacBook.", bundle: .module)
    public static let signature = String(localized: "Fold the light.", bundle: .module)

    // MARK: Menu bar

    public static let enablePli = String(localized: "Enable Pli", bundle: .module)
    public static let preset = String(localized: "Preset", bundle: .module)
    public static let builtInPresets = String(localized: "Built-in", bundle: .module)
    public static let myPresets = String(localized: "My Presets", bundle: .module)
    public static let demo = String(localized: "Demo", bundle: .module)
    public static let lock = String(localized: "Lock", bundle: .module)
    public static let demoHelp = String(localized: "Fold, hold, then unfold the display.", bundle: .module)
    public static let lockHelp = String(localized: "Fold the display, then lock your Mac.", bundle: .module)
    public static let settingsMenuItem = String(localized: "Settings…", bundle: .module)
    public static let checkForUpdates = String(localized: "Check for Updates…", bundle: .module)
    public static let quitPli = String(localized: "Quit Pli", bundle: .module)
    public static let statusPaused = String(localized: "Paused", bundle: .module)
    public static let statusNoSensor = String(localized: "No lid sensor", bundle: .module)
    public static let statusPermissionNeeded = String(localized: "Permission needed", bundle: .module)
    public static let statusActive = String(localized: "Active", bundle: .module)
    public static let allowScreenRecording = String(localized: "Allow Screen Recording…", bundle: .module)
    public static let relaunchPli = String(localized: "Relaunch Pli", bundle: .module)

    public static func statusActive(lidAt degrees: Int) -> String {
        String(format: String(localized: "Active · lid at %lld°", bundle: .module), degrees)
    }

    public static func menuBarSymbol(lidAt degrees: Int) -> String {
        String(format: String(localized: "Pli, lid at %lld°", bundle: .module), degrees)
    }

    // MARK: Settings window

    public static let settingsWindowTitle = String(localized: "Pli Settings", bundle: .module)
    public static let overview = String(localized: "Overview", bundle: .module)
    public static let style = String(localized: "Style", bundle: .module)
    public static let motion = String(localized: "Motion", bundle: .module)
    public static let triggers = String(localized: "Triggers", bundle: .module)
    public static let general = String(localized: "General", bundle: .module)
    public static let about = String(localized: "About", bundle: .module)
    public static let dismiss = String(localized: "Dismiss", bundle: .module)

    // MARK: Overview

    public static let previewOfScreen = String(localized: "Preview on a picture of your screen", bundle: .module)
    public static let previewOnWallpaper = String(localized: "Preview on your wallpaper", bundle: .module)
    public static let previewAccessibility = String(localized: "Preview of the fold", bundle: .module)
    public static let lidUnknown = String(localized: "Lid angle unknown", bundle: .module)
    public static let lidAngle = String(localized: "Lid angle", bundle: .module)
    public static let simulatedLidAngle = String(localized: "Simulated lid angle", bundle: .module)
    public static let protractorHint = String(localized: "Drag the outlined lid, or use the arrow keys, to preview an angle.", bundle: .module)
    public static let followMyLid = String(localized: "Follow My Lid", bundle: .module)
    public static let playFold = String(localized: "Play Fold", bundle: .module)
    public static let playUnfold = String(localized: "Play Unfold", bundle: .module)
    public static let statusSection = String(localized: "Status", bundle: .module)
    public static let lidSensor = String(localized: "Lid Sensor", bundle: .module)
    public static let sensorAvailable = String(localized: "Available", bundle: .module)
    public static let sensorMissing = String(localized: "Not found on this Mac", bundle: .module)
    public static let screenRecording = String(localized: "Screen Recording", bundle: .module)
    public static let allowed = String(localized: "Allowed", bundle: .module)
    public static let notAllowed = String(localized: "Not Allowed", bundle: .module)
    public static let rendering = String(localized: "Rendering", bundle: .module)
    public static let renderingFull = String(localized: "Full", bundle: .module)
    public static let renderingBasic = String(localized: "Basic", bundle: .module)
    public static let openSystemSettings = String(localized: "Open System Settings", bundle: .module)
    public static let basicModeBanner = String(localized: "Screen Recording is off, so Pli uses Basic mode: the system blur instead of a picture of your screen.", bundle: .module)
    public static let noSensorNote = String(localized: "This Mac has no lid angle sensor. The demo, the animated lock and the unlock reveal still work.", bundle: .module)
    public static let pausedNote = String(localized: "Pli pauses while the built-in display is off.", bundle: .module)

    public static func lidAt(_ degrees: Int) -> String {
        String(format: String(localized: "Lid at %lld°", bundle: .module), degrees)
    }

    public static func marks(rest: Int, start: Int, frosted: Int) -> String {
        String(format: String(localized: "Rest %lld° · Starts at %lld° · Frosted at %lld°", bundle: .module), rest, start, frosted)
    }

    // MARK: Style

    public static let presets = String(localized: "Presets", bundle: .module)
    public static let saveAsPreset = String(localized: "Save as Preset…", bundle: .module)
    public static let saveChanges = String(localized: "Save Changes", bundle: .module)
    public static let reset = String(localized: "Reset", bundle: .module)
    public static let exportPreset = String(localized: "Export…", bundle: .module)
    public static let importPreset = String(localized: "Import…", bundle: .module)
    public static let rename = String(localized: "Rename…", bundle: .module)
    public static let duplicate = String(localized: "Duplicate", bundle: .module)
    public static let delete = String(localized: "Delete…", bundle: .module)
    public static let deleteConfirm = String(localized: "Delete", bundle: .module)
    public static let cancel = String(localized: "Cancel", bundle: .module)
    public static let save = String(localized: "Save", bundle: .module)
    public static let presetName = String(localized: "Name", bundle: .module)
    public static let newPreset = String(localized: "New Preset", bundle: .module)
    public static let renamePreset = String(localized: "Rename Preset", bundle: .module)
    public static let deletePresetMessage = String(localized: "The preset is removed from My Presets.", bundle: .module)
    public static let choosePreset = String(localized: "Choose Preset", bundle: .module)
    public static let importTooLarge = String(localized: "This file is larger than 64 KB, so it is not a Pli preset.", bundle: .module)
    public static let importNotAPreset = String(localized: "This file is not a Pli preset.", bundle: .module)
    public static let importDamaged = String(localized: "This preset file is damaged and cannot be opened.", bundle: .module)
    public static let importNewerVersion = String(localized: "This preset was made by a newer version of Pli. Update Pli to open it.", bundle: .module)
    public static let importUnreadable = String(localized: "Pli could not read this file.", bundle: .module)
    public static let presetSaveFailed = String(localized: "Pli could not save this preset.", bundle: .module)
    public static let presetFileType = String(localized: "Pli Preset", bundle: .module)
    public static let simulatedLid = String(localized: "Simulated Lid", bundle: .module)
    public static let glass = String(localized: "Glass", bundle: .module)
    public static let perspective = String(localized: "Perspective", bundle: .module)
    public static let resetGlass = String(localized: "Reset Glass", bundle: .module)
    public static let resetPerspective = String(localized: "Reset Perspective", bundle: .module)
    public static let requiresScreenRecording = String(localized: "Requires Screen Recording permission", bundle: .module)
    public static let notUsedInBasicMode = String(localized: "Not used in Basic mode", bundle: .module)

    public static func deletePresetTitle(_ name: String) -> String {
        String(format: String(localized: "Delete “%@”?", bundle: .module), name)
    }

    public static func modifiedPreset(_ name: String) -> String {
        String(format: String(localized: "%@ (Modified)", bundle: .module), name)
    }

    public static func copyName(_ name: String) -> String {
        String(format: String(localized: "%@ Copy", bundle: .module), name)
    }

    public static func importedPreset(_ name: String) -> String {
        String(format: String(localized: "Imported “%@”.", bundle: .module), name)
    }

    public static func importedPresets(_ count: Int) -> String {
        String(format: String(localized: "Imported %lld presets.", bundle: .module), count)
    }

    /// Built-in presets show a localized name; a person's own presets keep theirs.
    public static func presetName(_ preset: Preset) -> String {
        switch preset.id {
        case BuiltInPresets.duo.id: String(localized: "Duo", bundle: .module)
        case BuiltInPresets.subtle.id: String(localized: "Subtle", bundle: .module)
        case BuiltInPresets.deepFrost.id: String(localized: "Deep Frost", bundle: .module)
        case BuiltInPresets.night.id: String(localized: "Night", bundle: .module)
        case BuiltInPresets.crystal.id: String(localized: "Crystal", bundle: .module)
        case BuiltInPresets.prism.id: String(localized: "Prism", bundle: .module)
        case BuiltInPresets.cinema.id: String(localized: "Cinema", bundle: .module)
        default: preset.name
        }
    }

    // MARK: Glass and Perspective settings (spec 7.4, glossary in Appendix B)

    public static let frost = String(localized: "Frost", bundle: .module)
    public static let grain = String(localized: "Grain", bundle: .module)
    public static let darkening = String(localized: "Darkening", bundle: .module)
    public static let tint = String(localized: "Tint", bundle: .module)
    public static let tintAmount = String(localized: "Tint Amount", bundle: .module)
    public static let saturation = String(localized: "Saturation", bundle: .module)
    public static let edgeSheen = String(localized: "Edge Sheen", bundle: .module)
    public static let prism = String(localized: "Prism", bundle: .module)
    public static let eyeDistance = String(localized: "Eye Distance", bundle: .module)
    public static let eyeHeight = String(localized: "Eye Height", bundle: .module)
    public static let spatialAnchor = String(localized: "Spatial Anchor", bundle: .module)
    public static let maxTilt = String(localized: "Max Tilt", bundle: .module)
    public static let finalBlackout = String(localized: "Final Blackout", bundle: .module)
    public static let edgeSoftness = String(localized: "Edge Softness", bundle: .module)
    public static let frostHelp = String(localized: "Blur gained as the glass moves away from the picture.", bundle: .module)
    public static let grainHelp = String(localized: "The etched texture of the frosted glass.", bundle: .module)
    public static let darkeningHelp = String(localized: "Light the glass absorbs as it frosts.", bundle: .module)
    public static let tintHelp = String(localized: "The color of the glass, and how strongly it applies.", bundle: .module)
    public static let saturationHelp = String(localized: "Color intensity of the picture seen through the glass.", bundle: .module)
    public static let edgeSheenHelp = String(localized: "A band of light along the far edge of the glass.", bundle: .module)
    public static let prismHelp = String(localized: "Color fringes that grow with the blur.", bundle: .module)
    public static let eyeDistanceHelp = String(localized: "How far you sit from the display. It shapes the perspective.", bundle: .module)
    public static let eyeHeightHelp = String(localized: "Your eye level on the display, measured from the top.", bundle: .module)
    public static let spatialAnchorHelp = String(localized: "How firmly the picture stays still in space while the glass tilts.", bundle: .module)
    public static let maxTiltHelp = String(localized: "The tilt of the glass once the fold is complete.", bundle: .module)
    public static let finalBlackoutHelp = String(localized: "The last part of the travel, where the glass fades to black.", bundle: .module)
    public static let edgeSoftnessHelp = String(localized: "Width of the fade into the black edge.", bundle: .module)

    // MARK: Motion settings

    public static let lidSection = String(localized: "Lid", bundle: .module)
    public static let timingSection = String(localized: "Timing", bundle: .module)
    public static let frostByAngle = String(localized: "Frost by Angle", bundle: .module)
    public static let startAngle = String(localized: "Start Angle", bundle: .module)
    public static let startThreshold = String(localized: "Start Threshold", bundle: .module)
    public static let fullyFrostedAt = String(localized: "Fully Frosted At", bundle: .module)
    public static let curve = String(localized: "Curve", bundle: .module)
    public static let smoothing = String(localized: "Smoothing", bundle: .module)
    public static let settleTime = String(localized: "Settle Time", bundle: .module)
    public static let unlockReveal = String(localized: "Unlock Reveal", bundle: .module)
    public static let demoFold = String(localized: "Demo Fold", bundle: .module)
    public static let demoHold = String(localized: "Demo Hold", bundle: .module)
    public static let demoUnfold = String(localized: "Demo Unfold", bundle: .module)
    public static let lockScreenUnfold = String(localized: "Lock Screen Unfold", bundle: .module)
    public static let resetMotion = String(localized: "Reset Motion", bundle: .module)
    public static let startAngleHelp = String(localized: "The effect never starts above this lid angle.", bundle: .module)
    public static let startThresholdHelp = String(localized: "How far the lid goes below its rest position before the effect starts.", bundle: .module)
    public static let fullyFrostedAtHelp = String(localized: "The lid angle where the fold is complete.", bundle: .module)
    public static let curveHelp = String(localized: "How the frost follows the lid.", bundle: .module)
    public static let smoothingHelp = String(localized: "Hides the sensor’s 1° steps. At 0 ms, the effect follows the raw angle.", bundle: .module)
    public static let settleTimeHelp = String(localized: "How long the lid stays still before its angle becomes the new rest position.", bundle: .module)
    public static let unlockRevealHelp = String(localized: "How long the desktop takes to emerge after you unlock.", bundle: .module)
    public static let demoFoldHelp = String(localized: "How long the demo takes to fold.", bundle: .module)
    public static let demoHoldHelp = String(localized: "How long the demo stays folded.", bundle: .module)
    public static let demoUnfoldHelp = String(localized: "How long the demo takes to unfold.", bundle: .module)
    public static let lockScreenUnfoldHelp = String(localized: "How long the wallpaper takes to unfold on the lock screen.", bundle: .module)

    public static func curveName(_ curve: FoldCurve) -> String {
        switch curve {
        case .linear: String(localized: "Linear", bundle: .module)
        case .smooth: String(localized: "Smooth", bundle: .module)
        case .fastStart: String(localized: "Fast Start", bundle: .module)
        case .slowStart: String(localized: "Slow Start", bundle: .module)
        }
    }

    // MARK: Triggers

    public static let lidClose = String(localized: "Lid Close", bundle: .module)
    public static let lidCloseFootnote = String(localized: "Frost the screen as you close the lid.", bundle: .module)
    public static let unfoldOnLockScreen = String(localized: "Unfold on Lock Screen", bundle: .module)
    public static let usesPrivateAPI = String(localized: "Uses a private macOS API", bundle: .module)
    public static let unavailableOnThisMacOS = String(localized: "Unavailable on this version of macOS", bundle: .module)
    public static let onUnlock = String(localized: "On Unlock", bundle: .module)
    public static let onUnlockFootnote = String(localized: "When the desktop emerges from the frost after you unlock.", bundle: .module)
    public static let animatedLock = String(localized: "Animated Lock", bundle: .module)
    public static let shortcut = String(localized: "Shortcut", bundle: .module)
    public static let recordShortcut = String(localized: "Record Shortcut", bundle: .module)
    public static let typeShortcut = String(localized: "Type a Shortcut", bundle: .module)
    public static let clearShortcut = String(localized: "Clear Shortcut", bundle: .module)
    public static let shortcutRecordingHelp = String(localized: "Press the new shortcut. Esc keeps the current one.", bundle: .module)
    public static let shortcutNeedsModifier = String(localized: "Use ⌘, ⌃ or ⌥ with a key.", bundle: .module)
    public static let shortcutAppCommand = String(localized: "Apps use ⌘ and a letter for their own commands. Add ⌃ or ⌥.", bundle: .module)
    public static let shortcutTaken = String(localized: "Another app already uses this shortcut. Choose another one.", bundle: .module)
    public static let demoFootnote = String(localized: "Fold, hold, then unfold, without moving the lid.", bundle: .module)
    public static let animatedLockFootnote = String(localized: "Fold, lock your Mac, then unfold the wallpaper on the lock screen.", bundle: .module)
    public static let noSensorTriggerNote = String(localized: "This Mac has no lid angle sensor.", bundle: .module)

    public static func shortcutValue(_ combo: String) -> String {
        String(format: String(localized: "Shortcut: %@", bundle: .module), combo)
    }

    public static func shortcutUsedBy(_ name: String) -> String {
        String(format: String(localized: "Already used by %@.", bundle: .module), name)
    }

    public static func unlockModeName(_ mode: UnlockRevealMode) -> String {
        switch mode {
        case .afterLidClose: String(localized: "After Closing the Lid", bundle: .module)
        case .always: String(localized: "Always", bundle: .module)
        case .never: String(localized: "Never", bundle: .module)
        }
    }

    // MARK: General

    public static let startup = String(localized: "Startup", bundle: .module)
    public static let openAtLogin = String(localized: "Open at Login", bundle: .module)
    public static let loginNeedsApproval = String(localized: "Allow Pli in System Settings, Login Items.", bundle: .module)
    public static let openLoginItems = String(localized: "Open Login Items", bundle: .module)
    public static let loginFailed = String(localized: "macOS did not let Pli open at login.", bundle: .module)
    public static let loginUnavailable = String(localized: "Move Pli to the Applications folder to open it at login.", bundle: .module)
    public static let showInMenuBar = String(localized: "Show in Menu Bar", bundle: .module)
    public static let menuBarHiddenNote = String(localized: "While hidden, open Pli again from Finder or Spotlight to see these settings.", bundle: .module)
    public static let renderingFootnote = String(localized: "Automatic uses a picture of your screen when Screen Recording is allowed, and the system blur otherwise.", bundle: .module)
    public static let followReduceMotion = String(localized: "Follow Reduce Motion", bundle: .module)
    public static let reduceMotionFootnote = String(localized: "With Reduce Motion on, the glass frosts without tilting, and timed animations are shorter.", bundle: .module)
    public static let hideCursor = String(localized: "Hide Cursor During the Effect", bundle: .module)
    public static let lighterInLowPower = String(localized: "Lighter Rendering in Low Power Mode", bundle: .module)
    public static let lighterFootnote = String(localized: "A lighter blur and at most 60 frames per second while Low Power Mode is on.", bundle: .module)
    public static let updates = String(localized: "Updates", bundle: .module)
    public static let checkAutomatically = String(localized: "Check Automatically", bundle: .module)
    public static let checkNow = String(localized: "Check Now", bundle: .module)
    public static let permissions = String(localized: "Permissions", bundle: .module)
    public static let showWelcomeAgain = String(localized: "Show Welcome Again", bundle: .module)

    public static func renderingModeName(_ mode: RenderingMode) -> String {
        switch mode {
        case .automatic: String(localized: "Automatic", bundle: .module)
        case .alwaysBasic: String(localized: "Always Basic", bundle: .module)
        }
    }

    // MARK: About

    public static let website = String(localized: "Website", bundle: .module)
    public static let github = String(localized: "GitHub", bundle: .module)
    public static let reportIssue = String(localized: "Report an Issue", bundle: .module)
    public static let credits = String(localized: "Credits", bundle: .module)
    public static let creditOptics = String(localized: "Optical model described by duo-open (MIT) and Duo-animation. Pli’s shader is written from scratch.", bundle: .module)
    public static let creditSkyLight = String(localized: "Surface above the lock screen: technique from SkyLightWindow (MIT).", bundle: .module)
    public static let creditSensor = String(localized: "Lid angle sensor: discovery documented by LidAngleSensor.", bundle: .module)
    public static let notAffiliated = String(localized: "Pli is not affiliated with Apple. iPhone is a trademark of Apple Inc.", bundle: .module)
    public static let license = String(localized: "Made by Ruben Catalao. MIT License.", bundle: .module)

    public static func version(_ short: String, _ build: String) -> String {
        String(format: String(localized: "Version %@ (%@)", bundle: .module), short, build)
    }

    // MARK: Onboarding (spec 8.5)

    public static let welcomeWindowTitle = String(localized: "Welcome to Pli", bundle: .module)
    public static let welcomeSentence = String(localized: "Close your lid, and your desktop folds away into frosted glass.", bundle: .module)
    public static let getStarted = String(localized: "Get Started", bundle: .module)
    public static let permissionTitle = String(localized: "Allow Screen Recording", bundle: .module)
    public static let permissionWhy = String(localized: "Pli turns a picture of your screen into the frosted glass you see as the lid closes.", bundle: .module)
    public static let permissionPromise = String(localized: "The picture stays in memory. It is never written to disk and never leaves your Mac.", bundle: .module)
    public static let permissionMonthly = String(localized: "macOS asks you to confirm this permission about once a month.", bundle: .module)
    public static let permissionLaterNote = String(localized: "Until you allow it, Pli uses Basic mode: the system blur instead of a picture of your screen.", bundle: .module)
    public static let allow = String(localized: "Allow", bundle: .module)
    public static let later = String(localized: "Later", bundle: .module)
    public static let waitingForPermission = String(localized: "Waiting for your answer in System Settings…", bundle: .module)
    public static let permissionGranted = String(localized: "Screen Recording is allowed.", bundle: .module)
    public static let relaunchNote = String(localized: "Allowed it already? Relaunch Pli to finish.", bundle: .module)
    public static let tryItTitle = String(localized: "Try It", bundle: .module)
    public static let tryItInstruction = String(localized: "Close your lid halfway, then open it again.", bundle: .module)
    public static let tryItNoSensor = String(localized: "This Mac has no lid angle sensor. Play the demo to see the fold.", bundle: .module)
    public static let playDemo = String(localized: "Play Demo", bundle: .module)
    public static let openPliAtLogin = String(localized: "Open Pli at login", bundle: .module)
    public static let done = String(localized: "Done", bundle: .module)

    public static func stepOf(_ step: Int, _ count: Int) -> String {
        String(format: String(localized: "Step %lld of %lld", bundle: .module), step, count)
    }

    // MARK: Units (spec 8.6: every value shows its unit)

    public static func degrees(_ number: String) -> String {
        String(format: String(localized: "%@°", bundle: .module), number)
    }

    public static func millimeters(_ number: String) -> String {
        String(format: String(localized: "%@ mm", bundle: .module), number)
    }

    public static func milliseconds(_ number: String) -> String {
        String(format: String(localized: "%@ ms", bundle: .module), number)
    }

    public static func seconds(_ number: String) -> String {
        String(format: String(localized: "%@ s", bundle: .module), number)
    }
}

// MARK: - Noir (the Settings window of 27.09.2026)

extension Strings {
    public static let look = String(localized: "Look", bundle: .module)
    public static let on = String(localized: "On", bundle: .module)
    public static let off = String(localized: "Off", bundle: .module)
    public static let playing = String(localized: "Playing", bundle: .module)
    public static let simulated = String(localized: "Simulated", bundle: .module)
    public static let followingYourLid = String(localized: "Following your lid", bundle: .module)
    public static let noSensorShort = String(localized: "No lid sensor on this Mac", bundle: .module)
    public static let fineTune = String(localized: "Fine-Tune", bundle: .module)
    public static let saveLook = String(localized: "Save Look", bundle: .module)
    public static let shareLookNote = String(localized: "A look saved as a .pli file opens in Pli with a double click.", bundle: .module)
    public static let frostCurveHint = String(localized: "Drag a handle to change where the frost starts or ends.", bundle: .module)
    public static let fineTuneTiming = String(localized: "Fine-Tune Timing", bundle: .module)
    public static let yourLid = String(localized: "Your lid", bundle: .module)
    public static let startAtMyLid = String(localized: "Start at My Lid", bundle: .module)
    public static let frostedAtMyLid = String(localized: "Frosted at My Lid", bundle: .module)
    public static let theLid = String(localized: "The Lid", bundle: .module)
    public static let shortcuts = String(localized: "Shortcuts", bundle: .module)
    public static let quality = String(localized: "Quality", bundle: .module)
    public static let pictureStaysNote = String(localized: "The picture stays in memory, never on disk.", bundle: .module)
    public static let basicModeShort = String(localized: "Without it, Pli frosts the glass without your desktop behind it.", bundle: .module)
    public static let thisMac = String(localized: "This Mac", bundle: .module)
    public static let foldsWithYourLid = String(localized: "Folds with your lid", bundle: .module)
    public static let shortcutsOnly = String(localized: "Shortcuts only", bundle: .module)
    public static let foldsWithYourLidNote = String(localized: "Pli reads your lid's angle: everything works on this Mac.", bundle: .module)
    public static let shortcutsOnlyNote = String(localized: "Pli cannot read a lid on this Mac. The demo, the animated lock and the unlock reveal still work with their shortcuts.", bundle: .module)
    public static let lockScreenShort = String(localized: "Lock screen", bundle: .module)
    public static let works = String(localized: "Works", bundle: .module)
    public static let unavailable = String(localized: "Unavailable", bundle: .module)
    public static let memoryNow = String(localized: "Memory used by Pli right now", bundle: .module)
    public static let megabytesUnit = String(localized: "MB", bundle: .module)
    public static let foldAndLock = String(localized: "Fold and Lock", bundle: .module)
    public static let memoryFoldNote = String(localized: "About 100 MB more during a fold, for a second: the picture of your desktop. Then it goes back.", bundle: .module)

    public static func lidAngleAccessibility(_ degrees: Int) -> String {
        String(format: String(localized: "Lid at %lld degrees", bundle: .module), degrees)
    }

    public static func startsAt(_ degrees: Int) -> String {
        String(format: String(localized: "Starts at %lld°", bundle: .module), degrees)
    }

    public static func frostedAt(_ degrees: Int) -> String {
        String(format: String(localized: "Frosted at %lld°", bundle: .module), degrees)
    }

    /// "0.1% of your 18 GB": the share is formatted here, so the key has no literal percent sign.
    public static func memoryShare(_ percent: Double, _ gigabytes: Int) -> String {
        let share = percent.formatted(.number.precision(.fractionLength(0...1))) + "\u{0025}"
        return String(format: String(localized: "%@ of your %lld GB", bundle: .module), share, gigabytes)
    }
}
