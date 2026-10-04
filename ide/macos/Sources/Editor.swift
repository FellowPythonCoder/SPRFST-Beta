// =====================================================================
//  The code editor: syntax highlighting, line numbers, breakpoint
//  gutter, minimap, completion, hover and inline problem marks.
// =====================================================================
import AppKit

protocol EditorDelegate: AnyObject {
    func editorDidChange(_ editor: EditorView)
    func editorRequestsSave(_ editor: EditorView)
    func editor(_ editor: EditorView, toggledBreakpointAt line: Int)
    func editor(_ editor: EditorView, jumpTo file: String, line: Int)
}

// ------------------------------------------------------------ gutter
final class GutterView: NSRulerView {
    weak var editor: EditorView?
    var breakpoints: Set<Int> = []
    var problemLines: [Int: Bool] = [:]      // line -> isError
    var currentLine: Int?

    init(scrollView: NSScrollView, editor: EditorView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.editor = editor
        self.clientView = editor.textView
        self.ruleThickness = Theme.gutterWidth
    }
    // NSRulerView redeclares initWithCoder: as non-failable, so unlike
    // every NSView subclass here this override must not be failable.
    required init(coder: NSCoder) { fatalError("not loaded from a nib") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let text = editor?.textView,
              let layout = text.layoutManager,
              let container = text.textContainer else { return }

        Theme.ink.setFill()
        rect.fill()
        let line = NSBezierPath()
        line.move(to: CGPoint(x: ruleThickness - 0.5, y: rect.minY))
        line.line(to: CGPoint(x: ruleThickness - 0.5, y: rect.maxY))
        Theme.edge.setStroke()
        line.lineWidth = 1
        line.stroke()

        let content = text.string as NSString
        let visible = scrollView?.contentView.bounds ?? .zero
        let glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var lineNumber = 1
        content.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location),
                                    options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        var index = charRange.location
        let inset = text.textContainerInset.height
        while index < NSMaxRange(charRange) {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let glyph = layout.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var frag = layout.boundingRect(forGlyphRange: glyph, in: container)
            frag.origin.y += inset - visible.origin.y

            if currentLine == lineNumber {
                Theme.raised.setFill()
                NSRect(x: 0, y: frag.minY, width: ruleThickness, height: frag.height).fill()
            }

            if breakpoints.contains(lineNumber) {
                let d: CGFloat = 9
                let dot = NSBezierPath(ovalIn: NSRect(x: 8, y: frag.minY + (frag.height - d) / 2,
                                                      width: d, height: d))
                Theme.red.setFill()
                dot.fill()
            } else if let isError = problemLines[lineNumber] {
                let d: CGFloat = 7
                let dot = NSBezierPath(ovalIn: NSRect(x: 9, y: frag.minY + (frag.height - d) / 2,
                                                      width: d, height: d))
                (isError ? Theme.red : Theme.amber).setFill()
                dot.fill()
            }

            let active = currentLine == lineNumber
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Fonts.code(),
                .foregroundColor: active ? Theme.amber : Theme.faint
            ]
            let s = NSAttributedString(string: "\(lineNumber)", attributes: attrs)
            s.draw(at: CGPoint(x: ruleThickness - s.size().width - 10, y: frag.minY))

            lineNumber += 1
            index = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let text = editor?.textView, let layout = text.layoutManager,
              let container = text.textContainer else { return }
        let point = convert(event.locationInWindow, from: nil)
        let visible = scrollView?.contentView.bounds ?? .zero
        let inText = CGPoint(x: 4, y: point.y + visible.origin.y - text.textContainerInset.height)
        let glyph = layout.glyphIndex(for: inText, in: container)
        let charIndex = layout.characterIndexForGlyph(at: glyph)
        let content = text.string as NSString
        var line = 1
        content.enumerateSubstrings(in: NSRange(location: 0, length: charIndex),
                                    options: [.byLines, .substringNotRequired]) { _, _, _, _ in line += 1 }
        editor?.toggleBreakpoint(line: line)
    }
}

