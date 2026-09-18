import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

private enum Brand {
  static let acid = Color(red: 0.945, green: 1, blue: 0.16)
  static let paper = Color(red: 0.945, green: 0.945, blue: 0.93)
  static let ink = Color(red: 0.07, green: 0.075, blue: 0.07)
}

private struct UduoIcon: View {
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 1024, y: size.height / 1024)
      let tile = Path(roundedRect: CGRect(x: 80, y: 72, width: 864, height: 864), cornerRadius: 195)
      var shadow = context
      shadow.addFilter(.shadow(color: .black.opacity(0.26), radius: 17, x: 0, y: 14))
      shadow.fill(tile, with: .color(Brand.ink))
      context.fill(
        tile,
        with: .linearGradient(
          Gradient(colors: [Color(white: 0.18), Color(white: 0.065)]),
          startPoint: CGPoint(x: 160, y: 80), endPoint: CGPoint(x: 864, y: 960)))
      context.stroke(tile, with: .color(.white.opacity(0.14)), lineWidth: 2)
      var mark = Path()
      mark.move(to: CGPoint(x: 284, y: 302))
      mark.addQuadCurve(to: CGPoint(x: 306, y: 280), control: CGPoint(x: 284, y: 280))
      mark.addLine(to: CGPoint(x: 386, y: 280))
      mark.addQuadCurve(to: CGPoint(x: 404, y: 298), control: CGPoint(x: 404, y: 280))
      mark.addLine(to: CGPoint(x: 404, y: 556))
      mark.addCurve(
        to: CGPoint(x: 512, y: 674), control1: CGPoint(x: 404, y: 635),
        control2: CGPoint(x: 438, y: 674))
      mark.addCurve(
        to: CGPoint(x: 620, y: 556), control1: CGPoint(x: 586, y: 674),
        control2: CGPoint(x: 620, y: 635))
      mark.addLine(to: CGPoint(x: 620, y: 399))
      mark.addLine(to: CGPoint(x: 740, y: 280))
      mark.addLine(to: CGPoint(x: 740, y: 556))
      mark.addCurve(
        to: CGPoint(x: 512, y: 794), control1: CGPoint(x: 740, y: 714),
        control2: CGPoint(x: 649, y: 794))
      mark.addCurve(
        to: CGPoint(x: 284, y: 556), control1: CGPoint(x: 375, y: 794),
        control2: CGPoint(x: 284, y: 714))
      mark.closeSubpath()
      context.fill(
        mark,
        with: .linearGradient(
          Gradient(colors: [Brand.acid, Color(red: 0.86, green: 0.94, blue: 0.07)]),
          startPoint: CGPoint(x: 384, y: 280), endPoint: CGPoint(x: 640, y: 800)))
      var fold = Path()
      fold.move(to: CGPoint(x: 620, y: 399))
      fold.addLine(to: CGPoint(x: 620, y: 308))
      fold.addQuadCurve(to: CGPoint(x: 648, y: 280), control: CGPoint(x: 620, y: 280))
      fold.addLine(to: CGPoint(x: 740, y: 280))
      fold.closeSubpath()
      context.fill(
        fold,
        with: .linearGradient(
          Gradient(colors: [Color(red: 0.98, green: 1, blue: 0.65), Brand.acid]),
          startPoint: CGPoint(x: 620, y: 280), endPoint: CGPoint(x: 724, y: 386)))
      var crease = Path()
      crease.move(to: CGPoint(x: 621, y: 398))
      crease.addLine(to: CGPoint(x: 738, y: 281))
      context.stroke(crease, with: .color(Brand.ink.opacity(0.2)), lineWidth: 2.5)
    }
  }
}

