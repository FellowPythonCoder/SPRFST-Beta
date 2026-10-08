// =====================================================================
//  The SPRFST mark, drawn with Core Graphics so it stays sharp at any
//  size. Same geometry as assets/logo/mark.svg.
// =====================================================================
import AppKit

final class LogoView: NSView {
    var showTrails = true
    var showPlate = true

    override var isFlipped: Bool { true }

    /// The bolt outline in a 512 x 512 design space.
    static let boltPoints: [CGPoint] = [
        CGPoint(x: 300, y: 64),  CGPoint(x: 186, y: 272), CGPoint(x: 266, y: 272),
        CGPoint(x: 212, y: 448), CGPoint(x: 430, y: 214), CGPoint(x: 336, y: 214),
        CGPoint(x: 404, y: 64)
    ]

    static func boltPath(in rect: CGRect) -> NSBezierPath {
        let s = min(rect.width, rect.height) / 512.0
        let path = NSBezierPath()
        for (i, p) in boltPoints.enumerated() {
            let q = CGPoint(x: rect.minX + p.x * s, y: rect.minY + p.y * s)
            if i == 0 { path.move(to: q) } else { path.line(to: q) }
        }
        path.close()
        return path
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let side = min(bounds.width, bounds.height)
        let rect = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2,
                          width: side, height: side)
        let s = side / 512.0

        if showPlate {
            let plate = NSBezierPath(roundedRect: rect, xRadius: 112 * s, yRadius: 112 * s)
            Theme.ink.setFill()
            plate.fill()
            Theme.edge.setStroke()
            plate.lineWidth = max(1, 2 * s)
            plate.stroke()
        }

        if showTrails && side > 48 {
            let trails: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (96, 196, 208, 196), (72, 256, 168, 256), (104, 316, 196, 316)
            ]
            for (i, t) in trails.enumerated() {
                let p = NSBezierPath()
                p.move(to: CGPoint(x: rect.minX + t.0 * s, y: rect.minY + t.1 * s))
                p.line(to: CGPoint(x: rect.minX + t.2 * s, y: rect.minY + t.3 * s))
                p.lineWidth = 14 * s
                p.lineCapStyle = .round
                Theme.amberDeep.withAlphaComponent(0.42 - CGFloat(i) * 0.11).setStroke()
                p.stroke()
            }
        }

        let bolt = LogoView.boltPath(in: rect)
        ctx.saveGState()
        bolt.addClip()
        let gradient = NSGradient(colors: [Theme.amberLight, Theme.amber, Theme.amberDeep],
                                  atLocations: [0, 0.45, 1],
                                  colorSpace: .sRGB)
        gradient?.draw(in: rect, angle: -45)
        ctx.restoreGState()
    }

    /// A rendered bitmap, used for the dock icon and the About panel.
    static func image(size: CGFloat, plate: Bool = true, trails: Bool = true) -> NSImage {
        let view = LogoView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.showPlate = plate
        view.showTrails = trails
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        view.draw(view.bounds)
        image.unlockFocus()
        return image
    }
}

/// Wordmark: the bolt beside the handwriting-style name.
final class WordmarkView: NSView {
    var subtitle: String? = "fast by design"
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let h = bounds.height
        let boltSide = h * 0.72
        let rect = CGRect(x: 0, y: (h - boltSide) / 2, width: boltSide, height: boltSide)

        let bolt = LogoView.boltPath(in: rect)
        NSGraphicsContext.current?.cgContext.saveGState()
        bolt.addClip()
        NSGradient(colors: [Theme.amberLight, Theme.amberDeep], atLocations: [0, 1], colorSpace: .sRGB)?
            .draw(in: rect, angle: -45)
        NSGraphicsContext.current?.cgContext.restoreGState()

        let name = NSAttributedString(string: "SPRFST", attributes: [
            .font: Fonts.hand(h * 0.52),
            .foregroundColor: Theme.text,
            .kern: h * 0.03
        ])
        name.draw(at: CGPoint(x: boltSide + h * 0.16, y: h * 0.12))

        if let subtitle {
            let sub = NSAttributedString(string: subtitle, attributes: [
                .font: Fonts.ui(h * 0.18),
                .foregroundColor: Theme.muted,
                .kern: h * 0.04
            ])
            sub.draw(at: CGPoint(x: boltSide + h * 0.2, y: h * 0.68))
        }
    }
}
