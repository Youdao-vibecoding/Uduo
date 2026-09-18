import Foundation

enum LiveDesktop {
  static let defaultOpenAngle = 110.0
}

private struct MotionFailure: Error, CustomStringConvertible {
  let description: String
}

private func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw MotionFailure(description: message) }
}

private final class MotionRig {
  let motion = LidMotion()
  var time = 10.0
  var angle = 110.0
  var values: [Double] = []
  let frame = 1.0 / 120

  init(focusesWhenHeld: Bool = false, initialAngle: Double? = 110) {
    motion.setFocusesWhenHeld(focusesWhenHeld)
    if let initialAngle {
      angle = initialAngle
      _ = motion.receive(angle, at: time)
    }
    motion.setEnabled(true, at: time)
  }

  @discardableResult
  func tick(_ nextAngle: Double? = nil) -> Double {
    time += frame
    if let nextAngle { angle = nextAngle }
    _ = motion.receive(angle, at: time)
    let value = Double(motion.sample(at: time))
    values.append(value)
    return value
  }

  @discardableResult
  func hold(_ duration: Double) -> [Double] {
    (0..<Int((duration / frame).rounded())).map { _ in tick() }
  }

  @discardableResult
  func move(to destination: Double, duration: Double) -> [Double] {
    let start = angle
    let frames = Int((duration / frame).rounded())
    return (1...frames).map { index in
      tick(start + (destination - start) * Double(index) / Double(frames))
    }
  }
}

private final class IntermittentSensorRig {
  struct Frame {
    let time: Double
    let value: Double
  }

  struct Reading {
    let time: Double
    let angle: Double
  }

  let motion = LidMotion()
  let frameInterval = 1.0 / 60
  let sensorInterval = 0.098
  var time = 10.0
  var angle = 110.0
  var frames: [Frame] = []
  var readings: [Reading] = []
  private var nextSensorTime = 10.098

  init() {
    motion.setFocusesWhenHeld(false)
    _ = motion.receive(angle, at: time)
    motion.setEnabled(true, at: time)
    readings.append(Reading(time: time, angle: angle))
  }

  @discardableResult
  func move(to destination: Double, duration: Double) -> [Frame] {
    let startTime = time
    let startAngle = angle
    let frameCount = Int((duration / frameInterval).rounded())
    let results = (1...frameCount).map { index in
      let frameTime = startTime + Double(index) * frameInterval
      while nextSensorTime <= frameTime {
        let progress = min(max((nextSensorTime - startTime) / duration, 0), 1)
        let sensorAngle = startAngle + (destination - startAngle) * progress
        _ = motion.receive(sensorAngle, at: nextSensorTime)
        readings.append(Reading(time: nextSensorTime, angle: sensorAngle))
        nextSensorTime += sensorInterval
      }
      return Frame(time: frameTime, value: Double(motion.sample(at: frameTime)))
    }
    frames.append(contentsOf: results)
    time = startTime + Double(frameCount) * frameInterval
    angle = destination
    return results
  }

  @discardableResult
  func hold(_ duration: Double) -> [Frame] {
    move(to: angle, duration: duration)
  }
}

private func checkContinuous(_ values: [Double], maximumStep: Double) throws {
  try require(
    values.allSatisfy { $0.isFinite && (0...1).contains($0) },
    "Motion must remain finite and within the visible effect range")
  let jumps = zip(values, values.dropFirst()).map { abs($1 - $0) }
  try require(
    (jumps.max() ?? 0) < maximumStep,
    "Motion changed too abruptly in one rendered frame: \(jumps.max() ?? 0)")
}

private func checkNonincreasing(_ values: [Double]) throws {
  let largestIncrease = zip(values, values.dropFirst()).map { $1 - $0 }.max() ?? 0
  try require(
    largestIncrease <= 0.00001,
    "Opening must not visibly deepen the fold: \(largestIncrease)")
}

