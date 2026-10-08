// =====================================================================
//  The tour, in a window.
//
//  Left: the twenty six lessons and how many points each one earned.
//  Right: what to learn, what to do, somewhere to type it, and one
//  button that decides. The deciding happens in learn/tour.spf — this
//  file asks and draws.
// =====================================================================
import AppKit

// ------------------------------------------------------------ a lesson row
final class RowButton: NSButton {
    var card = Card()
    var picked = false { didSet { needsDisplay = true } }
    private var warm = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        title = ""
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { warm = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { warm = false; needsDisplay = true }

    override func draw(_ dirty: NSRect) {
        // Fill what is ours. Since macOS 14 the rectangle we are handed
        // can be larger than this view.
        let mine = bounds
        if picked {
            Theme.raised.setFill()
            NSBezierPath(roundedRect: mine.insetBy(dx: 4, dy: 1), xRadius: 6, yRadius: 6).fill()
        } else if warm {
            Theme.panelHi.withAlphaComponent(0.5).setFill()
            NSBezierPath(roundedRect: mine.insetBy(dx: 4, dy: 1), xRadius: 6, yRadius: 6).fill()
        }

        let tick = card.done ? "✓" : "·"
        let tickColour = card.done ? Theme.green : Theme.faint
        (tick as NSString).draw(at: CGPoint(x: 14, y: mine.midY - 8),
                                withAttributes: [.font: Fonts.ui(13, weight: .semibold),
                                                 .foregroundColor: tickColour])

        let number = "\(card.n)"
        (number as NSString).draw(at: CGPoint(x: 32, y: mine.midY - 7),
                                  withAttributes: [.font: Fonts.mono(11),
                                                   .foregroundColor: Theme.faint])

        let words = card.title as NSString
        let colour = picked ? Theme.amber : (card.done ? Theme.text : Theme.muted)
        words.draw(at: CGPoint(x: 58, y: mine.midY - 8),
                   withAttributes: [.font: Fonts.ui(12.5, weight: picked ? .semibold : .regular),
                                    .foregroundColor: colour])

        if card.done && card.worth > 0 {
            let points = "\(card.worth)" as NSString
            let face = Fonts.mono(10)
            let size = points.size(withAttributes: [.font: face])
            points.draw(at: CGPoint(x: mine.maxX - size.width - 14, y: mine.midY - 6),
                        withAttributes: [.font: face, .foregroundColor: Theme.green])
        }
    }
}

// ------------------------------------------------------------- the meter
final class PointsBar: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func draw(_ dirty: NSRect) {
        let track = bounds.insetBy(dx: 0, dy: bounds.height / 2 - 3)
        Theme.raised.setFill()
        NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        guard fraction > 0 else { return }
        var filled = track
        filled.size.width = max(6, track.width * CGFloat(min(1, fraction)))
        Theme.amber.setFill()
        NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
    }
}

// ================================================================ window
final class TourWindow: NSWindowController, NSTextViewDelegate {
    private var cards: [Card] = []
    private var rows: [RowButton] = []
    private var lesson = Lesson()
    private var at = 1
    private var editingSide = false
    private var mainCode = ""
    private var sideCode = ""
    private var saveSoon: DispatchWorkItem?

    private let sidebarStack = NSStackView()
    private let lessonText = StudioTextView(editable: false)
    private let editor = StudioTextView(editable: true)
    private let outputText = StudioTextView(editable: false)
    private var stageLabel = label("", Fonts.ui(11, weight: .medium), Theme.faint)
    private var titleLabel = label("", Fonts.hand(26), Theme.text)
    private var pointsLabel = label("0", Fonts.mono(14), Theme.amber)
    private var rankLabel = label("Newcomer", Fonts.ui(11, weight: .medium), Theme.muted)
    private var verdictLabel = label("", Fonts.ui(12, weight: .medium), Theme.muted)
    private var fileLabel = label("", Fonts.mono(10), Theme.faint)
    private let meter = PointsBar(frame: .zero)
    private var checkButton: BarButton!
    private var runButton: BarButton!
    private var hintButton: BarButton!
    private var answerButton: BarButton!
    private var mainTab: BarButton!
    private var sideTab: BarButton!
    private var tabRow = NSView()

    convenience init() {
        let frame = NSRect(x: 0, y: 0, width: 1180, height: 820)
        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "SPRFST Tour"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.ink
        window.minSize = NSSize(width: 980, height: 680)
        self.init(window: window)
        build()
        window.center()
        reload(open: nil)
    }

    // ------------------------------------------------------------- layout
    private func build() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = Theme.ink.cgColor

