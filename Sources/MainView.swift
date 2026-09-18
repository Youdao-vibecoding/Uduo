import AppKit
import IOKit
import SwiftUI
import UniformTypeIdentifiers

private enum Studio {
  static let paper = Color(red: 0.945, green: 0.945, blue: 0.93)
  static let ink = Color(red: 0.07, green: 0.075, blue: 0.07)
  static let panel = Color(red: 0.075, green: 0.078, blue: 0.075)
  static let card = Color(red: 0.13, green: 0.135, blue: 0.13)
  static let acid = Color(red: 0.945, green: 1, blue: 0.16)
}

struct MainView: View {
  @ObservedObject var desktop: LiveDesktop
  @ObservedObject var updater: Updater
  let delegate: AppDelegate
  @State private var screenRecordingAllowed = CGPreflightScreenCaptureAccess()
  @State private var showsPreferences = false
  @State private var isAdjustingAngle = false
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    HStack(spacing: 0) {
      FoldLivePanel(
        lid: desktop.lid, openAngle: desktop.openAngle, active: desktop.isActive,
        available: desktop.sensorAvailable, version: version,
        showAbout: { openWindow(id: "about") }
      )
      .frame(width: 484)
      .background(Studio.paper)
      controls
        .frame(width: 376)
        .background(Studio.panel.ignoresSafeArea(edges: .vertical))
        .environment(\.colorScheme, .dark)
    }
    .frame(width: 860, height: 740)
    .background(Studio.paper.ignoresSafeArea())
    .onAppear {
      let openWindow = openWindow
      delegate.onReopen = {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in
      screenRecordingAllowed = CGPreflightScreenCaptureAccess()
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text("Controls")
          .font(.system(size: 26, weight: .semibold))
        Spacer()
        Button { showsPreferences.toggle() } label: {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 16, weight: .medium))
            .frame(width: 40, height: 40)
            .background(Studio.card, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("General settings"))
        .help("General settings")
        .popover(isPresented: $showsPreferences, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 18) {
            PreferencesCard(updater: updater)
            HStack {
              Text("Keyboard shortcut")
              Spacer()
              Text(verbatim: LocalEdition.shortcut)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          }
          .padding(20)
          .frame(width: 380)
          .background(Studio.panel)
          .environment(\.colorScheme, .dark)
          .preferredColorScheme(.dark)
          .tint(Studio.acid)
        }
      }
      ScrollView {
        VStack(spacing: 14) {
          Toggle(
            "Desktop fold",
            isOn: Binding(get: { desktop.isEnabled }, set: { desktop.setEnabled($0) })
          )
          .toggleStyle(StudioPowerStyle(status: desktop.statusTitle))
          .disabled(desktop.isStarting)
          .help(Text(verbatim: LocalEdition.shortcut))
          if !desktop.isActive {
            Text(desktop.statusSubtitle)
              .font(.system(size: 12))
              .foregroundStyle(.white.opacity(0.7))
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 4)
          }
          permissionNotice
          position
          focus
        }
        .padding(.bottom, 2)
      }
      .scrollIndicators(.automatic)
      HStack {
        Text(desktop.statusTitle)
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.55))
        Spacer()
        Button("Quit App") { NSApp.terminate(nil) }
          .buttonStyle(StudioPillStyle(light: true))
          .help(Text("⌘Q"))
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 26)
    .padding(.top, 24)
    .padding(.bottom, 24)
  }

  @ViewBuilder
  private var permissionNotice: some View {
    if let error = desktop.error {
      VStack(alignment: .leading, spacing: 12) {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(.system(size: 12))
          .fixedSize(horizontal: false, vertical: true)
        if desktop.needsPermission {
          Button("Open Settings", action: openScreenRecordingSettings)
            .buttonStyle(StudioPillStyle(light: true))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .background(Studio.card, in: RoundedRectangle(cornerRadius: 24))
    } else if !screenRecordingAllowed {
      VStack(alignment: .leading, spacing: 12) {
        Text("Screen Recording").font(.system(size: 14, weight: .medium))
        Text("Uduo reads your display only to draw the fold. Frames stay in memory on your Mac.")
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.7))
          .fixedSize(horizontal: false, vertical: true)
        Button("Open Settings", action: openScreenRecordingSettings)
          .buttonStyle(StudioPillStyle(light: true))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .background(Studio.card, in: RoundedRectangle(cornerRadius: 24))
    }
  }

  private var position: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Open baseline")
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity, alignment: .leading)
          .jellyCardDragHandle()
        Spacer()
        Button {
          withAnimation(.smooth(duration: 0.4)) { desktop.restoreDefaultOpenPosition() }
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .frame(width: 34, height: 34)
            .background(.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(desktop.isDefaultOpenAngle || desktop.isStarting)
        .accessibilityLabel(Text("Restore Default"))
        .help(Text("Go back to \(degrees(LiveDesktop.defaultOpenAngle))"))
      }
      Text(verbatim: degrees(desktop.openAngle))
        .font(.system(size: 48, weight: .regular, design: .rounded))
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
        .jellyCardDragHandle()
      VStack(spacing: 2) {
        AngleRuler(
          value: Binding(get: { desktop.openAngle }, set: { desktop.setOpenAngle($0) }),
          onEditingChanged: { isAdjustingAngle = $0 }
        )
        .frame(height: 44)
        .disabled(desktop.isStarting)
        HStack {
          Text(verbatim: degrees(LidMotion.openAngleRange.lowerBound))
          Spacer()
          Text(verbatim: degrees(LidMotion.openAngleRange.upperBound))
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.5))
      }
      Text("Folding starts below this angle.")
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.68))
        .fixedSize(horizontal: false, vertical: true)
        .help("Drag the ruler to adjust the angle.")
        .frame(maxWidth: .infinity, alignment: .leading)
        .jellyCardDragHandle()
      Button {
        withAnimation(.smooth(duration: 0.4)) { desktop.setOpenPosition() }
      } label: {
        HStack {
          Text("Use Current Angle")
          Spacer()
          Image(systemName: "arrow.up.right")
        }
      }
      .buttonStyle(StudioPillStyle(light: true))
      .disabled(!desktop.sensorAvailable || desktop.isStarting)
      .help("Save the lid angle you are viewing at right now")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(Studio.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .jellyCard(enabled: !isAdjustingAngle)
  }

  private var focus: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Follow both directions")
          .font(.system(size: 14, weight: .medium))
          .frame(maxWidth: .infinity, alignment: .leading)
          .jellyCardDragHandle()
        Spacer(minLength: 12)
        Toggle(
          "Follow both directions",
          isOn: Binding(
            get: { !desktop.focusesWhenHeld }, set: { desktop.setFocusesWhenHeld(!$0) })
        )
        .toggleStyle(.switch)
        .labelsHidden()
        .tint(Studio.acid)
      }
      Text("Follow the lid in both directions.")
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.68))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jellyCardDragHandle()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(Studio.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .jellyCard()
  }

  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }
}

