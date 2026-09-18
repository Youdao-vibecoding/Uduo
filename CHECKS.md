# Check Uduo

Run the checks that match the change, then verify the built app. A successful compile does not establish sensor compatibility or prove the physical effect feels smooth.

## Motion and lifecycle tests

```sh
bash Tests/run-motion-tests.sh
bash Tests/run-wake-tests.sh
```

The motion suite covers 14 cases, including opening, closing, direction reversal, sensor cadence, and the 25–120° baseline limits. The callback suite checks 34 lifecycle conditions against the gate extracted from `LiveDesktop.swift`, including rejection of readings from an earlier session.

`SWIFTC` and `SDKROOT` may be set to select the compiler and SDK. A full Xcode installation is needed to build the application:

```sh
bash scripts/build.sh
```

## Interface and hardware checks

- Grant Screen Recording, enable the effect, and verify that the active state is distinct from waiting or permission errors.
- Partly close and reopen the lid; pause, reverse direction, and repeat with both pause behaviors.
- Click and drag the angle ruler; confirm its saved value stays within 25–120°. Test arrow keys, Shift + arrow keys, Home, End, and accessibility input.
- Play the illustrated demonstration, return to live readings early, and let a second demonstration finish. Confirm that neither run changes the saved angle.
- Drag card whitespace, then use its buttons, switches, and the ruler. Confirm that decorative motion does not reorder cards or capture control gestures. Repeat with Reduce Motion enabled.
- Close and reopen the controls; quit from the app and launch again. Check Dock and menu bar visibility preferences.
- Check sleep/wake, fullscreen Spaces, and a configuration with an external display. The overlay should wait when the built-in display is unavailable.

Record the hardware and macOS version alongside the observations. Synthetic timing is not physical lid-to-screen latency; do not turn a local measurement into a claim about all Macs.

## Repository checks

The repository includes the upstream tracked-file check tools. Their scope includes text-file policy, Swift and shell linting, Python formatting, configuration parsing, and link validation.

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r scripts/requirements.txt
npm ci
brew install actionlint shellcheck lychee yamllint swift-format
npm run check
npm run check:native
npm run check:links
```

These tools inspect `git ls-files`; newly added files must be included in Git's index to be checked. Tool availability and the CI environment can differ from a developer's Mac. Report the checks actually run, and report failures or unavailable tools explicitly.

The text policy excludes comments and docstrings in code, Markdown comments, and em dashes. It also requires explicit classification of tracked file types. The source tree retains this upstream policy; it is not a claim that every upstream CI check has passed for a release.

Release artifacts need separate checks described in [RELEASE.md](RELEASE.md).
