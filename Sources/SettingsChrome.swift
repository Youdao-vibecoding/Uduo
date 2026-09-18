import AppKit
import SwiftUI

enum SettingsMetrics {
  static let groupSpacing: CGFloat = 22
  static let cardCorner: CGFloat = 18
  static let rowPaddingH: CGFloat = 16
  static let rowPaddingV: CGFloat = 13
  static let iconSize: CGFloat = 22
  static let dividerInset: CGFloat = rowPaddingH + iconSize + 11
}

struct SettingsGroup<Content: View>: View {
  var title: String?
  var footnote: String?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      if let title {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.leading, 4)
      }
      VStack(spacing: 0) { content }
        .background(SettingsSurface())
      if let footnote {
        Text(footnote)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.leading, 2)
          .padding(.top, 1)
      }
    }
  }
}

struct SettingsIcon: View {
  let symbol: String
  var tint = Color.accentColor

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 16, weight: .regular))
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(symbol == "exclamationmark.triangle.fill" ? tint : .secondary)
      .frame(width: SettingsMetrics.iconSize, height: SettingsMetrics.iconSize)
      .accessibilityHidden(true)
  }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
  let title: String
  var subtitle: String?
  @ViewBuilder var leading: Leading
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(alignment: .center, spacing: 11) {
      leading
        .frame(width: SettingsMetrics.iconSize, height: SettingsMetrics.iconSize)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 10)
      trailing
    }
    .padding(.horizontal, SettingsMetrics.rowPaddingH)
    .padding(.vertical, SettingsMetrics.rowPaddingV)
  }
}

struct SettingsSurface: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    RoundedRectangle(cornerRadius: SettingsMetrics.cardCorner, style: .continuous)
      .fill(
        Color(nsColor: .controlBackgroundColor)
          .opacity(reduceTransparency ? 1 : (colorScheme == .dark ? 0.78 : 0.76))
      )
      .overlay {
        RoundedRectangle(cornerRadius: SettingsMetrics.cardCorner, style: .continuous)
          .strokeBorder(.primary.opacity(colorScheme == .dark ? 0.09 : 0.045), lineWidth: 0.5)
      }
  }
}

struct SettingsWindowMaterial: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .underWindowBackground
    view.blendingMode = .behindWindow
    view.state = .followsWindowActiveState
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct CapsuleActionStyle: ButtonStyle {
  var emphasized = false
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(emphasized ? Color.accentColor : Color.primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background {
        if reduceTransparency {
          Capsule().fill(Color(nsColor: .controlBackgroundColor))
        } else {
          Capsule().fill(.regularMaterial)
        }
      }
      .overlay {
        Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
      }
      .brightness(configuration.isPressed ? -0.05 : 0)
      .opacity(isEnabled ? 1 : 0.4)
      .contentShape(Capsule())
  }
}

extension SettingsRow where Leading == SettingsIcon {
  init(
    _ symbol: String, tint: Color = .accentColor, title: String, subtitle: String? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(
      title: title, subtitle: subtitle, leading: { SettingsIcon(symbol: symbol, tint: tint) },
      trailing: trailing)
  }
}

struct SettingsDivider: View {
  var inset = SettingsMetrics.dividerInset

  var body: some View {
    Divider()
      .opacity(0.5)
      .padding(.leading, inset)
  }
}

func openScreenRecordingSettings() {
  guard
    let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
  else { return }
  NSWorkspace.shared.open(url)
}