        // ---- top bar
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.backgroundColor = Theme.panel.cgColor

        let logo = LogoView(frame: .zero)
        logo.translatesAutoresizingMaskIntoConstraints = false

        let wordmark = label("SPRFST Tour", Fonts.hand(20), Theme.text)
        let subtitle = label("learn it by writing it", Fonts.ui(11), Theme.faint)
        for one in [wordmark, subtitle, pointsLabel, rankLabel] {
            one.translatesAutoresizingMaskIntoConstraints = false
        }
        let pointsWord = label("points", Fonts.ui(10, weight: .medium), Theme.faint)
        pointsWord.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(logo)
        bar.addSubview(wordmark)
        bar.addSubview(subtitle)
        bar.addSubview(meter)
        bar.addSubview(rankLabel)
        bar.addSubview(pointsLabel)
        bar.addSubview(pointsWord)
        root.addSubview(bar)

        let barLine = Hairline(horizontal: true)
        root.addSubview(barLine)

        // ---- the lessons, down the left
        let sidebar = NSScrollView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.drawsBackground = false
        sidebar.hasVerticalScroller = true
        sidebar.autohidesScrollers = true
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 1
        sidebarStack.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(sidebarStack)
        sidebar.documentView = holder
        root.addSubview(sidebar)

        let sideLine = Hairline(horizontal: false)
        root.addSubview(sideLine)

        // ---- the lesson
        for one in [stageLabel, titleLabel, verdictLabel, fileLabel] {
            one.translatesAutoresizingMaskIntoConstraints = false
        }
        root.addSubview(stageLabel)
        root.addSubview(titleLabel)

        let reading = NSScrollView()
        reading.translatesAutoresizingMaskIntoConstraints = false
        reading.drawsBackground = false
        mountTextView(lessonText, in: reading, editable: false)
        lessonText.drawsBackground = false
        lessonText.textContainerInset = NSSize(width: 0, height: 6)
        root.addSubview(reading)

        // ---- which file am I typing in
        tabRow.translatesAutoresizingMaskIntoConstraints = false
        mainTab = BarButton("main.spf", kind: .primary) { [weak self] in self?.showBuffer(side: false) }
        sideTab = BarButton("second file", kind: .quiet) { [weak self] in self?.showBuffer(side: true) }
        tabRow.addSubview(mainTab)
        tabRow.addSubview(sideTab)
        root.addSubview(tabRow)

        // ---- where you type
        let writing = NSScrollView()
        writing.translatesAutoresizingMaskIntoConstraints = false
        writing.drawsBackground = true
        writing.backgroundColor = Theme.panel
        mountTextView(editor, in: writing, editable: true)
        editor.backgroundColor = Theme.panel
        editor.font = Fonts.mono(13)
        editor.textColor = Theme.text
        editor.insertionPointColor = Theme.amber
        editor.textContainerInset = NSSize(width: 10, height: 10)
        editor.delegate = self
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        writing.wantsLayer = true
        writing.layer?.cornerRadius = Theme.corner
        root.addSubview(writing)

        // ---- the buttons
        checkButton = BarButton("Check my answer", kind: .primary) { [weak self] in self?.check() }
        runButton = BarButton("Run", kind: .quiet) { [weak self] in self?.runIt() }
        hintButton = BarButton("Hint", kind: .quiet) { [weak self] in self?.askHint() }
        answerButton = BarButton("Show me", kind: .quiet) { [weak self] in self?.showAnswer() }
        let buttons = NSView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        for one in [checkButton, runButton, hintButton, answerButton] { buttons.addSubview(one!) }
        buttons.addSubview(verdictLabel)
        root.addSubview(buttons)

        // ---- what happened
        let showing = NSScrollView()
        showing.translatesAutoresizingMaskIntoConstraints = false
        showing.drawsBackground = true
        showing.backgroundColor = Theme.panel
        mountTextView(outputText, in: showing, editable: false)
        outputText.backgroundColor = Theme.panel
        outputText.font = Fonts.mono(12)
        outputText.textColor = Theme.muted
        outputText.textContainerInset = NSSize(width: 10, height: 8)
        showing.wantsLayer = true
        showing.layer?.cornerRadius = Theme.corner
        root.addSubview(showing)
        root.addSubview(fileLabel)

