import AppKit
import Carbon.HIToolbox
import SwiftUI

enum LocalEdition {
  static let isLocal = Bundle.main.object(forInfoDictionaryKey: "SoftfoldLocalBuild") as? Bool ?? false
  static let name = "Uduo"
  static var projectURL: URL? {
    (Bundle.main.object(forInfoDictionaryKey: "UduoProjectURL") as? String).flatMap(URL.init(string:))
  }
  static var shortcut: String { isLocal ? "⌃⌥⇧H" : "⌃⌥H" }
  static var hotKeyModifiers: UInt32 {
    UInt32(controlKey | optionKey | (isLocal ? shiftKey : 0))
  }
}

@main
struct UduoApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @StateObject private var desktop: LiveDesktop
  @StateObject private var updater = Updater()
  @AppStorage("showsMenuBarIcon") private var showsMenuBarIcon = true

  init() {
    let defaults = UserDefaults.standard
    if !defaults.bool(forKey: "migratedSoftfoldSettings") {
      let previous = defaults.persistentDomain(forName: "com.reffwu.softfold.local") ?? [:]
      let keys = [
        "openAngle", "focusesWhenHeld", "showsInDock", "showsMenuBarIcon",
        "AppleLanguages", "effectEnabled", "setUpOnFirstEnable",
      ]
      for key in keys {
        if defaults.object(forKey: key) == nil, let value = previous[key] {
          defaults.set(value, forKey: key)
        }
      }
      defaults.set(true, forKey: "migratedSoftfoldSettings")
    }
    _desktop = StateObject(wrappedValue: LiveDesktop())
  }

  var body: some Scene {
    Window(LocalEdition.name, id: "main") {
      MainView(desktop: desktop, updater: updater, delegate: delegate)
        .onAppear {
          delegate.onTerminate = { desktop.shutDown() }
          delegate.installToggleHotKey {
            if !desktop.isStarting { desktop.setEnabled(!desktop.isEnabled) }
          }
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .defaultPosition(.center)
    .commands {
      WindowCommands()
      CommandGroup(after: .appInfo) {
        if !LocalEdition.isLocal {
          Button("Check for Updates…") { updater.checkForUpdates() }
        }
      }
    }
    Window("About \(LocalEdition.name)", id: "about") {
      AboutView()
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .defaultPosition(.center)
    MenuBarExtra(isInserted: $showsMenuBarIcon) {
      MenuBarPanel(desktop: desktop, updater: updater)
    } label: {
      Image(desktop.isActive ? "MenuBarIconActive" : "MenuBarIcon")
        .renderingMode(.template)
        .accessibilityLabel(Text(verbatim: LocalEdition.name))
    }
    .menuBarExtraStyle(.window)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var onTerminate: (() -> Void)?
  var onReopen: (() -> Void)?
  private var toggleHotKey: EventHotKeyRef?
  private var hotKeyHandler: EventHandlerRef?

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    guard let onReopen else { return true }
    onReopen()
    return false
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    DockIcon.apply()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let toggleHotKey { UnregisterEventHotKey(toggleHotKey) }
    if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    onTerminate?()
  }

  func installToggleHotKey(_ action: @escaping () -> Void) {
    onToggle = action
    guard toggleHotKey == nil else { return }
    var event = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    var handler: EventHandlerRef?
    let context = Unmanaged.passUnretained(self).toOpaque()
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in delegate.onToggle?() }
        return noErr
      }, 1, &event, context, &handler)
    guard handlerStatus == noErr else {
      showHotKeyError(handlerStatus)
      return
    }
    var hotKey: EventHotKeyRef?
    let hotKeyStatus = RegisterEventHotKey(
      UInt32(kVK_ANSI_H), LocalEdition.hotKeyModifiers,
      EventHotKeyID(signature: OSType(0x484E_4745), id: 1), GetApplicationEventTarget(), 0,
      &hotKey)
    guard hotKeyStatus == noErr else {
      if let handler { RemoveEventHandler(handler) }
      showHotKeyError(hotKeyStatus)
      return
    }
    hotKeyHandler = handler
    toggleHotKey = hotKey
  }

  private var onToggle: (() -> Void)?

  private func showHotKeyError(_ status: OSStatus) {
    let alert = NSAlert()
    alert.messageText = String(localized: "Keyboard shortcut unavailable")
    alert.informativeText = "\(LocalEdition.name): \(LocalEdition.shortcut) (\(status))"
    alert.alertStyle = .warning
    alert.runModal()
  }
}