private struct FoldLivePanel: View {
  @ObservedObject var lid: LidReading
  let openAngle: Double
  let active: Bool
  let available: Bool
  let version: String
  let showAbout: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var demoProgress = 0.0
  @State private var isDemonstrating = false
  @State private var demoTask: Task<Void, Never>?

  private var liveProgress: Double {
    guard available, let angle = lid.degrees, openAngle > 8.6 else { return 0 }
    return min(max((openAngle - 0.6 - angle) / (openAngle - 8.6), 0), 1)
  }

  private var progress: Double { isDemonstrating ? demoProgress : liveProgress }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 7) {
          Text(verbatim: "Uduo")
            .font(.system(size: 36, weight: .semibold, design: .rounded))
          Text("Your desktop follows your lid.")
            .font(.system(size: 14))
            .foregroundStyle(Studio.ink.opacity(0.65))
        }
        Spacer()
        Button(action: showAbout) {
          Image(systemName: "info")
            .font(.system(size: 16, weight: .medium))
            .frame(width: 40, height: 40)
            .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("About Uduo"))
      }
      HStack(spacing: 7) {
        Circle().fill(isDemonstrating ? Studio.ink : (available ? .green : .gray))
          .frame(width: 6, height: 6)
        Text(isDemonstrating ? "Demo preview" : "Live preview")
          .font(.system(size: 11, weight: .medium))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.white, in: Capsule())
      .padding(.top, 23)
      FoldShowcase(progress: progress, active: active || isDemonstrating)
        .frame(width: 448, height: 290)
        .padding(.horizontal, -12)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: liveProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Fold preview"))
        .accessibilityValue(Text(verbatim: "\(Int(progress * 100))%"))
      HStack(spacing: 12) {
        metric(
          title: String(localized: "Live lid angle"),
          value: available ? lid.degrees.map(degrees) ?? "…" : "…",
          symbol: "angle", highlighted: false)
        metric(
          title: String(localized: "Fold preview"), value: "\(Int(progress * 100))%",
          symbol: "rectangle.compress.vertical", highlighted: true)
      }
      .padding(.top, 2)
      Spacer(minLength: 18)
      HStack {
        Button(action: toggleDemo) {
          Label(isDemonstrating ? "Back to live" : "Play demo",
            systemImage: isDemonstrating ? "arrow.uturn.backward" : "play.fill")
        }
        .buttonStyle(StudioPillStyle(light: true))
        Spacer()
        Text(verbatim: "v\(version)")
          .font(.system(size: 11))
          .foregroundStyle(Studio.ink.opacity(0.5))
      }
      HStack(spacing: 5) {
        Text("Illustrative preview")
        Text(verbatim: "·")
        Text(isDemonstrating ? "Demo does not change your settings." : "Preview follows your lid.")
      }
      .font(.system(size: 11))
      .foregroundStyle(Studio.ink.opacity(0.6))
      .padding(.top, 12)
    }
    .foregroundStyle(Studio.ink)
    .padding(.horizontal, 30)
    .padding(.top, 24)
    .padding(.bottom, 24)
    .onDisappear { stopDemo() }
    .onChange(of: reduceMotion) { if reduceMotion { stopDemo() } }
  }

  private func metric(title: String, value: String, symbol: String, highlighted: Bool) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Image(systemName: symbol).font(.system(size: 15))
        Spacer()
        Group {
          if highlighted {
            PreviewPercentage(progress: progress)
          } else {
            Text(value)
          }
        }
        .font(.system(size: 28, weight: .medium, design: .rounded))
        .monospacedDigit()
      }
      Text(title).font(.system(size: 12, weight: .medium))
    }
    .padding(19)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(highlighted ? Studio.acid : .white,
      in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .accessibilityElement(children: .combine)
    .jellyCardDragHandle()
    .jellyCard()
  }

  private func toggleDemo() {
    if isDemonstrating { stopDemo(); return }
    demoProgress = liveProgress
    isDemonstrating = true
    demoTask = Task { @MainActor in
      do {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.35)) { demoProgress = 1 }
        try await Task.sleep(nanoseconds: 1_650_000_000)
        try Task.checkCancellation()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.65)) { demoProgress = 0 }
        try await Task.sleep(nanoseconds: 1_950_000_000)
        try Task.checkCancellation()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { demoProgress = liveProgress }
        try await Task.sleep(nanoseconds: 550_000_000)
        try Task.checkCancellation()
        isDemonstrating = false
        demoTask = nil
      } catch {}
    }
  }

  private func stopDemo() {
    demoTask?.cancel()
    demoTask = nil
    isDemonstrating = false
  }
}