        let sidebarWidth: CGFloat = 250
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: root.topAnchor),
            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 58),
            barLine.topAnchor.constraint(equalTo: bar.bottomAnchor),
            barLine.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            barLine.trailingAnchor.constraint(equalTo: root.trailingAnchor),

            logo.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 18),
            logo.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 26),
            logo.heightAnchor.constraint(equalToConstant: 26),
            wordmark.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 12),
            wordmark.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: wordmark.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: wordmark.bottomAnchor, constant: -2),

            pointsLabel.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            pointsLabel.topAnchor.constraint(equalTo: bar.topAnchor, constant: 10),
            pointsWord.trailingAnchor.constraint(equalTo: pointsLabel.trailingAnchor),
            pointsWord.topAnchor.constraint(equalTo: pointsLabel.bottomAnchor, constant: 0),
            rankLabel.trailingAnchor.constraint(equalTo: pointsLabel.leadingAnchor, constant: -14),
            rankLabel.centerYAnchor.constraint(equalTo: pointsLabel.centerYAnchor),
            meter.trailingAnchor.constraint(equalTo: rankLabel.leadingAnchor, constant: -14),
            meter.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            meter.widthAnchor.constraint(equalToConstant: 160),
            meter.heightAnchor.constraint(equalToConstant: 14),

            sidebar.topAnchor.constraint(equalTo: barLine.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: sidebarWidth),
            holder.widthAnchor.constraint(equalTo: sidebar.widthAnchor),
            sidebarStack.topAnchor.constraint(equalTo: holder.topAnchor),
            sidebarStack.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            sidebarStack.bottomAnchor.constraint(equalTo: holder.bottomAnchor),

            sideLine.topAnchor.constraint(equalTo: barLine.bottomAnchor),
            sideLine.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sideLine.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),

            stageLabel.topAnchor.constraint(equalTo: barLine.bottomAnchor, constant: 18),
            stageLabel.leadingAnchor.constraint(equalTo: sideLine.trailingAnchor, constant: 28),
            titleLabel.topAnchor.constraint(equalTo: stageLabel.bottomAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),

            reading.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            reading.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            reading.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            reading.bottomAnchor.constraint(equalTo: tabRow.topAnchor, constant: -14),

            tabRow.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            tabRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            tabRow.heightAnchor.constraint(equalToConstant: 26),
            tabRow.bottomAnchor.constraint(equalTo: writing.topAnchor, constant: -8),
            mainTab.leadingAnchor.constraint(equalTo: tabRow.leadingAnchor),
            mainTab.centerYAnchor.constraint(equalTo: tabRow.centerYAnchor),
            sideTab.leadingAnchor.constraint(equalTo: mainTab.trailingAnchor, constant: 8),
            sideTab.centerYAnchor.constraint(equalTo: tabRow.centerYAnchor),

            writing.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            writing.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            writing.heightAnchor.constraint(equalToConstant: 250),
            writing.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),

            buttons.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            buttons.heightAnchor.constraint(equalToConstant: 32),
            buttons.bottomAnchor.constraint(equalTo: showing.topAnchor, constant: -12),
            checkButton.leadingAnchor.constraint(equalTo: buttons.leadingAnchor),
            checkButton.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            runButton.leadingAnchor.constraint(equalTo: checkButton.trailingAnchor, constant: 8),
            runButton.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            hintButton.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: 8),
            hintButton.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            answerButton.leadingAnchor.constraint(equalTo: hintButton.trailingAnchor, constant: 8),
            answerButton.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            verdictLabel.leadingAnchor.constraint(greaterThanOrEqualTo: answerButton.trailingAnchor, constant: 16),
            verdictLabel.trailingAnchor.constraint(equalTo: buttons.trailingAnchor),
            verdictLabel.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),

            showing.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            showing.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            showing.heightAnchor.constraint(equalToConstant: 132),
            showing.bottomAnchor.constraint(equalTo: fileLabel.topAnchor, constant: -6),

            fileLabel.leadingAnchor.constraint(equalTo: stageLabel.leadingAnchor),
            fileLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            fileLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10)
        ])
    }

    // ------------------------------------------------------------ filling
    private func reload(open wanted: Int?) {
        Tour.shared.list { [weak self] cards, standing in
            guard let self = self else { return }
            self.cards = cards
            self.rebuildSidebar()
            self.show(standing)
            // start at the first unfinished lesson
            var start = wanted ?? cards.first(where: { !$0.done })?.n ?? 1
            if start < 1 { start = 1 }
            self.go(to: start)
        }
    }

    private func rebuildSidebar() {
        for view in sidebarStack.arrangedSubviews { view.removeFromSuperview() }
        rows = []
        var stage = ""
        for card in cards {
            if card.stage != stage {
                stage = card.stage
                let heading = label(stage.uppercased(), Fonts.ui(9.5, weight: .semibold), Theme.faint)
                heading.translatesAutoresizingMaskIntoConstraints = false
                let pad = NSView()
                pad.translatesAutoresizingMaskIntoConstraints = false
                pad.addSubview(heading)
                NSLayoutConstraint.activate([
                    pad.heightAnchor.constraint(equalToConstant: 28),
                    heading.leadingAnchor.constraint(equalTo: pad.leadingAnchor, constant: 16),
                    heading.bottomAnchor.constraint(equalTo: pad.bottomAnchor, constant: -6)
                ])
                sidebarStack.addArrangedSubview(pad)
                pad.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor).isActive = true
            }
            let row = RowButton(frame: .zero)
            row.card = card
            row.target = self
            row.action = #selector(rowPicked(_:))
            row.tag = card.n
            sidebarStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor).isActive = true
            rows.append(row)
        }
        markRow()
    }

    private func markRow() {
        for row in rows { row.picked = (row.card.n == at) }
    }

    private func show(_ standing: Standing) {
        pointsLabel.stringValue = "\(standing.points)"
        rankLabel.stringValue = "\(standing.rank)  ·  \(standing.finished)/\(standing.lessons)"
        meter.fraction = standing.fraction
    }

    private func go(to n: Int) {
        at = n
        markRow()
        Tour.shared.open(n) { [weak self] lesson, standing in
            guard let self = self else { return }
            self.lesson = lesson
            self.mainCode = lesson.code
            self.sideCode = lesson.sideCode
            self.editingSide = false
            self.stageLabel.stringValue =
                "LESSON \(lesson.n) OF \(Tour.shared.count)   ·   \(lesson.stage.uppercased())"
            self.titleLabel.stringValue = lesson.title
            self.lessonText.textStorage?.setAttributedString(self.teaching(lesson))
            self.lessonText.scroll(.zero)
            self.editor.string = self.mainCode
            self.fileLabel.stringValue = lesson.file
            self.hintButton.text = lesson.hinted ? "Hint (seen)" : "Hint"
            self.answerButton.text = lesson.shown ? "Answer (seen)" : "Show me"
            self.sideTab.isHidden = lesson.side.isEmpty
            self.sideTab.text = lesson.side.isEmpty ? "second file" : lesson.side
            self.mainTab.isHidden = lesson.side.isEmpty
            self.showBuffer(side: false)
            self.outputText.textColor = Theme.faint
            self.outputText.string = """
            Type your answer in the box above, then press Check my answer (⌘ return).
            Run (⌘R) shows what your file prints without marking it.
            Stuck? Hint is worth 60 instead of 100; Show me is worth 30.
            """
            if lesson.done {
                self.verdict("already finished — you can do it again", Theme.green)
            } else {
                self.verdict("", Theme.muted)
            }
            self.show(standing)
            self.window?.makeFirstResponder(self.editor)
        }
    }

    // The lesson, set as one piece of text: paragraphs, a worked
    // example in the code face, and the task in amber.
    private func teaching(_ lesson: Lesson) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body = NSMutableParagraphStyle()
        body.lineHeightMultiple = 1.3
        body.paragraphSpacing = 10

        func add(_ text: String, _ font: NSFont, _ colour: NSColor, _ style: NSParagraphStyle) {
            out.append(NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: colour, .paragraphStyle: style
            ]))
        }

        for part in lesson.teach { add(part + "\n", Fonts.ui(13.5), Theme.text, body) }

        if !lesson.example.isEmpty {
            let tight = NSMutableParagraphStyle()
            tight.lineHeightMultiple = 1.2
            tight.firstLineHeadIndent = 14
            tight.headIndent = 14
            add("\nFOR INSTANCE\n", Fonts.ui(9.5, weight: .semibold), Theme.faint, body)
            for line in lesson.example {
                add(line + "\n", Fonts.mono(12), Theme.muted, tight)
            }
        }

        add("\nYOUR TURN\n", Fonts.ui(9.5, weight: .semibold), Theme.amberDeep, body)
        for part in lesson.brief { add(part + "\n", Fonts.ui(13.5, weight: .medium), Theme.amberLight, body) }
        return out
    }

    private func verdict(_ words: String, _ colour: NSColor) {
        verdictLabel.stringValue = words
        verdictLabel.textColor = colour
    }

    private func showBuffer(side: Bool) {
        if editingSide { sideCode = editor.string } else { mainCode = editor.string }
        editingSide = side && !lesson.side.isEmpty
        editor.string = editingSide ? sideCode : mainCode
        mainTab.kind = editingSide ? .quiet : .primary
        sideTab.kind = editingSide ? .primary : .quiet
        fileLabel.stringValue = editingSide ? lesson.sideFile : lesson.file
    }

    private func current() -> (code: String, side: String) {
        if editingSide { sideCode = editor.string } else { mainCode = editor.string }
        return (mainCode, lesson.side.isEmpty ? "" : sideCode)
    }

    // ------------------------------------------------------------ actions
    @objc private func rowPicked(_ sender: NSButton) {
        go(to: sender.tag)
    }

    func textDidChange(_ notification: Notification) {
        saveSoon?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let now = self.current()
            Tour.shared.save(self.at, code: now.code, side: now.side)
        }
        saveSoon = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    @objc func check() {
        let now = current()
        verdict("checking…", Theme.muted)
        Tour.shared.check(at, code: now.code, side: now.side) { [weak self] verdict, standing in
            guard let self = self else { return }
            self.show(standing)
            if verdict.passed {
                if verdict.firstTime && verdict.awarded > 0 {
                    self.verdict("that is it  ·  +\(verdict.awarded) points", Theme.green)
                } else {
                    self.verdict("that is it", Theme.green)
                }
                self.outputText.textColor = Theme.green
                self.outputText.string = verdict.output.joined(separator: "\n")
                Tour.shared.list { cards, standing in
                    self.cards = cards
                    self.rebuildSidebar()
                    self.show(standing)
                }
                if self.at < Tour.shared.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        self.go(to: self.at + 1)
                    }
                }
            } else if verdict.broken {
                self.verdict("it did not compile", Theme.red)
                self.outputText.textColor = Theme.red
                self.outputText.string = verdict.output.joined(separator: "\n")
            } else {
                self.verdict("not yet — line \(verdict.differs) is the first difference", Theme.red)
                self.outputText.textColor = Theme.muted
                var report: [String] = []
                report.append("you printed")
                report.append(verdict.output.isEmpty ? "   (nothing)"
                                                     : verdict.output.map { "   " + $0 }.joined(separator: "\n"))
                report.append("")
                report.append("the lesson wants")
                report.append(verdict.expected.map { "   " + $0 }.joined(separator: "\n"))
                self.outputText.string = report.joined(separator: "\n")
            }
        }
    }

    @objc func runIt() {
        let now = current()
        verdict("running…", Theme.muted)
        Tour.shared.run(at, code: now.code, side: now.side) { [weak self] lines in
            guard let self = self else { return }
            self.outputText.textColor = Theme.muted
            self.outputText.string = lines.isEmpty ? "(your file printed nothing)"
                                                   : lines.joined(separator: "\n")
            self.verdict("", Theme.muted)
        }
    }

    @objc func askHint() {
        Tour.shared.hint(at) { [weak self] hint, standing in
            guard let self = self else { return }
            self.show(standing)
            self.hintButton.text = "Hint (seen)"
            self.outputText.textColor = Theme.amberLight
            self.outputText.string = "hint\n   " + hint +
                "\n\n   (finishing after a hint is worth 60 instead of 100)"
        }
    }

    @objc func showAnswer() {
        let alert = NSAlert()
        alert.messageText = "Show one way to do it?"
        alert.informativeText = "The answer goes into the editor. Finishing after that is worth 30 points instead of 100."
        alert.addButton(withTitle: "Show me")
        alert.addButton(withTitle: "Not yet")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Tour.shared.answer(at) { [weak self] lines, standing in
            guard let self = self else { return }
            self.show(standing)
            self.answerButton.text = "Answer (seen)"
            if self.editingSide { self.showBuffer(side: false) }
            self.mainCode = lines.joined(separator: "\n") + "\n"
            self.editor.string = self.mainCode
            Tour.shared.save(self.at, code: self.mainCode, side: self.sideCode)
            self.outputText.textColor = Theme.muted
            self.outputText.string = "the answer is in the editor — press Check my answer to run it"
        }
    }

    @objc func goNext() { if at < Tour.shared.count { go(to: at + 1) } }
    @objc func goBack() { if at > 1 { go(to: at - 1) } }

    @objc func startOver() {
        let alert = NSAlert()
        alert.messageText = "Forget all progress?"
        alert.informativeText = "Every tick and every point goes back to nothing. The files you have written stay where they are."
        alert.addButton(withTitle: "Forget it")
        alert.addButton(withTitle: "Keep it")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Tour.shared.forget { [weak self] _ in self?.reload(open: 1) }
    }

    @objc func openFolder() {
        guard !Tour.shared.home.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: Tour.shared.home))
    }
}
