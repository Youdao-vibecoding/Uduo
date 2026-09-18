# Uduo 1.0.0

Your MacBook moves. Your desktop follows.

Uduo turns your MacBook's lid movement into a desktop fold that works in both directions. Lower the screen to fold, blur, and darken the desktop; lift it to bring everything back.

## In this release

- Continuous closing and opening, with an option to keep the fold when you pause.
- A live illustrated preview and a one-cycle demonstration that leaves your settings untouched.
- A 25–120° starting-angle ruler with click, drag, arrow-key, Shift-arrow, Home, and End controls. Changes save immediately.
- A light preview panel, dark controls, and yellow accents. Cards give slightly when dragged and spring back; Reduce Motion disables that movement.
- Dock and menu bar options, a global Control + Option + Shift + H shortcut, and a visible quit action.
- No telemetry, automatic updates, or automatic login-item registration.

## Download and setup

Download the DMG and drag **Uduo** into **Applications**. Launch it, allow Screen Recording, and restart the app if macOS asks. The permission is used to render the live effect; desktop frames stay in memory and are neither saved nor uploaded.

Requires **macOS 14+**, an **Apple silicon MacBook**, and a **compatible lid angle sensor**. Some Apple silicon MacBooks do not expose the required sensor. The effect uses the built-in display.

## Signing and known limits

This release uses an **ad-hoc signature**. It is **not Developer ID signed or notarized by Apple**, so macOS may block the first launch. If you trust the release, use the system's Privacy & Security controls described in [Apple's opening instructions](https://support.apple.com/en-nz/guide/mac-help/mh40616/mac).

Reinstalling or replacing an ad-hoc signed build may require granting Screen Recording again. Updates are manual. There is no new high-frame-rate mode, and sensor behavior varies by hardware.

The illustrated preview is an effect demonstration, not a captured desktop or a performance measurement. Quit other desktop-folding apps before enabling Uduo.

## Credits

Uduo is an independent MIT-licensed derivative of [Softfold](https://github.com/ReffWu/softfold) by Reff Wu, which began as a fork of [Hinge](https://github.com/Noveum/hinge) by Noveum.ai. Upstream copyright notices are retained.

If you enjoy the effect, a star helps others find the project. Compatibility reports and small, focused contributions are welcome.
