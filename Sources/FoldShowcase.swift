import SwiftUI

struct FoldShowcase: View, Animatable {
  var progress: Double
  let active: Bool

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  private let accent = Color(red: 0.945, green: 1, blue: 0.22)
  private let graphite = Color(red: 0.105, green: 0.11, blue: 0.105)

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 440, size.height / 300)
      context.translateBy(x: (size.width - 440 * scale) / 2, y: (size.height - 300 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      var shadow = context
      shadow.addFilter(.blur(radius: 16))
      shadow.fill(
        Path(ellipseIn: CGRect(x: 69, y: 261, width: 324, height: 23)),
        with: .color(.black.opacity(0.17)))
      drawBase(in: context)
      drawDisplay(in: context)
    }
    .accessibilityHidden(true)
  }

  private func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat = 0) -> CGPoint {
    CGPoint(x: 195 + x * 0.94 + y * 0.25, y: 207 + x * 0.025 + y * 0.34 - z * 0.84)
  }

  private func quad(_ points: [CGPoint]) -> Path {
    Path { path in
      guard let first = points.first else { return }
      path.move(to: first)
      for point in points.dropFirst() { path.addLine(to: point) }
      path.closeSubpath()
    }
  }

  private func drawBase(in context: GraphicsContext) {
    let front = quad([
      point(-163, 197, 3), point(163, 197, 3), point(155, 202, -4),
      point(-155, 202, -4),
    ])
    context.fill(
      front,
      with: .linearGradient(
        Gradient(colors: [Color(white: 0.52), Color(white: 0.25)]),
        startPoint: point(0, 197, 3), endPoint: point(0, 202, -4)))
    let side = quad([
      point(163, 0, 3), point(163, 197, 3), point(155, 202, -4), point(158, 0, -4),
    ])
    context.fill(side, with: .color(Color(white: 0.31)))
    var surface = context
    let origin = point(-163, 0, 3)
    surface.concatenate(
      CGAffineTransform(a: 0.94, b: 0.025, c: 0.25, d: 0.34, tx: origin.x, ty: origin.y))
    let deck = Path(roundedRect: CGRect(x: 0, y: 0, width: 326, height: 197), cornerRadius: 10)
    surface.fill(
      deck,
      with: .linearGradient(
        Gradient(colors: [Color(white: 0.61), Color(white: 0.83), Color(white: 0.64)]),
        startPoint: .zero, endPoint: CGPoint(x: 320, y: 200)))
    surface.stroke(deck, with: .color(.white.opacity(0.7)), lineWidth: 1)
    surface.fill(
      Path(roundedRect: CGRect(x: 17, y: 14, width: 292, height: 94), cornerRadius: 6),
      with: .color(Color(white: 0.27)))
    for row in 0..<5 {
      for column in 0..<14 {
        let key = CGRect(x: 21 + CGFloat(column) * 20.25, y: 18 + CGFloat(row) * 17.4, width: 17, height: 13.3)
        let path = Path(roundedRect: key, cornerRadius: 2)
        surface.fill(path, with: .color(graphite))
        surface.stroke(path, with: .color(.white.opacity(0.19)), lineWidth: 0.6)
        if row < 4 {
          surface.fill(
            Path(roundedRect: CGRect(x: key.midX - 1.7, y: key.minY + 4, width: 3.4, height: 0.8), cornerRadius: 0.4),
            with: .color(.white.opacity(0.45)))
        }
      }
    }
    surface.fill(
      Path(roundedRect: CGRect(x: 97, y: 87, width: 131, height: 12), cornerRadius: 2),
      with: .color(graphite))
    let trackpad = Path(roundedRect: CGRect(x: 107, y: 119, width: 112, height: 60), cornerRadius: 6)
    surface.fill(trackpad, with: .color(Color(white: 0.73)))
    surface.stroke(trackpad, with: .color(.black.opacity(0.21)), lineWidth: 0.9)
    surface.fill(
      Path(roundedRect: CGRect(x: 143, y: 188, width: 40, height: 7), cornerRadius: 3),
      with: .color(.black.opacity(0.16)))
    var hinge = Path()
    hinge.move(to: point(-148, 1, 7))
    hinge.addLine(to: point(148, 1, 7))
    context.stroke(hinge, with: .color(graphite), style: StrokeStyle(lineWidth: 5, lineCap: .round))
  }

  private func drawDisplay(in context: GraphicsContext) {
    let angle = (108 * (1 - min(max(progress, 0), 1))) * .pi / 180
    let depth = CGFloat(cos(angle))
    let height = CGFloat(sin(angle))
    let origin = point(-163, 206 * depth, 8 + 206 * height)
    let projection = 0.84 * height - 0.34 * depth
    var lid = context
    lid.concatenate(
      CGAffineTransform(
        a: 0.94, b: 0.025, c: -0.25 * depth, d: projection,
        tx: origin.x, ty: origin.y))
    let shell = Path(roundedRect: CGRect(x: 0, y: 0, width: 326, height: 206), cornerRadius: 10)
    if projection > 0 {
      lid.fill(shell, with: .color(graphite))
      lid.stroke(shell, with: .color(Color(white: 0.53)), lineWidth: 1.4)
      drawWallpaper(in: lid)
      lid.fill(
        Path(roundedRect: CGRect(x: 142, y: 6, width: 42, height: 9), cornerRadius: 3),
        with: .color(graphite))
      lid.fill(Path(ellipseIn: CGRect(x: 161.5, y: 8, width: 3, height: 3)), with: .color(Color(white: 0.27)))
    } else {
      lid.fill(
        shell,
        with: .linearGradient(
          Gradient(colors: [Color(white: 0.76), Color(white: 0.58)]),
          startPoint: .zero, endPoint: CGPoint(x: 326, y: 206)))
      lid.stroke(shell, with: .color(.white.opacity(0.65)), lineWidth: 1)
      let mark = Path(roundedRect: CGRect(x: 151, y: 91, width: 24, height: 24), cornerRadius: 7)
      lid.fill(mark, with: .color(.black.opacity(0.15)))
      lid.stroke(
        Path(roundedRect: CGRect(x: 157, y: 97, width: 12, height: 12), cornerRadius: 3),
        with: .color(.white.opacity(0.38)), lineWidth: 1)
    }
  }

  private func drawWallpaper(in context: GraphicsContext) {
    var desktop = context
    let bounds = CGRect(x: 7, y: 6, width: 312, height: 187)
    desktop.clip(to: Path(roundedRect: bounds, cornerRadius: 5))
    drawDesktop(in: desktop)
    let fold = active ? min(max(progress, 0), 1) : 0
    guard fold > 0 else { return }
    let amount = 36 * sin(fold * .pi / 2)
    let levels: [(radius: Double, lower: Double, upper: Double)] = [
      (6, 0, 6), (16, 6, 16), (36, 16, 36),
    ]
    for level in levels where amount > level.lower {
      var blurred = desktop
      let stops = (0...16).map { index in
        let position = Double(index) / 16
        let opacity = min(max((amount * (1 - position) - level.lower) / (level.upper - level.lower), 0), 1)
        return Gradient.Stop(color: .white.opacity(opacity), location: position)
      }
      blurred.clipToLayer { mask in
        mask.fill(
          Path(bounds),
          with: .linearGradient(
            Gradient(stops: stops), startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
      }
      blurred.addFilter(.blur(radius: level.radius * bounds.width / 786, options: .opaque))
      blurred.drawLayer { layer in drawDesktop(in: layer) }
    }
    desktop.fill(
      Path(bounds),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: .black.opacity(fold * 0.10), location: 0),
          .init(color: .black.opacity(fold * 0.05), location: 0.425),
          .init(color: .clear, location: 0.85),
          .init(color: .clear, location: 1),
        ]),
        startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
        endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
    var corners = desktop
    corners.clipToLayer { mask in
      mask.fill(
        Path(bounds),
        with: .linearGradient(
          Gradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white.opacity(0.5), location: 0.425),
            .init(color: .clear, location: 0.85),
            .init(color: .clear, location: 1),
          ]),
          startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
          endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
    }
    corners.fill(
      Path(bounds),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: .black.opacity(fold * 0.5), location: 0),
          .init(color: .clear, location: 0.19),
          .init(color: .clear, location: 0.81),
          .init(color: .black.opacity(fold * 0.5), location: 1),
        ]),
        startPoint: CGPoint(x: bounds.minX, y: bounds.midY),
        endPoint: CGPoint(x: bounds.maxX, y: bounds.midY)))
  }

  private func drawDesktop(in desktop: GraphicsContext) {
    let bounds = CGRect(x: 7, y: 6, width: 312, height: 187)
    desktop.fill(Path(bounds), with: .color(Color(red: 0.9, green: 0.91, blue: 0.87)))
    desktop.fill(
      Path(ellipseIn: CGRect(x: 77, y: -36, width: 250, height: 250)),
      with: .color(active ? accent : Color(white: 0.79)))
    var ribbon = Path()
    ribbon.move(to: CGPoint(x: 100, y: 222))
    ribbon.addCurve(
      to: CGPoint(x: 258, y: -47), control1: CGPoint(x: 325, y: 202),
      control2: CGPoint(x: 53, y: 10))
    desktop.stroke(ribbon, with: .color(graphite), style: StrokeStyle(lineWidth: 47, lineCap: .round))
    desktop.stroke(
      ribbon, with: .color(.white.opacity(0.08)),
      style: StrokeStyle(lineWidth: 1, lineCap: .round))
    desktop.fill(Path(CGRect(x: 7, y: 6, width: 312, height: 11)), with: .color(.white.opacity(0.32)))
    for index in 0..<3 {
      desktop.fill(
        Path(roundedRect: CGRect(x: 16 + index * 14, y: 10, width: 9, height: 2), cornerRadius: 1),
        with: .color(graphite.opacity(0.55)))
    }
    let window = CGRect(x: 24, y: 68, width: 109, height: 74)
    let windowPath = Path(roundedRect: window, cornerRadius: 7)
    var shadow = desktop
    shadow.addFilter(.shadow(color: .black.opacity(0.1), radius: 7, x: 0, y: 5))
    shadow.fill(windowPath, with: .color(.white.opacity(0.92)))
    for index in 0..<3 {
      desktop.fill(
        Path(ellipseIn: CGRect(x: 31 + index * 6, y: 75, width: 3, height: 3)),
        with: .color(Color(white: 0.63)))
    }
    desktop.draw(
      Text(verbatim: "Make room.").font(.system(size: 11, weight: .semibold)).foregroundStyle(graphite),
      at: CGPoint(x: 34, y: 93), anchor: .leading)
    for index in 0..<3 {
      desktop.fill(
        Path(roundedRect: CGRect(x: 34, y: 108 + index * 7, width: index == 2 ? 42 : 77, height: 2), cornerRadius: 1),
        with: .color(Color(white: 0.76)))
    }
    desktop.fill(
      Path(roundedRect: CGRect(x: 113, y: 175, width: 100, height: 13), cornerRadius: 5),
      with: .color(.white.opacity(0.58)))
    for index in 0..<8 {
      desktop.fill(
        Path(roundedRect: CGRect(x: 119 + index * 11, y: 178, width: 8, height: 8), cornerRadius: 2),
        with: .color(index == 3 && active ? accent : graphite.opacity(index % 2 == 0 ? 0.83 : 0.42)))
    }
  }
}
