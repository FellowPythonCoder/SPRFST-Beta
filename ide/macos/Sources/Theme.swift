// =====================================================================
//  SPRFST Studio — visual identity
//  Deep black, near-black panels, warm amber, soft white text.
// =====================================================================
import AppKit

enum Theme {
    // surfaces
    static let ink        = NSColor(srgbRed: 0.043, green: 0.043, blue: 0.051, alpha: 1)  // #0B0B0D
    static let panel      = NSColor(srgbRed: 0.071, green: 0.071, blue: 0.078, alpha: 1)  // #121214
    static let raised     = NSColor(srgbRed: 0.106, green: 0.106, blue: 0.118, alpha: 1)
    static let panelHi    = NSColor(srgbRed: 0.137, green: 0.137, blue: 0.149, alpha: 1)
    static let edge       = NSColor(srgbRed: 0.145, green: 0.145, blue: 0.157, alpha: 1)  // #252528

    // ink on top
    static let text       = NSColor(srgbRed: 0.957, green: 0.957, blue: 0.949, alpha: 1)  // #F4F4F2
    static let muted      = NSColor(srgbRed: 0.624, green: 0.624, blue: 0.643, alpha: 1)  // #9F9FA4
    static let faint      = NSColor(srgbRed: 0.427, green: 0.427, blue: 0.447, alpha: 1)

    // accents
    static let amber      = NSColor(srgbRed: 1.000, green: 0.631, blue: 0.212, alpha: 1)  // #FFA136
    static let amberDeep  = NSColor(srgbRed: 0.910, green: 0.463, blue: 0.102, alpha: 1)  // #E8761A
    static let amberLight = NSColor(srgbRed: 1.000, green: 0.769, blue: 0.420, alpha: 1)  // #FFC46B
    static let green      = NSColor(srgbRed: 0.459, green: 0.788, blue: 0.561, alpha: 1)
    static let red        = NSColor(srgbRed: 0.918, green: 0.455, blue: 0.431, alpha: 1)
    static let blue       = NSColor(srgbRed: 0.459, green: 0.698, blue: 0.918, alpha: 1)
    static let violet     = NSColor(srgbRed: 0.722, green: 0.580, blue: 0.918, alpha: 1)

    // syntax
    static let synKeyword = amber
    static let synText    = NSColor(srgbRed: 0.839, green: 0.761, blue: 0.541, alpha: 1)
    static let synNumber  = NSColor(srgbRed: 0.839, green: 0.651, blue: 0.467, alpha: 1)
    static let synComment = NSColor(srgbRed: 0.361, green: 0.376, blue: 0.392, alpha: 1)
    static let synType    = NSColor(srgbRed: 0.671, green: 0.816, blue: 0.918, alpha: 1)
    static let synName    = text
    static let synPunct   = NSColor(srgbRed: 0.569, green: 0.569, blue: 0.588, alpha: 1)

    // metrics
    static let corner: CGFloat = 10
    static let gutterWidth: CGFloat = 48
    static let minimapWidth: CGFloat = 72
    static let topBarHeight: CGFloat = 46
    static let stripHeight: CGFloat = 32
    static let statusHeight: CGFloat = 26
    static let dividerThickness: CGFloat = 7
}

// ---------------------------------------------------------------- fonts
enum Fonts {
    /// The four choices offered in Settings.
    enum Face: String, CaseIterable {
        case hand    = "SPRFST Hand"
        case clean   = "Clean Code"
        case system  = "System"
        case mono    = "Monospace"
    }

    static var current: Face = {
        if let raw = UserDefaults.standard.string(forKey: "sprfst.font"),
           let face = Face(rawValue: raw) { return face }
        return .clean
    }() {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "sprfst.font") }
    }

    static var size: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "sprfst.fontSize")
        return stored > 6 ? CGFloat(stored) : 13
    }() {
        didSet { UserDefaults.standard.set(Double(size), forKey: "sprfst.fontSize") }
    }

    /// The editor font. "SPRFST Hand" really is handwriting — the setting
    /// would be a lie otherwise — everything else is monospaced.
    static func code() -> NSFont {
        switch current {
        case .hand:
            return hand(size + 2)
        case .clean:
            return NSFont(name: "JetBrains Mono", size: size)
                ?? NSFont(name: "SF Mono", size: size)
                ?? NSFont(name: "Menlo", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .system:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .mono:
            return NSFont(name: "Menlo", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }

    /// Line numbers and anything that has to line up with code.
    static func mono(_ points: CGFloat) -> NSFont {
        NSFont(name: "SF Mono", size: points)
            ?? NSFont(name: "Menlo", size: points)
            ?? NSFont.monospacedSystemFont(ofSize: points, weight: .regular)
    }

    /// The handwriting face. macOS always has at least one of these; the
    /// system font is only reached on a machine stripped of them.
    static func hand(_ points: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let heavy = weight.rawValue >= NSFont.Weight.semibold.rawValue
        let names = heavy
            ? ["Noteworthy-Bold", "BradleyHandITCTT-Bold", "ChalkboardSE-Bold",
               "MarkerFelt-Wide", "Noteworthy", "Bradley Hand", "Chalkboard SE"]
            : ["Noteworthy-Light", "Noteworthy", "Bradley Hand", "BradleyHandITCTT-Bold",
               "ChalkboardSE-Light", "Chalkboard SE", "MarkerFelt-Thin"]
        for name in names {
            if let f = NSFont(name: name, size: points) { return f }
        }
        return NSFont.systemFont(ofSize: points, weight: weight)
    }

    /// Every label in the chrome. Handwriting reads small, so it is set
    /// a point and a half larger than the system font would be.
    static func ui(_ points: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        hand(points + 1.5, weight: weight)
    }

    /// For the few places that must be exact: figures in the status bar.
    static func plain(_ points: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: points, weight: weight)
    }
}

// ------------------------------------------------------- small helpers
extension NSView {
    func fill(_ parent: NSView, inset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }

    func painted(_ colour: NSColor, radius: CGFloat = 0) -> Self {
        wantsLayer = true
        layer?.backgroundColor = colour.cgColor
        layer?.cornerRadius = radius
        return self
    }
}

func label(_ string: String, _ font: NSFont, _ colour: NSColor) -> NSTextField {
    let t = NSTextField(labelWithString: string)
    t.font = font
    t.textColor = colour
    t.backgroundColor = .clear
    t.isBezeled = false
    t.isEditable = false
    t.drawsBackground = false
    t.lineBreakMode = .byTruncatingTail
    t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return t
}

/// A one pixel rule, used between the regions of the window.
final class Hairline: NSView {
    private let horizontal: Bool
    init(horizontal: Bool) {
        self.horizontal = horizontal
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        (horizontal ? heightAnchor : widthAnchor).constraint(equalToConstant: 1).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        Theme.edge.setFill()
        bounds.fill()
    }
}