private struct BrandPreview: View {
  var english = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 19) {
        UduoIcon().frame(width: 94, height: 94)
        VStack(alignment: .leading, spacing: 4) {
          Text(verbatim: "Uduo")
            .font(.system(size: 54, weight: .semibold, design: .rounded))
            .tracking(-2)
          Text(
            verbatim: copy("让桌面跟着屏幕开合。", "Your MacBook moves. Your desktop follows."))
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Brand.ink.opacity(0.62))
        }
        Spacer()
        Text(verbatim: "APP PREVIEW")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .tracking(1.8)
          .padding(.horizontal, 21)
          .padding(.vertical, 14)
          .background(.white, in: Capsule())
      }
      .padding(.horizontal, 42)
      .padding(.top, 34)
      HStack(alignment: .top, spacing: 0) {
        state(
          "01", title: copy("展开", "Open"), subtitle: copy("清晰如常", "Crisp and clear"),
          progress: 0)
        state(
          "02", title: copy("轻合", "Closing"), subtitle: copy("渐变模糊", "Progressive blur"),
          progress: 0.3)
        state(
          "03", title: copy("收拢", "Folded"), subtitle: copy("随角度加深", "A deeper fold"),
          progress: 0.6)
      }
      .padding(.top, 44)
      .padding(.horizontal, 20)
      Spacer(minLength: 30)
      HStack(alignment: .center, spacing: 46) {
        VStack(alignment: .leading, spacing: 14) {
          Text(verbatim: copy("每一度，都有回应。", "Every degree makes a difference."))
            .font(.system(size: 28, weight: .semibold))
          Text(
            verbatim: copy(
              "屏幕上缘渐渐柔和，靠近转轴处保持清晰。", "Soft blur at the top. Clarity near the hinge."))
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.64))
          HStack(spacing: 8) {
            Image(systemName: "laptopcomputer")
            Text(
              verbatim: copy(
                "为配备开合角度传感器的 Mac 而作",
                "Apple silicon MacBooks with a supported lid sensor"))
          }
          .font(.system(size: 13))
          .foregroundStyle(Brand.acid)
          .padding(.top, 10)
        }
        Spacer(minLength: 0)
        VStack(alignment: .leading, spacing: 15) {
          HStack(alignment: .firstTextBaseline) {
            Text(verbatim: copy("开始折叠的角度", "Start folding below"))
              .font(.system(size: 17, weight: .semibold))
            Spacer()
            Text(verbatim: "95°")
              .font(.system(size: 35, weight: .medium, design: .rounded))
          }
          HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<20, id: \.self) { index in
              RoundedRectangle(cornerRadius: 2)
                .fill(index <= 14 ? Brand.acid : .white.opacity(0.14))
                .frame(height: index % 5 == 0 || index == 19 ? 28 : 18)
            }
          }
          .frame(height: 28)
          HStack {
            Text(verbatim: "25°")
            Spacer()
            Text(verbatim: copy("可调范围", "Adjustable range"))
            Spacer()
            Text(verbatim: "120°")
          }
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.58))
        }
        .frame(width: 350)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 48)
      .padding(.vertical, 36)
      .frame(maxWidth: .infinity)
      .background(Brand.ink)
    }
    .frame(width: 1360, height: 790)
    .foregroundStyle(Brand.ink)
    .background(Brand.paper)
    .preferredColorScheme(.light)
  }

  private func copy(_ chinese: String, _ englishText: String) -> String {
    english ? englishText : chinese
  }

  private func state(
    _ number: String, title: String, subtitle: String, progress: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 17) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(verbatim: number)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(Brand.ink.opacity(0.42))
        Text(verbatim: title)
          .font(.system(size: 20, weight: .semibold))
        Text(verbatim: subtitle)
          .font(.system(size: 13))
          .foregroundStyle(Brand.ink.opacity(0.54))
      }
      .padding(.leading, 30)
      FoldShowcase(progress: progress, active: true)
        .frame(width: 440, height: 300)
    }
  }
}

private struct MotionPreview: View {
  let progress: Double

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(verbatim: "Uduo")
          .font(.system(size: 25, weight: .semibold, design: .rounded))
        Spacer()
        Text(verbatim: "Illustrated preview")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Brand.ink.opacity(0.56))
      }
      .padding(.horizontal, 30)
      .padding(.top, 23)
      FoldShowcase(progress: progress, active: true)
        .frame(width: 690, height: 368)
      HStack(spacing: 10) {
        Text(verbatim: "OPEN")
        GeometryReader { geometry in
          Capsule().fill(Brand.ink.opacity(0.10))
          Capsule().fill(Brand.ink)
            .frame(width: max(5, geometry.size.width * progress))
        }
        .frame(width: 154, height: 5)
        Text(verbatim: "CLOSED")
      }
      .font(.system(size: 9, weight: .semibold, design: .monospaced))
      .foregroundStyle(Brand.ink.opacity(0.5))
      .padding(.bottom, 23)
    }
    .frame(width: 720, height: 460)
    .foregroundStyle(Brand.ink)
    .background(Brand.paper)
    .preferredColorScheme(.light)
  }
}

@main
private enum RenderBrandAssets {
  @MainActor static func main() throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let icons = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
    let docs = root.appendingPathComponent("docs")
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    for logicalSize in [16, 32, 128, 256, 512] {
      for scale in [1, 2] {
        let pixels = logicalSize * scale
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(logicalSize)x\(logicalSize)\(suffix).png"
        try write(
          UduoIcon().frame(width: CGFloat(pixels), height: CGFloat(pixels)),
          to: icons.appendingPathComponent(name), scale: 1)
      }
    }
    try write(
      UduoIcon().frame(width: 1024, height: 1024), to: docs.appendingPathComponent("icon.png"),
      scale: 1)
    try write(BrandPreview(), to: docs.appendingPathComponent("preview.png"), scale: 2)
    try write(
      BrandPreview(english: true), to: docs.appendingPathComponent("preview-en.png"), scale: 2)
    try writeAnimation(to: docs.appendingPathComponent("demo.gif"))
    print("Rendered Uduo icons, bilingual previews and a folding GIF from repository-native views.")
  }

  @MainActor private static func writeAnimation(to url: URL) throws {
    let frameCount = 50
    guard let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.gif.identifier as CFString, frameCount, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationSetProperties(
      destination,
      [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    let properties = [
      kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.08],
    ] as CFDictionary
    for index in 0..<frameCount {
      let progress = (1 - cos(2 * .pi * Double(index) / Double(frameCount))) / 2
      let renderer = ImageRenderer(content: MotionPreview(progress: progress))
      renderer.scale = 1
      guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
      CGImageDestinationAddImage(destination, image, properties)
    }
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    let bytes = try Data(contentsOf: url).count
    guard bytes <= 5_000_000 else {
      throw NSError(
        domain: "UduoBrandAssets", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "The preview GIF exceeds 5 MB."])
    }
    print("demo.gif: 720 x 460, 50 frames, 12.5 fps, 4 seconds, \(bytes) bytes.")
  }

  @MainActor private static func write<Content: View>(
    _ content: Content, to url: URL, scale: CGFloat
  ) throws {
    let renderer = ImageRenderer(content: content)
    renderer.scale = scale
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url)
  }
}
