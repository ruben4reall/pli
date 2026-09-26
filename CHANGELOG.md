# Changelog

Every release of Pli. Versions follow semantic versioning; each one is signed, notarized, and offered to installed copies through Sparkle.

## 0.9.0 (2026-09-27)

The public preview: the iPhone Duo fold on your MacBook, driven by the real angle of the lid. Version 1.0 follows on October 15 and reaches this preview through Sparkle.

### New

- **The fold follows your lid.** As the lid closes, the desktop becomes a pane of frosted glass swinging on the hinge while the picture stays still. Stop halfway and it stops; open again and it unwinds exactly. The screen is black before the display turns off.
- **The unfold on wake.** After sleep with a password, your wallpaper unfolds over the lock screen as you open the lid, and your desktop never shows before you unlock; then the desktop emerges from the frost (0.9 s by default). Without a password, the desktop unfolds with the lid.
- **No false alarms.** Pli learns where your lid rests: a lid left still for 0.8 s at a new angle becomes the new rest position, adjustments of a few degrees never frost the screen, and opening wider never triggers anything.
- **Demo and Animated Lock.** ⌃⌥⌘P plays the fold without touching the lid; ⌃⌥⌘L folds, locks your Mac and unfolds your wallpaper on the lock screen. Both work on every Mac.
- **Every parameter, with a live preview.** Glass (frost, grain, darkening, tint, saturation, edge sheen, prism), perspective and motion, each with its unit, previewed by the real engine. Seven presets: Duo, Subtle, Deep Frost, Night, Crystal, Prism and Cinema. Save your own and share them as `.pli` files.
- **Native, and dark.** A menu bar symbol whose lid follows yours, a dark panel, one dark Settings window (Look, Motion, Triggers, General) where a 3D MacBook moves with your lid and shows the effect on its display, a three-step welcome, full keyboard and VoiceOver support.
- **This Mac.** Settings, General says whether Pli can read your lid, what works on your Mac, and the memory Pli uses right now (about 16 MB while it waits).
- **Considerate.** Follows Reduce Motion, renders lighter in Low Power Mode, never touches external displays, and falls back to Basic mode (the system blur) without the Screen Recording permission.
- **Private.** The picture of your screen stays in memory and is released a second after the lid rests. No telemetry. The only connection is the update check, when you allow it.
- **Updates.** Sparkle checks once a day if you allow it (Pli asks on its second launch), or when you choose *Check for Updates…* in the panel. Updates are EdDSA-signed and notarized.
- **Homebrew.** `brew install --cask ruben4reall/tap/pli`.
