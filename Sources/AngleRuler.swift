import AppKit
import SwiftUI

struct AngleRuler: NSViewRepresentable {
  @Binding var value: Double
  var onEditingChanged: (Bool) -> Void = { _ in }
  @Environment(\.isEnabled) private var isEnabled

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeNSView(context: Context) -> RulerSlider {
    let slider = RulerSlider()
    slider.minValue = LidMotion.openAngleRange.lowerBound
    slider.maxValue = LidMotion.openAngleRange.upperBound
    slider.isContinuous = true
    slider.target = context.coordinator
    slider.action = #selector(Coordinator.changed(_:))
    slider.setAccessibilityLabel(String(localized: "Open baseline"))
    slider.setAccessibilityHelp(String(localized: "Drag the ruler to adjust the angle."))
    slider.toolTip = String(localized: "Drag the ruler to adjust the angle.")
    return slider
  }

  func updateNSView(_ slider: RulerSlider, context: Context) {
    context.coordinator.parent = self
    slider.doubleValue = value
    slider.isEnabled = isEnabled
    slider.editingChanged = onEditingChanged
    slider.needsDisplay = true
  }

  final class Coordinator: NSObject {
    var parent: AngleRuler

    init(parent: AngleRuler) { self.parent = parent }

    @objc func changed(_ slider: RulerSlider) {
      parent.value = slider.doubleValue
    }
  }
}

final class RulerSlider: NSSlider {
  var editingChanged: (Bool) -> Void = { _ in }
  private var isAdjusting = false
  private let acid = NSColor(red: 0.945, green: 1, blue: 0.16, alpha: 1)

  override var acceptsFirstResponder: Bool { isEnabled }
  override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 44) }

  override func draw(_ dirtyRect: NSRect) {
    let width = max(bounds.width - 16, 1)
    let fraction = (doubleValue - minValue) / max(maxValue - minValue, 1)
    let intervals = max(Int((maxValue - minValue) / 2.5), 1)
    for index in 0...intervals {
      let x = bounds.minX + 8 + width * CGFloat(index) / CGFloat(intervals)
      let angle = minValue + (maxValue - minValue) * Double(index) / Double(intervals)
      let major = index % 4 == 0 || index == intervals
      let height: CGFloat = major ? 26 : 16
      let path = NSBezierPath(
        roundedRect: NSRect(x: x - 2, y: bounds.midY + 13 - height, width: 4, height: height),
        xRadius: 1.5, yRadius: 1.5)
      let color = angle <= doubleValue
        ? acid.withAlphaComponent(isEnabled ? 1 : 0.3)
        : NSColor.white.withAlphaComponent(isEnabled ? 0.14 : 0.05)
      color.setFill()
      path.fill()
    }
    let x = bounds.minX + 8 + width * CGFloat(fraction)
    let marker = NSBezierPath(
      roundedRect: NSRect(x: x - 3, y: bounds.midY - 18, width: 6, height: 36),
      xRadius: 3, yRadius: 3)
    NSColor.white.withAlphaComponent(isEnabled ? 1 : 0.3).setFill()
    marker.fill()
    if window?.firstResponder === self {
      acid.withAlphaComponent(0.4).setStroke()
      let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
      focus.lineWidth = 1
      focus.stroke()
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard isEnabled else { return }
    window?.makeFirstResponder(self)
    isAdjusting = true
    editingChanged(true)
    updateAngle(at: event)
  }

  override func mouseDragged(with event: NSEvent) {
    guard isEnabled, isAdjusting else { return }
    updateAngle(at: event)
  }

  override func mouseUp(with event: NSEvent) {
    guard isAdjusting else { return }
    if isEnabled { updateAngle(at: event) }
    endEditing()
  }

  override func keyDown(with event: NSEvent) {
    guard isEnabled else { return }
    let step = event.modifierFlags.contains(.shift) ? 5.0 : 1.0
    switch event.keyCode {
    case 123, 125: commit(doubleValue - step)
    case 124, 126: commit(doubleValue + step)
    case 115: commit(minValue)
    case 119: commit(maxValue)
    case 53: endEditing()
    default: super.keyDown(with: event)
    }
  }

  override func resignFirstResponder() -> Bool {
    endEditing()
    needsDisplay = true
    return super.resignFirstResponder()
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow == nil { endEditing() }
    super.viewWillMove(toWindow: newWindow)
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: isEnabled ? .resizeLeftRight : .arrow)
  }

  override func accessibilityPerformIncrement() -> Bool {
    guard isEnabled else { return false }
    commit(doubleValue + 1)
    return true
  }

  override func accessibilityPerformDecrement() -> Bool {
    guard isEnabled else { return false }
    commit(doubleValue - 1)
    return true
  }

  override func setAccessibilityValue(_ accessibilityValue: Any?) {
    guard isEnabled, let number = accessibilityValue as? NSNumber else { return }
    commit(number.doubleValue)
  }

  override func accessibilityValueDescription() -> String? {
    "\(Int(doubleValue.rounded()))°"
  }

  private func updateAngle(at event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let fraction = min(max((point.x - bounds.minX - 8) / max(bounds.width - 16, 1), 0), 1)
    commit((minValue + Double(fraction) * (maxValue - minValue)).rounded())
  }

  private func commit(_ proposed: Double) {
    guard proposed.isFinite else { return }
    doubleValue = min(max(proposed, minValue), maxValue)
    needsDisplay = true
    sendAction(action, to: target)
  }

  private func endEditing() {
    guard isAdjusting else { return }
    isAdjusting = false
    editingChanged(false)
  }
}