private func openingImmediatelyAfterEnable() throws {
  let rig = MotionRig(initialAngle: 64)
  let initial = rig.tick(63)
  try require(initial > 0.3, "Enabling a partly closed lid must reflect its actual position")
  let opening = rig.move(to: 110, duration: 0.6)
  try require(opening[12] < initial, "Opening after enable must begin reducing the effect")
  try checkNonincreasing(opening)
  try checkContinuous([initial] + opening, maximumStep: 0.05)
  rig.hold(0.6)
  try require(rig.values.last! < 0.001, "The effect must clear once fully open")
}

private func sensorArrivesAfterEnable() throws {
  let rig = MotionRig(initialAngle: nil)
  try require(rig.motion.sample(at: rig.time) == 0, "Missing sensor data must show no effect")
  let initial = rig.tick(62)
  try require(initial > 0.3, "The first valid angle must initialize the visible fold")
  let opening = rig.move(to: 110, duration: 0.6)
  try require(opening[12] < initial, "A delayed sensor must still support opening")
  try checkNonincreasing(opening)
}

private func immediateReversal() throws {
  let rig = MotionRig()
  rig.move(to: 55, duration: 0.3)
  let before = rig.values.last!
  let opening = rig.move(to: 110, duration: 0.3)
  try require(
    opening[5] < before - 0.005,
    "A fast reversal must visibly respond within 50 ms without carrying closing momentum")
  try checkNonincreasing([before] + opening)
  try checkContinuous(rig.values, maximumStep: 0.08)
  rig.hold(0.6)
  try require(rig.values.last! < 0.001, "A fast reversal must return to a clear desktop")
}

private func openingAfterPauseInFollowMode() throws {
  let rig = MotionRig()
  rig.move(to: 60, duration: 0.6)
  rig.hold(1.8)
  let before = rig.values.last!
  try require(before > 0.3, "Continuous following must retain the fold while held")
  let opening = rig.move(to: 110, duration: 0.8)
  try require(opening[12] < before, "Opening from a pause must reduce the retained effect")
  try checkNonincreasing([before] + opening)
  try checkContinuous(rig.values, maximumStep: 0.05)
  rig.hold(0.6)
  try require(rig.values.last! < 0.001, "Opening from a pause must fully clear")
}

private func openingAfterPauseInFocusMode() throws {
  let rig = MotionRig(focusesWhenHeld: true)
  rig.move(to: 60, duration: 0.6)
  rig.hold(1.8)
  try require(rig.values.last! < 0.001, "Focus mode must restore clarity while held")
  let opening = rig.move(to: 85, duration: 0.5)
  try require(opening.max()! < 0.001, "Opening after focus has settled must stay clear")
  let closing = rig.move(to: 50, duration: 0.5)
  try require(closing.last! > 0.3, "Closing again must release focus and show the fold")
  rig.move(to: 110, duration: 0.6)
  rig.hold(0.6)
  try require(rig.values.last! < 0.001, "Focus mode must clear at the fully open position")
  try checkContinuous(rig.values, maximumStep: 0.05)
}

private func stableNoiseAndFullyOpen() throws {
  let rig = MotionRig(initialAngle: 70)
  rig.hold(0.6)
  let noise = (0..<360).map { index in rig.tick(70 + sin(Double(index)) * 0.25) }
  try require(
    noise.max()! - noise.min()! < 0.002,
    "Sub-degree stationary sensor noise must not make the desktop shimmer")
  rig.move(to: 110, duration: 0.8)
  rig.hold(0.6)
  let openNoise = (0..<240).map { index in rig.tick(110 + sin(Double(index)) * 0.25) }
  try require(openNoise.max()! < 0.001, "Fully open sensor noise must keep the effect cleared")
}

private func slowAndFastMotion() throws {
  for duration in [4.0, 0.4] {
    let rig = MotionRig()
    let closing = rig.move(to: 30, duration: duration)
    try require(closing.last! > 0.6, "Both slow and fast closing must produce a visible fold")
    try require(
      zip(closing, closing.dropFirst()).allSatisfy { $1 >= $0 - 0.00001 },
      "Steady closing must not move the effect backward")
    let opening = rig.move(to: 110, duration: duration)
    let reversalFrames = Int((0.1 / rig.frame).rounded())
    try require(
      opening.max()! - closing.last! < 0.01,
      "Reversal deepened by \(opening.max()! - closing.last!) over a \(duration) second movement")
    try checkNonincreasing(Array(opening.dropFirst(reversalFrames)))
    rig.hold(0.6)
    try require(rig.values.last! < 0.001, "Both slow and fast opening must fully clear")
    try checkContinuous(rig.values, maximumStep: 0.08)
  }
}

