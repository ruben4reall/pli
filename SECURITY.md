# Security

Pli runs only on your Mac. This page says what it touches, what it never does, how those promises are checked, and how to report a problem.

## What it touches

| Where | What Pli does there |
| --- | --- |
| Your built-in display | While you lower the lid (and for the demo and the animated lock), Pli takes one picture of the built-in display with ScreenCaptureKit, without the cursor and without Pli's own windows. The picture lives in GPU memory only: it is never written to disk or sent anywhere, and it is released a second after the lid rests. The lock screen surface never receives it (the compiler enforces it): above the lock screen, Pli only shows your wallpaper. |
| The lid angle sensor | Read only, through IOKit HID, without any permission. Pli opens the angle interface and nothing else: not the accelerometer, the gyroscope or the light sensor that share its device. |
| Your wallpaper | Read, to draw the unfold on the lock screen and the settings preview. |
| Preferences (`ch.rubencatalao.pli`) | Your settings, as one JSON value. An unreadable value falls back to the defaults. |
| `~/Library/Application Support/Pli/Presets` | Your presets, one JSON file each. A file that cannot be read is renamed `.corrupt`, never deleted. `.pli` files you import are limited to 64 KB, their values clamped to their ranges and their names to 60 characters. |
| Login Items | Only if you choose *Open at Login*, through `SMAppService`; it shows in System Settings, General, Login Items. |
| Keyboard shortcuts | ⌃⌥⌘P and ⌃⌥⌘L (or yours) are registered with `RegisterEventHotKey`. No event tap, no Accessibility permission, no keyboard monitoring. |
| The system log | Numbers and states (angles, durations, phases), under the subsystem `ch.rubencatalao.pli`. Never an image, a window title or a path. |
| Private macOS functions | Three features use them, listed with their reasons in the README: the unfold above the lock screen (SkyLight), the animated lock (login.framework) and hiding the cursor during the effect. |
| The network | Only Sparkle, and only when you allow automatic checks (Pli asks on its second launch) or choose *Check for Updates…*: it reads `https://getpli.vercel.app/appcast.xml` and downloads updates from GitHub Releases. The request says which version of Pli asks, like any update check; Sparkle's system profile is off. |

## What it never does

- No telemetry, analytics or crash reports. No account.
- No picture of your screen saved or sent anywhere.
- No network connection other than the update check above.
- No change to external displays, and no click or key taken: the overlay ignores the mouse and never becomes the key window.

## How the promises are checked

- Guard tests run at every build: no networking API in the shipped code, Sparkle only in `App/SparkleUpdater.swift`, Sparkle as the one external dependency, no analytics library, no image-writing API outside the developer tool, private functions only in `PrivateAPI.swift`, and a lock screen surface that never names a desktop capture.
- `UpdaterConfigurationTests` check the update settings: an HTTPS feed, an EdDSA key, a signed feed, verification before extraction, automatic checks offered rather than imposed, no system profile.
- Updates are signed twice: with Pli's EdDSA key, which Sparkle checks before it opens the disk image, and with a Developer ID, notarized by Apple.
- Releases are built with the hardened runtime and notarized, and the disk image carries Apple's ticket.

## Reporting a vulnerability

If you find a way in which Pli could leak a picture of your screen, connect somewhere it should not, run something it should not, or break one of the promises above, please report it privately: use "Report a vulnerability" on the Security tab of the repository. You will get an answer within a week, and a fix before any public disclosure.
