// =====================================================================
//  The Guidebook: thirty chapters with runnable examples.
//  Chapters are Markdown files shipped in Resources/guidebook; code
//  fences marked ```sprfst get a Run button that really runs.
// =====================================================================
import AppKit

struct Chapter {
    let number: Int
    let title: String
    let path: String
}

final class GuidebookWindow: NSWindowController {
    private let list = NSTableView()
    private let reader = NSTextView()
    private var chapters: [Chapter] = []
    private var blocks: [(range: NSRange, code: String)] = []
    private let runner = RunConsole()

    convenience init() {
        var size = NSSize(width: 1120, height: 760)
        if let visible = NSScreen.main?.visibleFrame.size {
            size.width = min(size.width, visible.width - 80)
            size.height = min(size.height, visible.height - 80)
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "SPRFST Guidebook"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.ink
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        self.init(window: window)
        build()
        load()
    }

    private func build() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Theme.ink.cgColor

        // chapter list
        list.headerView = nil
        list.backgroundColor = .clear
        list.rowHeight = 34
        list.dataSource = self
        list.delegate = self
        list.target = self
        list.action = #selector(choose)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.width = 240
        list.addTableColumn(col)

        let listScroll = NSScrollView()
        listScroll.documentView = list
        listScroll.drawsBackground = true
        listScroll.backgroundColor = Theme.panel
        listScroll.hasVerticalScroller = true

        // reader
        reader.isEditable = false
        reader.backgroundColor = Theme.ink
        reader.textColor = Theme.text
        reader.textContainerInset = NSSize(width: 32, height: 28)
        let readerScroll = NSScrollView()
        readerScroll.documentView = reader
        readerScroll.hasVerticalScroller = true
        readerScroll.drawsBackground = true
        readerScroll.backgroundColor = Theme.ink

        // chapter list on the left, reader in the middle, runner below
        let listWidth = listScroll.widthAnchor.constraint(equalToConstant: 250)
        let runnerHeight = runner.heightAnchor.constraint(equalToConstant: 220)
        let listDivider = DragDivider(.width, listWidth, sign: 1, from: 170, to: 420)
        let runnerDivider = DragDivider(.height, runnerHeight, sign: 1, from: 60, to: 520)

        for view in [listScroll, readerScroll, runner] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        content.addSubview(listDivider)
        content.addSubview(runnerDivider)

        NSLayoutConstraint.activate([
            listWidth, runnerHeight,

            listScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            listScroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            listScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            listDivider.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor),
            listDivider.topAnchor.constraint(equalTo: content.topAnchor),
            listDivider.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            readerScroll.leadingAnchor.constraint(equalTo: listDivider.trailingAnchor),
            readerScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            readerScroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            readerScroll.bottomAnchor.constraint(equalTo: runnerDivider.topAnchor),

            runnerDivider.leadingAnchor.constraint(equalTo: listDivider.trailingAnchor),
            runnerDivider.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            runnerDivider.bottomAnchor.constraint(equalTo: runner.topAnchor),

            runner.leadingAnchor.constraint(equalTo: listDivider.trailingAnchor),
            runner.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            runner.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
    }

    private func load() {
        chapters = GuidebookWindow.discover()
        list.reloadData()
        if !chapters.isEmpty {
            list.selectRowIndexes([0], byExtendingSelection: false)
            show(chapters[0])
        } else {
            reader.string = "The guidebook files were not found in this build."
        }
    }

    static func discover() -> [Chapter] {
        var roots: [String] = []
        if let r = Bundle.main.resourcePath { roots.append(r + "/guidebook") }
        roots.append(FileManager.default.currentDirectoryPath + "/guidebook")
        if Toolchain.shared.isAvailable { roots.append(Toolchain.shared.home + "/guidebook") }

        for root in roots {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
            let md = files.filter { $0.hasSuffix(".md") }.sorted()
            if md.isEmpty { continue }
            return md.enumerated().map { index, name in
                let stem = name.replacingOccurrences(of: ".md", with: "")
                let parts = stem.split(separator: "-", maxSplits: 1)
                let number = Int(parts.first ?? "") ?? index + 1
                let title = parts.count > 1
                    ? parts[1].replacingOccurrences(of: "-", with: " ").capitalized
                    : stem
                return Chapter(number: number, title: title, path: root + "/" + name)
            }
        }
        return []
    }

    @objc private func choose() {
        let row = list.selectedRow
        guard row >= 0 && row < chapters.count else { return }
        show(chapters[row])
    }

    private func show(_ chapter: Chapter) {
        let source = (try? String(contentsOfFile: chapter.path, encoding: .utf8)) ?? ""
        let rendered = GuidebookWindow.render(source)
        reader.textStorage?.setAttributedString(rendered.text)
        blocks = rendered.blocks
        reader.scroll(NSPoint(x: 0, y: 0))
        addRunButtons()
    }

    /// Minimal Markdown: headings, code fences, lists, emphasis.
    static func render(_ markdown: String) -> (text: NSAttributedString, blocks: [(range: NSRange, code: String)]) {
        let out = NSMutableAttributedString()
        var blocks: [(NSRange, String)] = []
        var inCode = false
        var codeStart = 0
        var code = ""

        for raw in markdown.components(separatedBy: "\n") {
            if raw.hasPrefix("```") {
                if inCode {
                    blocks.append((NSRange(location: codeStart, length: out.length - codeStart), code))
                    inCode = false
                    code = ""
                    out.append(NSAttributedString(string: "\n"))
                } else {
                    inCode = true
                    codeStart = out.length
                }
                continue
            }
            if inCode {
                code += raw + "\n"
                out.append(NSAttributedString(string: raw + "\n", attributes: [
                    .font: Fonts.code(),
                    .foregroundColor: Theme.amberLight,
                    .backgroundColor: Theme.panel
                ]))
                continue
            }
            if raw.hasPrefix("### ") {
                out.append(NSAttributedString(string: String(raw.dropFirst(4)) + "\n\n", attributes: [
                    .font: Fonts.ui(15, weight: .semibold), .foregroundColor: Theme.text]))
            } else if raw.hasPrefix("## ") {
                out.append(NSAttributedString(string: String(raw.dropFirst(3)) + "\n\n", attributes: [
                    .font: Fonts.hand(22), .foregroundColor: Theme.amber]))
            } else if raw.hasPrefix("# ") {
                out.append(NSAttributedString(string: String(raw.dropFirst(2)) + "\n\n", attributes: [
                    .font: Fonts.hand(32), .foregroundColor: Theme.amber]))
            } else if raw.hasPrefix("- ") || raw.hasPrefix("* ") {
                out.append(NSAttributedString(string: "  •  " + String(raw.dropFirst(2)) + "\n", attributes: [
                    .font: Fonts.ui(13), .foregroundColor: Theme.text]))
            } else if raw.hasPrefix("> ") {
                out.append(NSAttributedString(string: "  " + String(raw.dropFirst(2)) + "\n", attributes: [
                    .font: Fonts.ui(13, weight: .medium), .foregroundColor: Theme.amberLight]))
            } else {
                out.append(NSAttributedString(string: raw + "\n", attributes: [
                    .font: Fonts.ui(13), .foregroundColor: Theme.text]))
            }
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        out.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: out.length))
        return (out, blocks.map { (range: $0.0, code: $0.1) })
    }