private func disableAndResumeWhileOpening() throws {
  let rig = MotionRig()
  rig.move(to: 40, duration: 0.6)
  rig.motion.setEnabled(false, at: rig.time)
  try require(rig.motion.sample(at: rig.time) == 0, "Disabling must clear the effect")
  rig.move(to: 60, duration: 0.2)
  rig.motion.setEnabled(true, at: rig.time)
  let resumed = Double(rig.motion.sample(at: rig.time))
  try require(resumed > 0.3, "Resume must initialize from the current partly open angle")
  let opening = rig.move(to: 110, duration: 0.5)
  try require(opening[12] < resumed, "Opening must continue responding after resume")
  try checkNonincreasing([resumed] + opening)
  try checkContinuous([resumed] + opening, maximumStep: 0.05)
}

private func intermittentSensorSlowAndFastReversal() throws {
  for duration in [4.0, 0.4] {
    let rig = IntermittentSensorRig()
    rig.move(to: 50, duration: duration)
    let before = rig.frames.last!.value
    let lastClosingReading = rig.readings.last!
    let openingStart = rig.time
    try require(before > 0.4, "Sparse readings must still produce a visible closing effect")
    let opening = rig.move(to: 110, duration: duration)
    guard
      let reversalReading = rig.readings.first(where: {
        $0.time > openingStart && $0.angle > lastClosingReading.angle + 1
      })
    else {
      throw MotionFailure(description: "The sensor trace must include an observable reversal")
    }
    let responseWindow = opening.filter {
      $0.time >= reversalReading.time && $0.time <= reversalReading.time + 0.15
    }
    let beforeReportedReversal =
      opening.last(where: { $0.time < reversalReading.time })?.value ?? before
    try require(
      responseWindow.contains { $0.value < beforeReportedReversal - 0.005 },
      "Opening must respond within 150 ms after the sensor reports an observable reversal")
    try checkNonincreasing(
      [beforeReportedReversal] + opening.filter { $0.time >= reversalReading.time }.map(\.value))
    rig.hold(0.8)
    try require(
      rig.frames.last!.value < 0.001,
      "A reversal with sparse sensor readings must fully clear")
    try checkContinuous(rig.frames.map(\.value), maximumStep: 0.1)
    let maximumReadingGap = zip(rig.readings, rig.readings.dropFirst()).map {
      $1.time - $0.time
    }.max()!
    try require(
      maximumReadingGap > 0.09,
      "This trace must exercise sensor updates substantially slower than rendering")
  }
}

private func intermittentSensorOpeningAfterPause() throws {
  let rig = IntermittentSensorRig()
  rig.move(to: 60, duration: 0.7)
  rig.hold(1.8)
  let before = rig.frames.last!.value
  let openingStart = rig.time
  try require(before > 0.3, "Following mode must keep a partly closed lid visible while held")
  let opening = rig.move(to: 110, duration: 0.8)
  guard
    let openingReading = rig.readings.first(where: {
      $0.time > openingStart && $0.angle > 61
    })
  else {
    throw MotionFailure(description: "The paused trace must deliver an observable opening reading")
  }
  try require(
    opening.contains {
      $0.time >= openingReading.time && $0.time <= openingReading.time + 0.15
        && $0.value < before - 0.005
    },
    "Opening after a pause must respond after the next sparse sensor reading")
  try checkNonincreasing([before] + opening.map(\.value))
  rig.hold(0.8)
  try require(
    rig.frames.last!.value < 0.001,
    "Opening after a pause must fully clear with sparse readings")
  try checkContinuous(rig.frames.map(\.value), maximumStep: 0.1)
}

