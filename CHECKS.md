# Check Uduo

Run the checks that match the change, then verify the built app. A successful compile does not establish sensor compatibility or prove the physical effect feels smooth.

## Motion and lifecycle tests

```sh
make test
```

This runs `Tests/run-motion-tests.sh` and `Tests/run-wake-tests.sh`. The motion suite covers 14 cases, including opening, closing, direction reversal, sensor cadence, and the 25–120° baseline limits. The callback suite checks 34 lifecycle conditions against the gate extracted from `LiveDesktop.swift`, including rejection of readings from an earlier session.

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

## Current CI checks

[The workflow](.github/workflows/checks.yml) runs on `macos-26` with Python 3.13 and read-only repository permissions. Its required steps are the tracked-file policy check, shell syntax checks, both test suites, and an ad-hoc signed build and DMG package. It does not publish release artifacts.

To run the same checks from the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r scripts/requirements.txt
python3 scripts/check.py policy
for script in scripts/*.sh Tests/*.sh; do
  bash -n "$script"
done
make test
CODE_SIGN_IDENTITY=- make package
```

The policy check inspects `git ls-files`; newly added files must be included in Git's index to be checked. The loop checks every shell file separately. Passing several filenames to a single `bash -n` invocation would check only the first script.

The text policy excludes comments and docstrings in code, Markdown comments, and em dashes. It also validates supported resource signatures and configuration formats, and requires explicit classification of tracked file types.

Additional upstream lint and link-checking tools remain in the repository, but they are optional and are not part of this CI workflow. Node, npm, and Homebrew check tools are not required for the checks above. Report the checks actually run, and report failures or unavailable tools explicitly.

Release artifacts need separate checks described in [RELEASE.md](RELEASE.md).
