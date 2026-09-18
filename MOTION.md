# How Uduo follows the lid

Uduo reads the lid angle, turns that input into continuous fold progress, and renders a captured desktop on the built-in display. The interface preview has its own illustration and demonstration state.

## Angle and direction

`LidSensor.swift` reads the compatible sensor through IOKit HID. Its report handling is derived from Softfold and the [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) reference. Available precision and refresh cadence depend on the hardware.

The user chooses the angle at which folding starts. `LidMotion.swift` bounds that baseline to 25–120° when loading a preference, setting a value, or calibrating. A small noise band limits jitter; estimated velocity and a damped second-order response smooth changes between readings. When the sensor confirms a reversal, the previous direction's velocity estimates are cleared while the visual position stays continuous.

The default behavior retains the fold when the lid stops. Opening the lid reverses it. If the user turns off **Keep fold when still**, the alternative behavior lets the desktop sharpen after a pause. Restoring capture or recovering a sensor session initializes the effect from the current angle rather than replaying from a fully open position.

## Desktop rendering

ScreenCaptureKit supplies the live desktop. Metal applies the fold projection, progressively blends cached blur levels, and darkens the upper corners. Blur grows toward the top while the area near the hinge stays clearer. Captured frames remain in memory and are discarded when the capture lifecycle releases them.

Capture and drawing have separate schedules. The renderer can reuse the latest captured frame while the lid moves. Capture pauses when the effect is no longer needed; the overlay stays transparent at rest. This release retains the inherited rendering cadence and makes no high-frame-rate or latency guarantee.

The overlay targets the built-in display. It waits when that display is unavailable, including external-display-only use. Sleep/wake recovery uses readiness checks and session identifiers to reject stale callbacks. Turning the effect off cancels pending recovery.

## Preview and card motion

`FoldShowcase.swift` draws a computer and an illustrative desktop. Live lid readings drive its fold progress. Its blur and shading are clipped to the illustrated screen, leaving the computer body clear.

The demonstration performs one close/open cycle, then returns to live readings. It can be cancelled and never changes the saved baseline or desktop effect settings. Its percentage describes the illustrated fold progress, not the absolute lid angle or a measured match to the Metal output.

Card movement is decorative. Only eligible non-control areas start it; mouse events continue to the original controls. Offset is limited, layout order stays fixed, and releasing the mouse restores the resting position. Reduce Motion disables the movement. There is no idle animation timer.

## Evidence boundary

The automated suites exercise motion rules and callback ownership. They do not measure physical end-to-end latency, which also depends on the sensor, capture, GPU, and display. Upstream prototype timings are not presented as Uduo benchmarks. See [CHECKS.md](CHECKS.md) for practical verification.