private struct PreviewPercentage: View, Animatable {
  var progress: Double

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    Text(verbatim: "\(Int(progress * 100))%")
  }
}

private struct StudioPowerStyle: ToggleStyle {
  let status: String

  func makeBody(configuration: Configuration) -> some View {
    Button { configuration.isOn.toggle() } label: {
      HStack(spacing: 14) {
        Image(systemName: "power")
          .font(.system(size: 20, weight: .medium))
          .frame(width: 46, height: 46)
          .background(configuration.isOn ? Studio.ink : Color.white.opacity(0.08), in: Circle())
          .foregroundStyle(configuration.isOn ? Studio.acid : .white)
        VStack(alignment: .leading, spacing: 5) {
          configuration.label.font(.system(size: 19, weight: .semibold))
          Text(status).font(.system(size: 12)).opacity(0.7)
        }
        Spacer(minLength: 0)
        Image(systemName: configuration.isOn ? "checkmark" : "minus")
          .font(.system(size: 15, weight: .medium))
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(configuration.isOn ? Studio.ink : .white)
      .background(configuration.isOn ? Studio.acid : Studio.card,
        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: 28))
    }
    .buttonStyle(.plain)
    .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
  }
}

private struct StudioPillStyle: ButtonStyle {
  var light = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
      .foregroundStyle(light ? Studio.ink : .white)
      .background(light ? Color.white : Studio.card, in: Capsule())
      .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
      .contentShape(Capsule())
  }
}

extension LiveDesktop {
  var statusTitle: String {
    if isActive { return String(localized: "On") }
    if isStarting { return String(localized: "Starting…") }
    return isEnabled ? String(localized: "Waiting…") : String(localized: "Off")
  }

  var statusSubtitle: String {
    if isActive { return String(localized: "Your desktop bends as the lid closes.") }
    if isStarting { return String(localized: "Getting the desktop and the sensor ready.") }
    if isWaitingForDisplay {
      return String(localized: "Waiting for the built-in display to turn on.")
    }
    if !sensorAvailable { return String(localized: "Waiting for the lid angle sensor.") }
    if isEnabled { return String(localized: "Uduo is on but not running yet.") }
    return String(localized: "Turn Uduo on to follow the lid.")
  }
}

