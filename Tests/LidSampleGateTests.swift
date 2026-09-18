import Foundation
import QuartzCore

enum LiveDesktop {
  static let defaultOpenAngle = 95.0
}

@main
enum LidSampleGateTests {
  private static var checks = 0

  private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError(message) }
  }

  private static func initialAndSuspendedSamples() {
    let gate = LidSampleGate()
    let motion = LidMotion()
    let first = gate.receive(80, motion: motion)!
    require(first.1.available, "Initial sensor sample must be available")
    require(gate.isCurrent(first.0), "Initial generation must be current")
    require(gate.current() == first.0, "Missing-sensor callback must share the generation")
    gate.suspend()
    require(!gate.isCurrent(first.0), "A queued pre-sleep callback must become stale")
    require(gate.current() == nil, "Missing-sensor callbacks must be blocked while asleep")
    require(gate.receive(60, motion: motion) == nil, "Angle samples must be blocked while asleep")
    require(gate.receive(nil, motion: motion) == nil, "Disconnect samples must be blocked asleep")
    require(motion.calibrate() == 80, "Blocked samples must not change the motion angle")
  }

  private static func resumeRequiresDisconnect() {
    let gate = LidSampleGate()
    let motion = LidMotion()
    let beforeSleep = gate.receive(85, motion: motion)!
    gate.suspend()
    gate.resume()
    require(gate.current() == nil, "Resume must wait for the reconnect reset")
    require(gate.receive(84, motion: motion) == nil, "An old positive sample must not resume motion")
    require(motion.calibrate() == 85, "A sample before reconnect reset must not change motion")
    let reset = gate.receive(nil, motion: motion)!
    require(!reset.1.available, "Reconnect reset must mark the sensor unavailable")
    require(gate.current() == reset.0, "Reset must enable callbacks for the new generation")
    let fresh = gate.receive(55, motion: motion)!
    require(fresh.1.available, "Fresh wake sample must make the sensor available")
    require(fresh.1.availabilityChanged, "Fresh wake sample must publish availability")
    require(gate.isCurrent(fresh.0), "Fresh wake callback must be current")
    require(!gate.isCurrent(beforeSleep.0), "Wake must not revive an old queued callback")
    require(motion.calibrate() == 55, "Fresh wake sample must reach motion")
  }

  private static func repeatedSleepAndInterruptedResume() {
    let gate = LidSampleGate()
    let motion = LidMotion()
    let first = gate.receive(90, motion: motion)!
    gate.suspend()
    gate.suspend()
    require(!gate.isCurrent(first.0), "Repeated sleep must keep old callbacks stale")
    require(gate.receive(70, motion: motion) == nil, "Repeated sleep must stay suspended")
    gate.resume()
    let reset = gate.receive(nil, motion: motion)!
    gate.suspend()
    require(!gate.isCurrent(reset.0), "Interrupted wake must invalidate its reset callback")
    require(gate.receive(60, motion: motion) == nil, "Interrupted wake must reject late angles")
    gate.resume()
    require(gate.receive(60, motion: motion) == nil, "A subsequent wake must require its own reset")
    let nextReset = gate.receive(nil, motion: motion)!
    let fresh = gate.receive(50, motion: motion)!
    require(nextReset.0 == fresh.0, "Reset and fresh sample must share the new generation")
    require(gate.isCurrent(fresh.0), "A later valid wake must recover normally")
    require(!gate.isCurrent(reset.0), "An interrupted wake must remain stale after recovery")
  }

  private static func effectToggleDoesNotDisconnectSensor() {
    let gate = LidSampleGate()
    let motion = LidMotion()
    motion.setFocusesWhenHeld(false)
    let first = gate.receive(50, motion: motion)!
    motion.setEnabled(true)
    require(motion.isClosing, "Enabling at a folded angle must start the effect")
    motion.setEnabled(false)
    require(!motion.isClosing, "Disabling must stop the effect")
    require(motion.sample(at: CACurrentMediaTime()) == 0, "Disabled motion must render clear")
    require(gate.isCurrent(first.0), "Toggling the effect must keep the sensor generation")
    let whileDisabled = gate.receive(65, motion: motion)!
    require(whileDisabled.1.available, "The sensor must stay available while the effect is off")
    require(whileDisabled.0 == first.0, "Normal toggles must not require a reconnect reset")
    motion.setEnabled(true)
    require(motion.isClosing, "Re-enabling must use the latest folded angle")
    require(motion.sample(at: CACurrentMediaTime()) > 0, "Re-enabled motion must render its angle")
  }

  static func main() {
    initialAndSuspendedSamples()
    resumeRequiresDisconnect()
    repeatedSleepAndInterruptedResume()
    effectToggleDoesNotDisconnectSensor()
    print("LidSampleGate: \(checks) lifecycle checks passed")
  }
}
