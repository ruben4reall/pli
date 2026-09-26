# Contributing to Pli

Thank you for looking at this. Pli is small, native and careful; contributions that keep it that way are welcome.

## The promises that cannot change

- The picture of your screen stays in memory. It is never written to disk, never sent anywhere, and released a second after the lid rests.
- No telemetry, no analytics, no crash reporter. The only network code is Sparkle's update check, in `App/SparkleUpdater.swift`.
- Private macOS functions are looked up in one file, `Packages/PliKit/Sources/PliSystem/PrivateAPI.swift`, and a missing one turns its feature off: nothing crashes.
- External displays are never touched, and the overlay never takes a click or a key.

Guard tests (`GuardTests`, `UpdaterConfigurationTests`) check these at every run. A pull request that breaks one will be closed, however good the code is.

## How to propose a change

1. Open an issue first for anything bigger than a typo, so we agree on the direction before you spend time.
2. Fork the repository and branch from `main`.
3. Write a test that fails, then the code that makes it pass: `swift test --package-path Packages/PliKit`. The release scripts have their own tests (`scripts/tests/run.sh`), and so does the website (`cd site && node --test tests/*.test.mjs`).
4. Build the app: `brew install xcodegen`, then `scripts/build.sh`. Run it with `PLI_LID_SIMULATOR=1` to move a simulated lid from the Debug menu.
5. Open a pull request against `main`. Say what changes for a person using Pli, not only in the code. CI runs the tests and builds the app.

## Style

- Swift 6 with strict concurrency; anything that touches AppKit is `@MainActor`.
- Every user-facing string goes through the String Catalog (`String(localized:)`), in plain English, with its unit (°, mm, ms, s, %).
- Native controls first; custom drawing only for the preview and the protractor.
- Colors and type come from the brand tokens (`docs/brand/BRAND.md`).
- No em dashes in visible text.
- One change per commit, the message in the imperative.

## Security

See [SECURITY.md](SECURITY.md). Please do not open a public issue for a vulnerability.