func degrees(_ value: Double) -> String {
  Measurement(value: value, unit: UnitAngle.degrees).formatted(
    .measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))
}

struct MacLook {
  enum Model {
    case pro14
    case pro16
    case air13
    case air15
  }

  enum Port {
    case magSafe
    case thunderbolt
    case headphone
  }

  struct Chassis {
    let isPro: Bool
    let depth: Double
    let baseHeight: Double
    let lidMetal: Double
    let lidGlass: Double
    let lidCorner: Double
    let curveHeight: Double
    let curveWidth: Double
    let portCenter: Double
    let ports: [(port: Port, center: Double)]
    let feet: [Double]
    let footTop: Double
    let footBottom: Double
    let footHeight: Double
    let vent: ClosedRange<Double>?
    let hingeDrop: Double
    let hingeGap: Double
    let displayHeight: Double
    let topBezel: Double

    var lidThickness: Double { lidMetal + lidGlass }
  }

  let model: Model
  let color: Int

  static let current = detect()
  static let pointsPerCentimeter: CGFloat = 4.6

  var chassis: Chassis {
    switch model {
    case .pro14:
      return Chassis(
        isPro: true, depth: 22.12, baseHeight: 1.11, lidMetal: 0.37, lidGlass: 0.045,
        lidCorner: 0.16, curveHeight: 0.62, curveWidth: 0.9, portCenter: 0.37,
        ports: [(.magSafe, 2.81), (.thunderbolt, 4.63), (.thunderbolt, 6.12), (.headphone, 7.41)],
        feet: [1.716, 18.337], footTop: 2.07, footBottom: 1.79, footHeight: 0.15,
        vent: 9.07...19.48, hingeDrop: 0.70, hingeGap: 0.18,
        displayHeight: 19.64, topBezel: 0.56)
    case .pro16:
      return Chassis(
        isPro: true, depth: 24.81, baseHeight: 1.22, lidMetal: 0.39, lidGlass: 0.07,
        lidCorner: 0.16, curveHeight: 0.62, curveWidth: 0.9, portCenter: 0.375,
        ports: [(.magSafe, 3.58), (.thunderbolt, 5.43), (.thunderbolt, 6.93), (.headphone, 8.21)],
        feet: [1.72, 21.03], footTop: 2.05, footBottom: 1.79, footHeight: 0.15,
        vent: 9.81...22.42, hingeDrop: 0.76, hingeGap: 0.24,
        displayHeight: 22.34, topBezel: 0.54)
    case .air13:
      return Chassis(
        isPro: false, depth: 21.5, baseHeight: 0.74, lidMetal: 0.32, lidGlass: 0.06,
        lidCorner: 0.07, curveHeight: 0.37, curveWidth: 0.45, portCenter: 0.22,
        ports: [(.magSafe, 2.27), (.thunderbolt, 4.14), (.thunderbolt, 5.64)],
        feet: [1.43, 18.02], footTop: 1.98, footBottom: 1.76, footHeight: 0.14,
        vent: nil, hingeDrop: 0.52, hingeGap: 0.09,
        displayHeight: 18.87, topBezel: 0.64)
    case .air15:
      return Chassis(
        isPro: false, depth: 23.76, baseHeight: 0.76, lidMetal: 0.32, lidGlass: 0.06,
        lidCorner: 0.07, curveHeight: 0.37, curveWidth: 0.45, portCenter: 0.21,
        ports: [(.magSafe, 3.30), (.thunderbolt, 5.11), (.thunderbolt, 6.58)],
        feet: [1.49, 20.22], footTop: 2.00, footBottom: 1.80, footHeight: 0.14,
        vent: nil, hingeDrop: 0.52, hingeGap: 0.09,
        displayHeight: 21.14, topBezel: 0.68)
    }
  }

  var finish: (red: Double, green: Double, blue: Double) {
    let isPro = model == .pro14 || model == .pro16
    let hex: UInt32
    switch color {
    case 2 where isPro: hex = 0xBCBCBF
    case 2: hex = 0xB0B0B3
    case 7: hex = 0x59626F
    case 8: hex = 0xE9E2D8
    case 9: hex = 0x555257
    case 11: hex = 0xCCD8DF
    default: hex = 0xDFE0E2
    }
    return (
      Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255
    )
  }

  func shade(_ factor: Double) -> Color {
    let base = finish
    return Color(
      .sRGB, red: min(base.red * factor, 1), green: min(base.green * factor, 1),
      blue: min(base.blue * factor, 1))
  }