private func checkBaselineResponse(_ motion: LidMotion, matches baseline: Double) throws {
  let reference = LidMotion(openAngle: baseline)
  motion.setFocusesWhenHeld(false)
  reference.setFocusesWhenHeld(false)
  for angle in [20.0, 25, 60, 95, 110, 119, 120, 140, 180] {
    for item in [motion, reference] {
      _ = item.receive(angle, at: 10)
      item.setEnabled(true, at: 10)
    }
    let actual = Double(motion.sample(at: 10))
    let expected = Double(reference.sample(at: 10))
    try require(actual.isFinite && (0...1).contains(actual), "Baseline changes must keep the effect finite")
    try require(
      abs(actual - expected) < 0.00001,
      "At lid angle \(angle), the effect must match a \(baseline) degree baseline: \(actual) vs \(expected)")
  }
}

private func initialBaselineStaysInRange() throws {
  for proposed in [120.0, 121, 180, 360] {
    try checkBaselineResponse(LidMotion(openAngle: proposed), matches: 120)
  }
  for proposed in [-90.0, 0, 24, 25] {
    try checkBaselineResponse(LidMotion(openAngle: proposed), matches: 25)
  }
  try checkBaselineResponse(LidMotion(openAngle: 95), matches: 95)
}

private func changedBaselineStaysInRange() throws {
  let motion = LidMotion(openAngle: 95)
  for (proposed, expected) in [(180.0, 120.0), (121, 120), (120, 120), (0, 25), (95, 95)] {
    motion.setBaseline(proposed)
    try checkBaselineResponse(motion, matches: expected)
  }
}

private func calibrationCapsHighReadings() throws {
  let motion = LidMotion(openAngle: 120)
  for sensed in [180.0, 140, 121, 120] {
    _ = motion.receive(sensed, at: 10)
    try require(motion.calibrate() == 120, "Calibrating an open lid must never store more than 120 degrees")
    try checkBaselineResponse(motion, matches: 120)
  }
  for sensed in [25.0, 95, 119] {
    _ = motion.receive(sensed, at: 10)
    try require(motion.calibrate() == sensed, "Calibration must preserve a valid viewing angle")
    try checkBaselineResponse(motion, matches: sensed)
  }
  motion.setBaseline(95)
  _ = motion.receive(24, at: 10)
  try require(motion.calibrate() == nil, "A nearly closed lid must not become the open baseline")
  try checkBaselineResponse(motion, matches: 95)
}

private func nonfiniteBaselineUsesDefault() throws {
  for proposed in [Double.nan, .infinity, -.infinity] {
    try checkBaselineResponse(LidMotion(openAngle: proposed), matches: LiveDesktop.defaultOpenAngle)
    let motion = LidMotion(openAngle: 120)
    motion.setBaseline(proposed)
    try checkBaselineResponse(motion, matches: LiveDesktop.defaultOpenAngle)
  }
}

@main
private enum LidMotionBehaviorTests {
  static func main() {
    let tests: [(String, () throws -> Void)] = [
      ("opening immediately after enable", openingImmediatelyAfterEnable),
      ("sensor arrives after enable", sensorArrivesAfterEnable),
      ("immediate reversal", immediateReversal),
      ("opening after pause in follow mode", openingAfterPauseInFollowMode),
      ("opening after pause in focus mode", openingAfterPauseInFocusMode),
      ("stable noise and fully open", stableNoiseAndFullyOpen),
      ("slow and fast motion", slowAndFastMotion),
      ("disable and resume while opening", disableAndResumeWhileOpening),
      ("98 ms sensor, 60 Hz render: slow and fast reversal", intermittentSensorSlowAndFastReversal),
      ("98 ms sensor, 60 Hz render: opening after pause", intermittentSensorOpeningAfterPause),
      ("initial baseline stays within 25 to 120 degrees", initialBaselineStaysInRange),
      ("changed baseline stays within 25 to 120 degrees", changedBaselineStaysInRange),
      ("calibration caps high readings and preserves valid angles", calibrationCapsHighReadings),
      ("nonfinite baseline falls back to the default", nonfiniteBaselineUsesDefault),
    ]
    var failures = 0
    for (name, test) in tests {
      do {
        try test()
        print("PASS: \(name)")
      } catch {
        failures += 1
        print("FAIL: \(name): \(error)")
      }
    }
    print("\(tests.count - failures)/\(tests.count) behavior tests passed")
    exit(failures == 0 ? 0 : 1)
  }
}