// ----------------------------------------------------------- minimap
final class MinimapView: NSView {
    weak var editor: EditorView?
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.panel.setFill()
        bounds.fill()
        guard let text = editor?.textView else { return }
        let lines = text.string.components(separatedBy: "\n")
        guard !lines.isEmpty else { return }

        let rowHeight = max(1.2, min(3.0, bounds.height / CGFloat(max(lines.count, 1))))
        let charWidth = (bounds.width - 10) / 90.0

        for (i, line) in lines.enumerated() {
            let y = CGFloat(i) * rowHeight
            if y > bounds.height { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let indent = CGFloat(line.prefix(while: { $0 == " " }).count)
            let width = min(CGFloat(trimmed.count) * charWidth, bounds.width - 10 - indent * charWidth)
            let colour: NSColor
            if trimmed.hasPrefix("~~") { colour = Theme.synComment.withAlphaComponent(0.5) }
            else if trimmed.hasPrefix("fn ") || trimmed.hasPrefix("pub fn ")
                 || trimmed.hasPrefix("object ") || trimmed.hasPrefix("data ")
                 || trimmed.hasPrefix("enum ") || trimmed.hasPrefix("trait ") { colour = Theme.amber }
            else { colour = Theme.muted.withAlphaComponent(0.55) }
            colour.setFill()
            NSRect(x: 5 + indent * charWidth, y: y, width: max(width, 1), height: max(rowHeight - 0.6, 0.8)).fill()
        }

        // the window on to the document
        if let scroll = editor?.scrollView {
            let total = max(scroll.documentView?.frame.height ?? 1, 1)
            let visible = scroll.contentView.bounds
            let top = visible.origin.y / total * bounds.height
            let height = visible.height / total * bounds.height
            Theme.amber.withAlphaComponent(0.12).setFill()
            NSRect(x: 0, y: top, width: bounds.width, height: height).fill()
        }
    }

    override func mouseDown(with event: NSEvent) { scrollTo(event) }
    override func mouseDragged(with event: NSEvent) { scrollTo(event) }

    private func scrollTo(_ event: NSEvent) {
        guard let scroll = editor?.scrollView, let doc = scroll.documentView else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fraction = max(0, min(1, point.y / bounds.height))
        let target = fraction * max(doc.frame.height - scroll.contentView.bounds.height, 0)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: target))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}

// --------------------------------------------------------- the editor
final class EditorView: NSView, NSTextViewDelegate {
    weak var delegate: EditorDelegate?

    let textView = NSTextView()
    let scrollView = NSScrollView()
    private let minimap = MinimapView()
    private var gutter: GutterView!
    private var completionWindow: CompletionWindow?
    private var hoverPopover: NSPopover?
    private var highlightTimer: Timer?

    var path: String = "" { didSet { reloadSyntax() } }
    var isDirty = false

    static let keywords: Set<String> = [
        "module","use","fn","task","test","bench","data","object","trait","enum","impl",
        "type","macro","extern","app","let","var","const","give","if","else","while","loop",
        "for","in","break","skip","defer","fail","try","catch","unsafe","match","when",
        "and","or","not","is","as","self","Self","nil","true","false","spawn","await",
        "pub","on","window","ref","own","weak","chan","mut","has"
    ]
    static let types: Set<String> = [
        "Int","Num","Text","Bool","Byte","Nil","Any","List","Map","Set","Result","Future",
        "Chan","Ok","Err","Range","Show","Eq","Ord","Hash"
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = Theme.ink.cgColor

        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.backgroundColor = Theme.ink
        textView.drawsBackground = true
        textView.insertionPointColor = Theme.amber
        textView.selectedTextAttributes = [.backgroundColor: Theme.amber.withAlphaComponent(0.22)]
        textView.textColor = Theme.text
        textView.font = Fonts.code()
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.ink
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        gutter = GutterView(scrollView: scrollView, editor: self)
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        minimap.editor = self
        minimap.translatesAutoresizingMaskIntoConstraints = false
        addSubview(minimap)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: minimap.leadingAnchor),
            minimap.trailingAnchor.constraint(equalTo: trailingAnchor),
            minimap.topAnchor.constraint(equalTo: topAnchor),
            minimap.bottomAnchor.constraint(equalTo: bottomAnchor),
            minimap.widthAnchor.constraint(equalToConstant: Theme.minimapWidth)
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    @objc private func scrolled() {
        minimap.needsDisplay = true
        gutter.needsDisplay = true
    }