  func gradient(_ stops: [(Double, Double)]) -> Gradient {
    Gradient(stops: stops.map { Gradient.Stop(color: shade($0.1), location: $0.0) })
  }

  var baseShading: Gradient {
    chassis.isPro
      ? gradient([
        (0, 1.02), (0.2, 0.99), (0.35, 0.95), (0.5, 0.82), (0.62, 0.63), (0.74, 0.5), (0.8, 0.52),
        (0.88, 0.66), (0.92, 0.7), (0.96, 0.55), (1, 0.25),
      ])
      : gradient([
        (0, 1.12), (0.03, 1.0), (0.29, 1.0), (0.64, 0.6), (0.91, 0.9), (0.96, 0.84), (1, 0.6),
      ])
  }

  var endShading: [(Double, Double)] {
    chassis.isPro
      ? [
        (0, 0.7), (0.11, 0.66), (0.33, 1.05), (0.5, 0.82), (0.72, 0.56), (1.0, 0.64), (1.6, 0.75),
        (3.0, 0.9), (5.0, 1.0),
      ]
      : [(0, 0.8), (0.04, 0.75), (0.18, 1.16), (0.26, 1.06), (0.53, 0.74), (1.0, 0.92), (1.4, 1.0)]
  }

  var lidShading: Gradient {
    chassis.isPro
      ? gradient([(0, 0.56), (0.05, 1.13), (0.15, 1.0), (1, 1.0)])
      : gradient([(0, 1.0), (0.05, 1.15), (0.2, 1.0), (1, 1.0)])
  }

  private static func detect() -> MacLook {
    let model = hardwareModel()
    let color = housingColor() ?? 1
    let deviceModel = UTTagClass(rawValue: "com.apple.device-model-code")
    let identifier =
      UTType(tag: "\(model)@ECOLOR=\(color)", tagClass: deviceModel, conformingTo: nil)?.identifier
      ?? ""
    let kind: Model
    if identifier.contains("macbookair-15") {
      kind = .air15
    } else if identifier.contains("macbookair") || model.hasPrefix("MacBookAir") {
      kind = .air13
    } else if identifier.contains("macbookpro-16") {
      kind = .pro16
    } else {
      kind = .pro14
    }
    return MacLook(model: kind, color: color)
  }

  private static func hardwareModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var buffer = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buffer, &size, nil, 0)
    return String(cString: buffer)
  }

  private static func housingColor() -> Int? {
    let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/chosen")
    guard entry != 0 else { return nil }
    defer { IOObjectRelease(entry) }
    guard
      let data = IORegistryEntryCreateCFProperty(
        entry, "housing-color" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? Data,
      data.count >= 4
    else { return nil }
    let value = data.suffix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    return Int(value)
  }
}

struct LidPicture: View {
  @ObservedObject var lid: LidReading
  let openAngle: Double
  let active: Bool
  let available: Bool
  var folding = false
  var scale = MacLook.pointsPerCentimeter
  var centered = false
  var look = MacLook.current

  private var hinge: CGPoint { CGPoint(x: length * 0.55 + 10, y: length + 32) }
  private var canvas: CGSize {
    CGSize(
      width: centered ? 2 * hinge.x + length : hinge.x + length + 4,
      height: hinge.y + baseHeight + points(look.chassis.footHeight) + 10)
  }

  private func points(_ centimeters: Double) -> CGFloat {
    CGFloat(centimeters) * scale
  }

  private var length: CGFloat { points(look.chassis.depth) }
  private var baseHeight: CGFloat { points(look.chassis.baseHeight) }
  private var lidThickness: CGFloat { points(look.chassis.lidThickness) }
  private var glowWidth: CGFloat { min(1.6, lidThickness * 0.5) }
  private var hingeDrop: CGFloat { points(look.chassis.hingeDrop) }
  private var hingeGap: CGFloat { points(look.chassis.hingeGap) }
  private var pivot: CGPoint {
    CGPoint(x: (hingeDrop - hingeGap) / 2, y: (hingeDrop + hingeGap) / 2)
  }