    /// Put a Run button beside every SPRFST block.
    private func addRunButtons() {
        reader.subviews.forEach { $0.removeFromSuperview() }
        guard let layout = reader.layoutManager, let container = reader.textContainer else { return }
        for (index, block) in blocks.enumerated() {
            guard block.range.location + block.range.length <= (reader.string as NSString).length else { continue }
            let glyphs = layout.glyphRange(forCharacterRange: block.range, actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.y += reader.textContainerInset.height
            rect.origin.x += reader.textContainerInset.width

            let button = NSButton(title: "Try it", target: self, action: #selector(runBlock(_:)))
            button.tag = index
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = Fonts.ui(11, weight: .semibold)
            button.contentTintColor = Theme.ink
            button.wantsLayer = true
            button.layer?.backgroundColor = Theme.amber.cgColor
            button.layer?.cornerRadius = 5
            button.frame = NSRect(x: reader.bounds.width - 110, y: rect.minY, width: 58, height: 20)
            button.autoresizingMask = [.minXMargin]
            reader.addSubview(button)
        }
    }

    @objc private func runBlock(_ sender: NSButton) {
        guard sender.tag < blocks.count else { return }
        let code = blocks[sender.tag].code
        let tmp = NSTemporaryDirectory() + "sprfst-guidebook-\(UUID().uuidString).spf"
        let program = code.contains("fn main(")
            ? code
            : "use std.io\n\nfn main() {\n" + code.split(separator: "\n").map { "    " + $0 }.joined(separator: "\n") + "\n}\n"
        try? program.write(toFile: tmp, atomically: true, encoding: .utf8)
        runner.runWithFigures(file: tmp, cwd: NSTemporaryDirectory())
    }
}

extension GuidebookWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { chapters.count }

    func tableView(_ t: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let chapter = chapters[row]
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 8)
        let n = label(String(format: "%02d", chapter.number), Fonts.code(), Theme.amber)
        n.widthAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(n)
        stack.addArrangedSubview(label(chapter.title, Fonts.ui(12), Theme.text))
        return stack
    }

    func tableView(_ t: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { CompletionRow() }
}
