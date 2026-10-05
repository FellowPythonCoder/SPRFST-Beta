// =====================================================================
//  The small pieces the window is built from: tabs, buttons and the
//  draggable dividers between regions.
//
//  Everything here draws itself. AppKit's own controls bring the blue
//  system highlight and the grey bezels with them, which is not what
//  this application looks like.
// =====================================================================
import AppKit

/// One flat tab. The editor tabs, the Run/Terminal strip and the
/// inspector switcher are all this control.
final class TabButton: NSButton {
    var text: String = "" {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var isActive = false { didSet { needsDisplay = true } }
    var closable = false
    var onClose: (() -> Void)?
    private var hovering = false

    init(_ text: String, closable: Bool = false, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.text = text
        self.closable = closable
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var face: NSFont { Fonts.ui(12, weight: isActive ? .semibold : .regular) }

    override var intrinsicContentSize: NSSize {
        let width = (text as NSString).size(withAttributes: [.font: face]).width
        return NSSize(width: ceil(width) + (closable ? 46 : 32), height: Theme.stripHeight)
    }

    private var closeRect: NSRect {
        NSRect(x: bounds.maxX - 25, y: (bounds.height - 16) / 2, width: 16, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        (isActive ? Theme.raised : (hovering ? Theme.panelHi : Theme.panel)).setFill()
        bounds.fill()

        if isActive {
            Theme.amber.setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
        }

        let string = NSAttributedString(string: text, attributes: [
            .font: face,
            .foregroundColor: isActive ? Theme.text : Theme.muted
        ])
        let size = string.size()
        string.draw(at: NSPoint(x: 16, y: (bounds.height - size.height) / 2))

        if closable && (hovering || isActive) {
            let r = closeRect.insetBy(dx: 4.5, dy: 4.5)
            let cross = NSBezierPath()
            cross.move(to: NSPoint(x: r.minX, y: r.minY)); cross.line(to: NSPoint(x: r.maxX, y: r.maxY))
            cross.move(to: NSPoint(x: r.minX, y: r.maxY)); cross.line(to: NSPoint(x: r.maxX, y: r.minY))
            cross.lineWidth = 1.4
            cross.lineCapStyle = .round
            (hovering ? Theme.text : Theme.faint).setStroke()
            cross.stroke()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovering = false; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        if closable, closeRect.contains(convert(event.locationInWindow, from: nil)) {
            onClose?()
            return
        }
        super.mouseDown(with: event)
    }
}

/// A rounded button for the top bar and the welcome screen.
final class BarButton: NSButton {
    enum Kind { case primary, quiet }

    var text: String = "" {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }
    var kind: Kind = .quiet { didSet { needsDisplay = true } }
    private var hovering = false
    private let handler: () -> Void

    init(_ text: String, kind: Kind = .quiet, _ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.text = text
        self.kind = kind
        title = ""
        isBordered = false
        focusRingType = .none
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }

    private var face: NSFont { Fonts.ui(12, weight: kind == .primary ? .semibold : .regular) }

    override var intrinsicContentSize: NSSize {
        let width = (text as NSString).size(withAttributes: [.font: face]).width
        return NSSize(width: ceil(width) + 30, height: 28)
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill: NSColor
        switch kind {
        case .primary: fill = hovering ? Theme.amberLight : Theme.amber
        case .quiet:   fill = hovering ? Theme.panelHi : Theme.raised
        }
        fill.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7).fill()
        if kind == .quiet {
            Theme.edge.setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
            outline.lineWidth = 1
            outline.stroke()
        }
        let string = NSAttributedString(string: text, attributes: [
            .font: face,
            .foregroundColor: kind == .primary ? Theme.ink : Theme.text
        ])
        let size = string.size()
        string.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                y: (bounds.height - size.height) / 2))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovering = false; needsDisplay = true }
}

/// The line between two regions. Drag it to resize them.
///
/// It moves one layout constant, so the window can never end up in the
/// state a split view gets into when it is asked for a position before
/// it has a size.
final class DragDivider: NSView {
    enum Along { case width, height }

    private let along: Along
    private let constraint: NSLayoutConstraint
    private let sign: CGFloat
    private let low: CGFloat
    private let high: CGFloat
    private var startValue: CGFloat = 0
    private var startPoint: NSPoint = .zero

    init(_ along: Along, _ constraint: NSLayoutConstraint,
         sign: CGFloat = 1, from low: CGFloat, to high: CGFloat) {
        self.along = along
        self.constraint = constraint
        self.sign = sign
        self.low = low
        self.high = high
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let thickness = (along == .width ? widthAnchor : heightAnchor)
        thickness.constraint(equalToConstant: Theme.dividerThickness).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.ink.setFill()
        bounds.fill()
        Theme.edge.setFill()
        if along == .width {
            NSRect(x: (bounds.width - 1) / 2, y: 0, width: 1, height: bounds.height).fill()
        } else {
            NSRect(x: 0, y: (bounds.height - 1) / 2, width: bounds.width, height: 1).fill()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: along == .width ? .resizeLeftRight : .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        startValue = constraint.constant
        startPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let now = event.locationInWindow
        let delta = (along == .width ? now.x - startPoint.x : now.y - startPoint.y)
        let wanted = startValue + sign * delta
        constraint.constant = min(max(wanted, low), high)
    }
}

/// A strip of tabs with a right hand side for buttons.
final class TabStrip: NSView {
    let tabs = NSStackView()
    let accessories = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor

        tabs.orientation = .horizontal
        tabs.spacing = 0
        tabs.alignment = .centerY
        tabs.translatesAutoresizingMaskIntoConstraints = false

        accessories.orientation = .horizontal
        accessories.spacing = 6
        accessories.alignment = .centerY
        accessories.translatesAutoresizingMaskIntoConstraints = false

        addSubview(tabs)
        addSubview(accessories)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Theme.stripHeight),
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabs.topAnchor.constraint(equalTo: topAnchor),
            tabs.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabs.trailingAnchor.constraint(lessThanOrEqualTo: accessories.leadingAnchor, constant: -8),
            accessories.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            accessories.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.panel.setFill()
        bounds.fill()
        Theme.edge.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    func setTabs(_ buttons: [TabButton]) {
        for view in tabs.arrangedSubviews { tabs.removeArrangedSubview(view); view.removeFromSuperview() }
        for button in buttons { tabs.addArrangedSubview(button) }
    }
}