    // ------------------------------------------------------- content
    var text: String {
        get { textView.string }
        set {
            textView.string = newValue
            reloadSyntax()
            minimap.needsDisplay = true
            gutter.needsDisplay = true
        }
    }

    func load(path: String) {
        self.path = path
        text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        isDirty = false
        textView.undoManager?.removeAllActions()
    }

    @discardableResult
    func save() -> Bool {
        guard !path.isEmpty else { return false }
        do {
            try textView.string.write(toFile: path, atomically: true, encoding: .utf8)
            isDirty = false
            return true
        } catch { return false }
    }

    // --------------------------------------------------- highlighting
    /// A fast local pass so typing never stutters; the compiler's own
    /// token stream refines it a moment later.
    func reloadSyntax() {
        guard let storage = textView.textStorage else { return }
        let source = textView.string as NSString
        let full = NSRange(location: 0, length: source.length)
        storage.beginEditing()
        storage.setAttributes([.font: Fonts.code(), .foregroundColor: Theme.synName], range: full)

        var i = 0
        while i < source.length {
            let c = source.character(at: i)
            let ch = Character(UnicodeScalar(c) ?? " ")

            if ch == "~" {                                   // comments
                let start = i
                if i + 1 < source.length && source.character(at: i + 1) == UInt16(91) { // ~[
                    i += 2
                    while i + 1 < source.length &&
                          !(source.character(at: i) == UInt16(93) && source.character(at: i + 1) == UInt16(126)) { i += 1 }
                    i = min(i + 2, source.length)
                } else {
                    while i < source.length && source.character(at: i) != 10 { i += 1 }
                }
                storage.addAttribute(.foregroundColor, value: Theme.synComment,
                                     range: NSRange(location: start, length: i - start))
                continue
            }
            if ch == "\"" {                                   // text literals
                let start = i
                i += 1
                while i < source.length {
                    let d = source.character(at: i)
                    if d == 92 { i += 2; continue }           // backslash
                    if d == 34 { i += 1; break }
                    if d == 10 { break }
                    i += 1
                }
                storage.addAttribute(.foregroundColor, value: Theme.synText,
                                     range: NSRange(location: start, length: min(i, source.length) - start))
                continue
            }
            if ch.isNumber {                                  // numbers
                let start = i
                while i < source.length,
                      let u = UnicodeScalar(source.character(at: i)),
                      Character(u).isNumber || Character(u) == "." || Character(u) == "_" ||
                      Character(u) == "x" || (Character(u).isHexDigit) { i += 1 }
                storage.addAttribute(.foregroundColor, value: Theme.synNumber,
                                     range: NSRange(location: start, length: i - start))
                continue
            }
            if ch.isLetter || ch == "_" {                     // words
                let start = i
                while i < source.length,
                      let u = UnicodeScalar(source.character(at: i)),
                      Character(u).isLetter || Character(u).isNumber || Character(u) == "_" { i += 1 }
                let word = source.substring(with: NSRange(location: start, length: i - start))
                if EditorView.keywords.contains(word) {
                    storage.addAttributes([.foregroundColor: Theme.synKeyword], range: NSRange(location: start, length: i - start))
                } else if EditorView.types.contains(word) || (word.first?.isUppercase ?? false) {
                    storage.addAttribute(.foregroundColor, value: Theme.synType, range: NSRange(location: start, length: i - start))
                }
                continue
            }
            if "(){}[],;:.+-*/%<>=!&|^?".contains(ch) {
                storage.addAttribute(.foregroundColor, value: Theme.synPunct, range: NSRange(location: i, length: 1))
            }
            i += 1
        }
        storage.endEditing()
    }

