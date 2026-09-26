# Tasks · Pli

> Shared task list. Check what is done, add what you discover.

## To do

- [ ] Each later release: raise MARKETING_VERSION, add its CHANGELOG section, run the signed release, then scripts/publish.sh release, tap and site
- [ ] Watch Sparkle's releases and raise exactVersion in project.yml when one ships
- [ ] Upload the social preview (docs/brand/social-preview.png) in the repository settings
- [ ] Owner: run the early hardware checks (R1 to R7) and record the decisions
- [ ] Owner: run the Plan 2 acceptance checklist on a Release build
- [ ] Set LockScreenSpace.absoluteLevel from the R3 result (400 by default, 300 in the brief)
- [ ] Tune Fully Frosted At and Final Blackout from the display-off angle (R2)
- [ ] Measure the idle CPU of the sensor thread against the 0.3% budget; lower restPollingHz if needed
- [ ] Early checks on real hardware (sensor, lock screen space, capture latency)
- [ ] Owner: run the Plan 3 acceptance checklist
- [ ] Owner: decide on Apple imagery (Pro Black wallpaper, system icons in the Dock) on the public site and in the repository before launch
- [ ] Lower the idle CPU (0.4% of one core measured at rest, budget 0.3%)
- [ ] Acceptance testing on a real MacBook

## Done

- [x] Pli 1.0.0 for everyone: notarized universal release, Sparkle update from 0.9.0, Homebrew, website (2026-09-27)
- [x] Pli 0.9.0 public preview: notarized release, Sparkle updates, Homebrew tap, website with downloads (2026-09-27)
- [x] Release pipeline: notarized DMG, Sparkle updates
- [x] Website live at https://getpli.vercel.app (Vercel project pli, personal scope), page counter wired
- [x] Settings window, menu bar panel, onboarding (Noir design, 3D MacBook, This Mac and live memory)
- [x] Brand: icon (first version, pane on its hinge), wordmark, tokens
- [x] PliCore: motion model, state machine, settings and presets
- [x] PliRender: Metal glass renderer
- [x] PliSystem: sensor, capture, system events, hotkeys, private APIs
- [x] App: overlay surfaces, Basic mode
- [x] Design specification
