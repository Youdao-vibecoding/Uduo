# Build Uduo

Uduo 1.0.0 targets Apple silicon and macOS 14 or later. A compatible lid angle sensor is needed for the desktop effect; building the application does not establish hardware compatibility.

## Requirements

- An Apple silicon Mac with the full Xcode toolchain installed and its license accepted.
- Swift 5.9 or later and a macOS SDK with SwiftUI, ScreenCaptureKit, Metal, and string-catalog tooling. The app supports a macOS 14.2 SDK build.
- Python 3 for the sensor callback tests. The optional repository checks have additional dependencies described in [CHECKS.md](CHECKS.md).

## Build and package

From the repository root:

```sh
bash scripts/build.sh
open dist/Uduo.app
```

The build script invokes the Swift, Metal, and string-catalog tools directly, includes app resources and the MIT license, and applies an ad-hoc signature. It does not require Sparkle or a Developer ID certificate.

To create a disk image:

```sh
bash scripts/package.sh
```

This creates `dist/Uduo-1.0.0-arm64.dmg` and its `.dmg.sha256` file for version 1.0.0. Pass `--skip-build` to package a freshly built app without recompiling. See [RELEASE.md](RELEASE.md) for artifact checks and the publication process. Building or packaging does not publish a GitHub release.

## Signing and permissions

The supplied build path produces an ad-hoc signed application, not an Apple-notarized release. A successful code-signature verification confirms that the bundle matches its signature; it does not confer Developer ID trust or notarization.

The desktop effect requires Screen Recording permission. Grant it to Uduo through System Settings and restart the application if requested. Rebuilding can change the ad-hoc signature and cause macOS to request permission again. Quit other desktop-folding applications before enabling Uduo so that their overlays do not overlap.

## Source map

| File | Responsibility |
| --- | --- |
| `Sources/LidSensor.swift` | HID sensor readings |
| `Sources/LidMotion.swift` | Angle limits, filtering, direction changes, and fold progress |
| `Sources/LiveDesktop.swift` | Capture, overlay lifecycle, and sleep/wake recovery |
| `Sources/DesktopRenderer.swift` and `Resources/Fold.metal` | Metal desktop rendering |
| `Sources/MainView.swift` and `Sources/FoldShowcase.swift` | Controls and illustrative preview |
| `Sources/AngleRuler.swift` | Mouse, keyboard, and accessibility angle control |
| `Sources/JellyCard.swift` | Bounded decorative card movement |
| `Resources/Localizable.xcstrings` | Interface translations |

The preview's demonstration is separate from live settings. The angle range is 25–120° across saved values, calibration, mouse input, keyboard input, and accessibility input. Reduce Motion disables decorative card movement. The interface does not depend on newer Liquid Glass APIs.

## Validation

```sh
bash Tests/run-motion-tests.sh
bash Tests/run-wake-tests.sh
```

These suites contain 14 motion cases and 34 sensor callback lifecycle checks. They test the state and motion rules, not physical sensor-to-screen latency. Hardware checks for permission changes, lid reversal, sleep/wake, fullscreen Spaces, and external-display use are described in [CHECKS.md](CHECKS.md).

## Upstream

Uduo derives from Softfold v1.16 at commit `cb2009ace60d3a73653d94760b2c7b447a6240fa`. Keep the upstream copyright notices in [LICENSE](LICENSE) when distributing the app or source. See [README.md](README.md) for credits.