    func markProblems(_ diagnostics: [Diagnostic]) {
        guard let storage = textView.textStorage else { return }
        let source = textView.string as NSString
        storage.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: source.length))
        storage.removeAttribute(.underlineColor, range: NSRange(location: 0, length: source.length))
        gutter.problemLines.removeAll()

        for d in diagnostics {
            gutter.problemLines[d.line] = d.isError
            if let range = range(ofLine: d.line, column: d.col, through: d.endCol) {
                storage.addAttributes([
                    .underlineStyle: NSUnderlineStyle.thick.rawValue,
                    .underlineColor: d.isError ? Theme.red : Theme.amber
                ], range: range)
            }
        }
        gutter.needsDisplay = true
    }

    func range(ofLine line: Int, column: Int, through endColumn: Int?) -> NSRange? {
        let source = textView.string as NSString
        var current = 1
        var index = 0
        while current < line && index < source.length {
            let r = source.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(r)
            current += 1
        }
        guard current == line, index <= source.length else { return nil }
        let lineRange = source.lineRange(for: NSRange(location: min(index, source.length - 1 < 0 ? 0 : index), length: 0))
        let start = min(lineRange.location + max(column - 1, 0), NSMaxRange(lineRange))
        let end = endColumn.map { min(lineRange.location + max($0 - 1, 0), NSMaxRange(lineRange)) } ?? (start + 1)
        let length = max(end - start, 1)
        guard start + length <= source.length else { return nil }
        return NSRange(location: start, length: length)
    }

    // ------------------------------------------------------ navigation
    func go(toLine line: Int, column: Int = 1) {
        guard let range = range(ofLine: line, column: column, through: column + 1) else { return }
        textView.setSelectedRange(NSRange(location: range.location, length: 0))
        textView.scrollRangeToVisible(range)
        gutter.currentLine = line
        gutter.needsDisplay = true
        window?.makeFirstResponder(textView)
    }

    func toggleBreakpoint(line: Int) {
        if gutter.breakpoints.contains(line) { gutter.breakpoints.remove(line) }
        else { gutter.breakpoints.insert(line) }
        gutter.needsDisplay = true
        delegate?.editor(self, toggledBreakpointAt: line)
    }

    var breakpoints: [Int] { gutter.breakpoints.sorted() }

    func setExecutionLine(_ line: Int?) {
        gutter.currentLine = line
        gutter.needsDisplay = true
        if let line { go(toLine: line) }
    }

    var caretOffset: Int { textView.selectedRange().location }

    var caretLineColumn: (Int, Int) {
        let source = textView.string as NSString
        let loc = min(textView.selectedRange().location, source.length)
        var line = 1
        var lineStart = 0
        source.enumerateSubstrings(in: NSRange(location: 0, length: loc),
                                   options: [.byLines, .substringNotRequired]) { _, r, _, _ in
            line += 1
            lineStart = NSMaxRange(r)
        }
        return (line, loc - lineStart + 1)
    }

    // --------------------------------------------------- text delegate
    func textDidChange(_ notification: Notification) {
        isDirty = true
        reloadSyntax()
        minimap.needsDisplay = true
        gutter.needsDisplay = true
        delegate?.editorDidChange(self)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        let (line, _) = caretLineColumn
        gutter.currentLine = line
        gutter.needsDisplay = true
    }

    /// Keep the indentation of the previous line, and add one step after `{`.
    func textView(_ view: NSTextView, shouldChangeTextIn range: NSRange, replacementString string: String?) -> Bool {
        guard let string, string == "\n" else { return true }
        let source = view.string as NSString
        let lineRange = source.lineRange(for: NSRange(location: range.location, length: 0))
        let line = source.substring(with: lineRange)
        var indent = String(line.prefix(while: { $0 == " " }))
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("{") { indent += "    " }
        view.insertText("\n" + indent, replacementRange: range)
        return false
    }

    // -------------------------------------------------- completion UI
    func showCompletions(_ items: [Completion]) {
        guard !items.isEmpty, let window else { return }
        completionWindow?.close()
        let rect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
        let panel = CompletionWindow(items: items) { [weak self] chosen in
            self?.insertCompletion(chosen)
        }
        panel.show(at: rect, parent: window)
        completionWindow = panel
    }

    private func insertCompletion(_ item: Completion) {
        let source = textView.string as NSString
        var start = textView.selectedRange().location
        while start > 0 {
            let c = source.character(at: start - 1)
            guard let u = UnicodeScalar(c), Character(u).isLetter || Character(u).isNumber || Character(u) == "_" else { break }
            start -= 1
        }
        let replace = NSRange(location: start, length: textView.selectedRange().location - start)
        textView.insertText(item.label, replacementRange: replace)
        completionWindow?.close()
        completionWindow = nil
    }

    func showHover(_ info: HoverInfo) {
        let rect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
        guard let screen = window?.convertFromScreen(rect) else { return }
        let point = textView.convert(screen, from: nil)

        let body = NSStackView()
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 4
        body.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        let title = info.signature ?? info.type ?? info.kind ?? ""
        body.addArrangedSubview(label("\(info.name ?? "")  \(title)", Fonts.code(), Theme.amber))
        if let doc = info.doc, !doc.isEmpty {
            let d = label(doc, Fonts.ui(12), Theme.text)
            d.preferredMaxLayoutWidth = 360
            d.lineBreakMode = .byWordWrapping
            body.addArrangedSubview(d)
        }
        if let module = info.module, !module.isEmpty {
            body.addArrangedSubview(label("use std.\(module)", Fonts.code(), Theme.muted))
        }

        let controller = NSViewController()
        controller.view = body.painted(Theme.raised, radius: Theme.corner)

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.show(relativeTo: point, of: textView, preferredEdge: .maxY)
        hoverPopover = popover
    }
}