  var body: some View {
    let live = available ? lid.degrees : nil
    let angle = min(max(live ?? openAngle, 0), 180)
    let lidAnchor = UnitPoint(
      x: pivot.x / length, y: (lidThickness + pivot.y) / (lidThickness + hingeGap))
    let screenAngle = folding ? max(angle, min(max(openAngle, 0), 180)) : angle
    ZStack(alignment: .topLeading) {
      Ellipse()
        .fill(Color.black.opacity(0.12))
        .frame(width: length + 22, height: 10)
        .blur(radius: 5)
        .offset(x: hinge.x - 11, y: hinge.y + baseHeight)
      guide(angle: openAngle)
      ZStack(alignment: .topLeading) {
        screenLight
          .rotationEffect(.degrees(-screenAngle), anchor: lidAnchor)
          .offset(x: hinge.x, y: hinge.y - lidThickness)
      }
      .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
      .mask(alignment: .topLeading) {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 2 * length / (hinge.y + 2 * length + 1)),
            .init(color: .black, location: (2 * length + 24) / (hinge.y + 2 * length + 1)),
            .init(color: .black, location: (hinge.y + 2 * length - 3) / (hinge.y + 2 * length + 1)),
            .init(color: .clear, location: 1),
          ], startPoint: .top, endPoint: .bottom
        )
        .frame(width: canvas.width + 2 * length, height: hinge.y + 2 * length + 1)
        .offset(x: -length, y: -2 * length)
      }
      lidBar
        .rotationEffect(.degrees(-angle), anchor: lidAnchor)
        .offset(x: hinge.x, y: hinge.y - lidThickness)
        .opacity(live == nil ? 0.35 : 1)
      screenGlow
        .zIndex(1)
        .rotationEffect(.degrees(-screenAngle), anchor: lidAnchor)
        .offset(x: hinge.x, y: hinge.y - lidThickness)
      base
        .offset(x: hinge.x, y: hinge.y)
    }
    .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    .animation(.smooth(duration: 0.2), value: angle)
    .animation(.smooth(duration: 0.4), value: openAngle)
    .animation(.easeInOut(duration: 0.3), value: active)
    .animation(.smooth(duration: 0.35), value: folding)
    .accessibilityElement()
    .accessibilityLabel(Text("Lid angle"))
    .accessibilityValue(Text(verbatim: degrees(angle)))
  }

  private func baseOutline(_ height: CGFloat) -> Path {
    let chassis = look.chassis
    let curveTop = height - points(chassis.curveHeight)
    let width = points(chassis.curveWidth)
    let controlY = curveTop + points(chassis.curveHeight) * 0.58
    let controlX = width * (chassis.isPro ? 0.33 : 0.42)
    var path = Path()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: length, y: 0))
    path.addLine(to: CGPoint(x: length, y: curveTop))
    path.addCurve(
      to: CGPoint(x: length - width, y: height), control1: CGPoint(x: length, y: controlY),
      control2: CGPoint(x: length - controlX, y: height))
    path.addLine(to: CGPoint(x: width, y: height))
    path.addCurve(
      to: CGPoint(x: 0, y: curveTop), control1: CGPoint(x: controlX, y: height),
      control2: CGPoint(x: 0, y: controlY))
    path.closeSubpath()
    return path
  }

  private func shadeEnds(of shape: Path, in context: inout GraphicsContext) {
    let stops = look.endShading
    let last = stops.last?.0 ?? 1
    let reach = points(last)
    let darken = Gradient(
      stops: stops.map { Gradient.Stop(color: Color(white: min($0.1, 1)), location: $0.0 / last) })
    let finish = look.finish
    let lighten = Gradient(
      stops: stops.map { stop in
        let lift = { (channel: Double) in max(min(channel * stop.1, 1) - channel, 0) }
        return Gradient.Stop(
          color: Color(
            .sRGB, red: lift(finish.red), green: lift(finish.green), blue: lift(finish.blue)),
          location: stop.0 / last)
      })
    for fromRear in [true, false] {
      let start = CGPoint(x: fromRear ? 0 : length, y: 0)
      let end = CGPoint(x: fromRear ? reach : length - reach, y: 0)
      let band = Path(CGRect(x: fromRear ? 0 : length - reach, y: -1, width: reach, height: 400))
      var multiply = context
      multiply.clip(to: shape)
      multiply.blendMode = .multiply
      multiply.fill(band, with: .linearGradient(darken, startPoint: start, endPoint: end))
      var add = context
      add.clip(to: shape)
      add.blendMode = .plusLighter
      add.fill(band, with: .linearGradient(lighten, startPoint: start, endPoint: end))
    }
  }

  private var base: some View {
    let chassis = look.chassis
    let height = baseHeight
    let footHeight = points(chassis.footHeight)
    return Canvas { context, _ in
      for start in chassis.feet {
        let top = points(chassis.footTop)
        let bottom = points(chassis.footBottom)
        let inset = (top - bottom) / 2
        let x = points(start)
        var foot = Path()
        foot.move(to: CGPoint(x: x, y: height - 1))
        foot.addLine(to: CGPoint(x: x + top, y: height - 1))
        foot.addLine(to: CGPoint(x: x + top - inset, y: height + footHeight))
        foot.addLine(to: CGPoint(x: x + inset, y: height + footHeight))
        foot.closeSubpath()
        context.fill(
          foot,
          with: .linearGradient(
            Gradient(colors: [Color(white: 0.42), Color(white: 0.16), Color(white: 0.1)]),
            startPoint: CGPoint(x: 0, y: height), endPoint: CGPoint(x: 0, y: height + footHeight)))
      }
      let outline = baseOutline(height)
      context.fill(
        outline,
        with: .linearGradient(
          look.baseShading, startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
      shadeEnds(of: outline, in: &context)
      context.drawLayer { layer in
        layer.clip(to: outline)
        if let vent = chassis.vent {
          let slot = CGRect(
            x: points(vent.lowerBound), y: height * 0.84,
            width: points(vent.upperBound - vent.lowerBound), height: height * 0.07)
          layer.fill(
            Path(roundedRect: slot, cornerRadius: slot.height / 2),
            with: .color(Color.black.opacity(0.55)))
          layer.fill(
            Path(
              CGRect(
                x: slot.minX + slot.height, y: slot.maxY, width: slot.width - slot.height * 2,
                height: 0.5)),
            with: .color(Color.white.opacity(0.18)))
        }
        for item in chassis.ports {
          drawPort(item.port, at: points(item.center), in: &layer)
        }
      }
      context.stroke(outline, with: .color(Color.primary.opacity(0.14)), lineWidth: 0.5)
    }
    .frame(width: length, height: height + footHeight + 1, alignment: .topLeading)
  }

  private func drawPort(_ port: MacLook.Port, at center: CGFloat, in context: inout GraphicsContext)
  {
    let chassis = look.chassis
    let y = points(chassis.portCenter)
    let rim = look.shade(chassis.isPro ? 1.35 : 1.2)
    switch port {
    case .magSafe:
      let outer = CGRect(
        x: center - points(0.865), y: y - points(0.16), width: points(1.73), height: points(0.32))
      context.fill(
        Path(roundedRect: outer, cornerRadius: outer.height / 2),
        with: .color(look.shade(chassis.isPro ? 0.82 : 0.86)))
      context.stroke(
        Path(roundedRect: outer, cornerRadius: outer.height / 2), with: .color(rim),
        lineWidth: 0.35)
      let strip = CGRect(
        x: center - points(0.53), y: y - points(0.06), width: points(1.06), height: points(0.12))
      context.fill(
        Path(roundedRect: strip, cornerRadius: strip.height / 2),
        with: .color(chassis.isPro ? Color(white: 0.05) : Color(red: 0.85, green: 0.86, blue: 0.87))
      )
      for index in 0..<5 {
        let pinX = center + points(0.187 * Double(index - 2))
        let pin = CGRect(
          x: pinX - points(0.018), y: y - points(0.018), width: points(0.036),
          height: points(0.036))
        context.fill(
          Path(ellipseIn: pin),
          with: .color(
            chassis.isPro ? Color(white: 0.62) : Color(red: 0.55, green: 0.5, blue: 0.46)))
      }
    case .thunderbolt:
      let outer = CGRect(
        x: center - points(0.42), y: y - points(0.1325), width: points(0.84),
        height: points(0.265))
      context.fill(
        Path(roundedRect: outer, cornerRadius: outer.height / 2),
        with: .color(chassis.isPro ? Color(white: 0.04) : Color(red: 0.11, green: 0.13, blue: 0.17))
      )
      context.stroke(
        Path(roundedRect: outer, cornerRadius: outer.height / 2), with: .color(look.shade(0.6)),
        lineWidth: 0.3)
      let tongue = CGRect(
        x: center - points(0.305), y: y - points(0.03), width: points(0.61), height: points(0.06))
      context.fill(
        Path(roundedRect: tongue, cornerRadius: tongue.height / 2),
        with: .color(chassis.isPro ? Color(white: 0.24) : Color(red: 0.45, green: 0.49, blue: 0.54))
      )
    case .headphone:
      let hole = CGRect(
        x: center - points(0.185), y: y - points(0.185), width: points(0.37), height: points(0.37))
      context.fill(Path(ellipseIn: hole), with: .color(Color(white: 0.03)))
      context.stroke(Path(ellipseIn: hole), with: .color(look.shade(0.6)), lineWidth: 0.3)
    }
  }

  private var lidBar: some View {
    let chassis = look.chassis
    let metal = points(chassis.lidMetal)
    let glass = points(chassis.lidGlass)
    let corner = points(chassis.lidCorner)
    let blockWidth = hingeDrop * 0.44
    return Canvas { context, _ in
      let shell = Path(
        roundedRect: CGRect(x: 0, y: 0, width: length, height: metal + glass),
        cornerRadii: RectangleCornerRadii(
          topLeading: corner, bottomLeading: 0.3, bottomTrailing: 0.3, topTrailing: corner),
        style: .continuous)
      context.fill(
        shell,
        with: .linearGradient(
          look.lidShading, startPoint: .zero, endPoint: CGPoint(x: 0, y: metal + glass)))
      shadeEnds(of: shell, in: &context)
      context.drawLayer { layer in
        layer.clip(to: shell)
        layer.fill(
          Path(CGRect(x: 0, y: metal, width: length, height: glass)),
          with: .color(Color(white: 0.04)))
      }
      context.stroke(shell, with: .color(Color.primary.opacity(0.14)), lineWidth: 0.5)
      context.fill(
        Path(CGRect(x: 0, y: metal + glass, width: blockWidth, height: hingeGap)),
        with: .color(look.shade(0.45)))
    }
    .frame(width: length, height: lidThickness + hingeGap, alignment: .topLeading)
  }

  private var screenGlow: some View {
    Rectangle()
      .fill(Color.accentColor)
      .frame(width: points(look.chassis.displayHeight), height: glowWidth)
      .shadow(color: Color.accentColor.opacity(0.9), radius: 5)
      .offset(
        x: length - points(look.chassis.topBezel + look.chassis.displayHeight),
        y: lidThickness - glowWidth
      )
      .frame(width: length, height: lidThickness + hingeGap, alignment: .topLeading)
      .opacity(active ? 1 : 0)
  }

  private var screenLight: some View {
    let width = points(look.chassis.displayHeight)
    let start = length - points(look.chassis.topBezel + look.chassis.displayHeight)
    let layers = (1...8).map {
      index -> (reach: CGFloat, spread: CGFloat, strength: Double, softness: CGFloat) in
      let step = Double(index) / 8
      return (
        CGFloat(0.04 + 0.72 * pow(step, 1.5)), CGFloat(0.5 * pow(step, 1.6)),
        0.22 * pow(1 - step, 1.3) + 0.02, CGFloat(1 + 22 * step)
      )
    }
    return ZStack(alignment: .topLeading) {
      ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
        let reach = width * layer.reach
        let spread = width * layer.spread
        Path { path in
          path.move(to: CGPoint(x: spread, y: 0))
          path.addLine(to: CGPoint(x: spread + width, y: 0))
          path.addLine(to: CGPoint(x: width + 2 * spread, y: reach))
          path.addLine(to: CGPoint(x: 0, y: reach))
          path.closeSubpath()
        }
        .fill(
          LinearGradient(
            colors: [
              Color.accentColor.opacity(layer.strength), Color.accentColor.opacity(0),
            ],
            startPoint: .top, endPoint: .bottom)
        )
        .frame(width: width + 2 * spread, height: reach)
        .blur(radius: layer.softness)
        .offset(x: start - spread, y: lidThickness)
      }
    }
    .frame(width: length, height: lidThickness + hingeGap, alignment: .topLeading)
    .mask(alignment: .topLeading) {
      let reach = width * 0.3
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: .black, location: reach / (width + 2 * reach)),
          .init(color: .black, location: (reach + width) / (width + 2 * reach)),
          .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing
      )
      .frame(width: width + 2 * reach, height: width * 3)
      .offset(x: start - reach, y: lidThickness)
    }
    .opacity(active ? 1 : 0)
  }

  private func guide(angle: Double) -> some View {
    let radians = CGFloat(angle) * .pi / 180
    let direction = CGVector(dx: cos(radians), dy: -sin(radians))
    let start = CGPoint(
      x: hinge.x + pivot.x - pivot.x * cos(radians) - pivot.y * sin(radians),
      y: hinge.y + pivot.y + pivot.x * sin(radians) - pivot.y * cos(radians))
    let tip = CGPoint(
      x: start.x + direction.dx * (length + 16), y: start.y + direction.dy * (length + 16))
    return ZStack(alignment: .topLeading) {
      Path { path in
        path.move(to: start)
        path.addLine(
          to: CGPoint(x: start.x + direction.dx * length, y: start.y + direction.dy * length))
      }
      .stroke(Color.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
      Text(verbatim: degrees(angle))
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .fixedSize()
        .position(tip)
    }
    .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
  }

}
