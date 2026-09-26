# Tasks · Pli

> Shared task list. Check what is done, add what you discover.

## To do

- [ ] Owner: run the early hardware checks (R1 to R7) and record the decisions
- [ ] Owner: run the Plan 2 acceptance checklist on a Release build
- [ ] Set LockScreenSpace.absoluteLevel from the R3 result (400 by default, 300 in the brief)
- [ ] Tune Fully Frosted At and Final Blackout from the display-off angle (R2)
- [ ] Measure the idle CPU of the sensor thread against the 0.3% budget; lower restPollingHz if needed
- [ ] Early checks on real hardware (sensor, lock screen space, capture latency)
- [ ] At launch (October 15): revert the site's prelaunch commit (download and GitHub links) and redeploy
- [ ] Owner: run the Plan 3 acceptance checklist
- [ ] Owner: decide on Apple imagery (Pro Black wallpaper, system icons in the Dock) on the public site and in the repository before launch
- [ ] Lower the idle CPU (0.4% of one core measured at rest, budget 0.3%)
- [ ] Release pipeline: notarized DMG, Sparkle updates
- [ ] Acceptance testing on a real MacBook

## Done

- [x] Website live at https://getpli.vercel.app (Vercel project pli, personal scope), page counter wired
- [x] Settings window, menu bar panel, onboarding (Noir design, 3D MacBook, This Mac and live memory)
- [x] Brand: icon (first version, pane on its hinge), wordmark, tokens
- [x] PliCore: motion model, state machine, settings and presets
- [x] PliRender: Metal glass renderer
- [x] PliSystem: sensor, capture, system events, hotkeys, private APIs
- [x] App: overlay surfaces, Basic mode
- [x] Design specification