// ------------------------------------------------- completion window
final class CompletionWindow: NSWindow {
    private let table = NSTableView()
    private let items: [Completion]
    private let onChoose: (Completion) -> Void

    init(items: [Completion], onChoose: @escaping (Completion) -> Void) {
        self.items = Array(items.prefix(120))
        self.onChoose = onChoose
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu

        let container = NSView().painted(Theme.raised, radius: Theme.corner)
        container.layer?.borderColor = Theme.edge.cgColor
        container.layer?.borderWidth = 1
        contentView = container

        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.selectionHighlightStyle = .regular
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.width = 400
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(choose)
        table.action = #selector(choose)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.fill(container, inset: 6)
        if !self.items.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
    }

    override var canBecomeKey: Bool { true }

    func show(at rect: NSRect, parent: NSWindow) {
        var frame = NSRect(x: rect.minX, y: rect.minY - 248, width: 420, height: 240)
        if let screen = parent.screen, frame.minY < screen.visibleFrame.minY {
            frame.origin.y = rect.maxY + 8
        }
        setFrame(frame, display: true)
        parent.addChildWindow(self, ordered: .above)
        orderFront(nil)
    }

    @objc private func choose() {
        let row = table.selectedRow
        guard row >= 0 && row < items.count else { return }
        onChoose(items[row])
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: close()                       // escape
        case 36, 48: choose()                  // return, tab
        default: super.keyDown(with: event)
        }
    }
}

extension CompletionWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        let badge = label(String(item.kind.prefix(2)).uppercased(), Fonts.ui(9, weight: .bold), Theme.ink)
        badge.wantsLayer = true
        badge.layer?.backgroundColor = Theme.amber.cgColor
        badge.layer?.cornerRadius = 3
        badge.alignment = .center
        badge.widthAnchor.constraint(equalToConstant: 22).isActive = true

        stack.addArrangedSubview(badge)
        stack.addArrangedSubview(label(item.label, Fonts.code(), Theme.text))
        stack.addArrangedSubview(label(item.detail, Fonts.ui(11), Theme.muted))
        return stack
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let v = CompletionRow()
        return v
    }
}

final class CompletionRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        Theme.amber.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}
