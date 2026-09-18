import AppKit
import SwiftUI

public extension View {
  func jellyCard(
    enabled: Bool = true, maximumOffset: CGFloat = 10, dragRegion: CGRect? = nil
  ) -> some View {
    modifier(
      JellyCardModifier(enabled: enabled, maximumOffset: maximumOffset, dragRegion: dragRegion))
  }

  func jellyCardDragHandle() -> some View {
    anchorPreference(key: JellyHandlePreference.self, value: .bounds) { [$0] }
  }
}

private struct JellyHandlePreference: PreferenceKey {
  static var defaultValue: [Anchor<CGRect>] = []

  static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
    value.append(contentsOf: nextValue())
  }
}

private struct JellyCardModifier: ViewModifier {
  let enabled: Bool
  let maximumOffset: CGFloat
  let dragRegion: CGRect?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var offset = CGSize.zero

  private var limit: CGFloat {
    maximumOffset.isFinite ? min(max(maximumOffset, 0), 12) : 10
  }

  private var canDrag: Bool { enabled && !reduceMotion && limit > 0 }

  func body(content: Content) -> some View {
    content
      .backgroundPreferenceValue(JellyHandlePreference.self) { handles in
        GeometryReader { geometry in
          JellyMouseObserver(
            enabled: canDrag,
            regions: handles.map { geometry[$0] } + (dragRegion.map { [$0] } ?? []),
            onDrag: receiveDrag
          )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .scaleEffect(
        x: 1 + abs(offset.width) / max(limit, 1) * 0.025 - abs(offset.height) / max(limit, 1) * 0.01,
        y: 1 + abs(offset.height) / max(limit, 1) * 0.025 - abs(offset.width) / max(limit, 1) * 0.01)
      .rotationEffect(.degrees(Double(offset.width / max(limit, 1)) * 0.8))
      .offset(offset)
      .onChange(of: canDrag) { if !canDrag { reset() } }
      .onDisappear { offset = .zero }
  }

  private func receiveDrag(_ translation: CGSize?) {
    guard canDrag, let translation else { reset(); return }
    let distance = hypot(translation.width, translation.height)
    guard distance.isFinite, distance > 0 else { return }
    let resistance = limit * tanh(distance / 65) / distance
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      offset = CGSize(
        width: translation.width * resistance, height: translation.height * resistance)
    }
  }

  private func reset() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.66)) {
      offset = .zero
    }
  }
}

private struct JellyMouseObserver: NSViewRepresentable {
  let enabled: Bool
  let regions: [CGRect]
  let onDrag: (CGSize?) -> Void

  func makeNSView(context: Context) -> JellyObservationView {
    let view = JellyObservationView()
    view.configure(enabled: enabled, regions: regions, onDrag: onDrag)
    return view
  }

  func updateNSView(_ view: JellyObservationView, context: Context) {
    view.configure(enabled: enabled, regions: regions, onDrag: onDrag)
  }

  static func dismantleNSView(_ view: JellyObservationView, coordinator: ()) {
    view.disconnect()
  }
}

private final class JellyObservationView: NSView {
  private var enabled = false
  private var regions: [CGRect] = []
  private var onDrag: ((CGSize?) -> Void)?
  private var mouseMonitor: Any?
  private var notifications: [NSObjectProtocol] = []
  private var origin: CGPoint?
  private var isDragging = false

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { false }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  func configure(enabled: Bool, regions: [CGRect], onDrag: @escaping (CGSize?) -> Void) {
    self.enabled = enabled
    self.regions = regions
    self.onDrag = onDrag
    if !enabled {
      origin = nil
      isDragging = false
    }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    disconnect()
    guard let window else { return }
    mouseMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]
    ) { [weak self] event in
      self?.receive(event)
      return event
    }
    let center = NotificationCenter.default
    notifications = [
      center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) {
        [weak self] _ in self?.finish()
      },
      center.addObserver(
        forName: NSApplication.willResignActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.finish() },
    ]
  }

  func disconnect() {
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    for observer in notifications { NotificationCenter.default.removeObserver(observer) }
    notifications.removeAll()
    origin = nil
    isDragging = false
  }

  private func receive(_ event: NSEvent) {
    if event.type == .leftMouseUp {
      finish()
      return
    }
    if event.type == .keyDown, event.keyCode == 53 {
      finish()
      return
    }
    guard enabled, !isHiddenOrHasHiddenAncestor, event.window === window else { return }
    switch event.type {
    case .leftMouseDown:
      let point = convert(event.locationInWindow, from: nil)
      guard visibleRect.contains(point), regions.contains(where: { $0.contains(point) }) else {
        origin = nil
        return
      }
      origin = event.locationInWindow
      isDragging = false
    case .leftMouseDragged:
      guard let origin else { return }
      let translation = CGSize(
        width: event.locationInWindow.x - origin.x, height: origin.y - event.locationInWindow.y)
      guard isDragging || hypot(translation.width, translation.height) >= 3 else { return }
      isDragging = true
      onDrag?(translation)
    default:
      break
    }
  }

  private func finish() {
    let shouldReset = isDragging
    origin = nil
    isDragging = false
    if shouldReset { onDrag?(nil) }
  }

  deinit {
    disconnect()
  }
}