struct WindowCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("About Uduo") {
        openWindow(id: "about")
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    CommandGroup(replacing: .appSettings) {
      Button("Settings…") {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }
      .keyboardShortcut(",")
    }
  }
}

struct MenuBarPanel: View {
  @ObservedObject var desktop: LiveDesktop
  @ObservedObject var updater: Updater
  @ObservedObject private var starRequest = StarRequest.shared
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 12) {
      LidPicture(
        lid: desktop.lid, openAngle: desktop.openAngle, active: desktop.isActive,
        available: desktop.sensorAvailable, folding: desktop.isFolding, centered: true
      )
      .padding(.top, 8)
      if starRequest.isVisible {
        StarRow()
          .panelCard()
          .transition(.opacity)
      }
      VStack(spacing: 0) {
        SettingsRow(
          title: desktop.statusTitle, subtitle: desktop.statusSubtitle,
          leading: { SettingsIcon(symbol: "power", tint: desktop.isActive ? .green : .gray) }
        ) {
          Toggle(
            "Turn Uduo on or off",
            isOn: Binding(get: { desktop.isEnabled }, set: { desktop.setEnabled($0) })
          )
          .toggleStyle(.switch)
          .labelsHidden()
          .disabled(desktop.isStarting)
          .help(Text(verbatim: LocalEdition.shortcut))
        }
        SettingsDivider()
        SettingsRow(
          "angle", tint: .indigo, title: String(localized: "Open position"),
          subtitle: degrees(desktop.openAngle)
        ) {
          if !desktop.isDefaultOpenAngle {
            Button {
              withAnimation(.smooth(duration: 0.4)) { desktop.restoreDefaultOpenPosition() }
            } label: {
              Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel(Text("Restore Default"))
            .controlSize(.small)
            .fixedSize()
            .help(Text("Go back to \(degrees(LiveDesktop.defaultOpenAngle))"))
          }
          Button("Use Current Angle") {
            withAnimation(.smooth(duration: 0.4)) { desktop.setOpenPosition() }
          }
          .controlSize(.small)
          .fixedSize()
          .disabled(!desktop.sensorAvailable || desktop.isStarting)
          .help("Save the lid angle you are viewing at right now")
        }
      }
      .panelCard()
      if let error = desktop.error {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text(error)
            .font(.system(size: 11))
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 4)
          if desktop.needsPermission {
            Button("Open Settings", action: openScreenRecordingSettings)
              .controlSize(.small)
          }
        }
        .padding(10)
        .panelCard()
      }
      Divider().padding(.horizontal, 6)
      VStack(spacing: 0) {
        PanelAction(symbol: "gearshape", title: String(localized: "Settings…"), shortcut: "⌘,") {
          openWindow(id: "main")
          NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        if !LocalEdition.isLocal {
          PanelAction(
            symbol: "arrow.triangle.2.circlepath", title: String(localized: "Check for Updates…")
          ) {
            updater.checkForUpdates()
          }
        }
        PanelAction(symbol: "power", title: String(localized: "Quit Uduo"), shortcut: "⌘Q") {
          NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 6)
    .frame(width: 330)
    .background(.regularMaterial)
  }
}

private struct PanelAction: View {
  let symbol: String
  let title: String
  var shortcut: String?
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .frame(width: 18)
        Text(verbatim: title)
          .font(.system(size: 13))
          .lineLimit(1)
        Spacer(minLength: 8)
        if let shortcut {
          Text(verbatim: shortcut)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, 8)
      .frame(height: 26)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color.primary.opacity(hovering ? 0.09 : 0))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

extension View {
  fileprivate func panelCard() -> some View {
    background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }
}

@MainActor
final class Updater: ObservableObject {
  @Published var installsAutomatically = false

  func checkForUpdates() {}
}
