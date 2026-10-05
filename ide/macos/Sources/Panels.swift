// =====================================================================
//  The side panels: file explorer, problems, outline, git and debugger.
// =====================================================================
import AppKit

// ------------------------------------------------------------ chrome
final class PanelHeader: NSView {
    private let title: NSTextField
    var accessory: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let a = accessory {
                a.translatesAutoresizingMaskIntoConstraints = false
                addSubview(a)
                NSLayoutConstraint.activate([
                    a.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                    a.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            }
        }
    }

    init(_ text: String) {
        title = label(text.uppercased(), Fonts.ui(10, weight: .semibold), Theme.muted)
        super.init(frame: .zero)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            // never run under the accessory button, never past the edge
            title.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -76),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ text: String) { title.stringValue = text.uppercased() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.panel.setFill()
        bounds.fill()
        Theme.edge.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    /// One line of text, truncated, never wider than the panel.
    func setDetail(_ text: String) { setTitle(text) }
}

func panelButton(_ symbol: String, _ tooltip: String, _ target: AnyObject, _ action: Selector) -> NSButton {
    let b = NSButton(title: symbol, target: target, action: action)
    b.bezelStyle = .inline
    b.isBordered = false
    b.font = Fonts.ui(11, weight: .medium)
    b.contentTintColor = Theme.muted
    b.toolTip = tooltip
    return b
}

// ---------------------------------------------------------- explorer
final class FileNode {
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?
    init(url: URL, isDirectory: Bool) { self.url = url; self.isDirectory = isDirectory }

    func load() -> [FileNode] {
        if let children { return children }
        guard isDirectory else { children = []; return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        let skip: Set<String> = ["build", "packages", ".git", "node_modules"]
        let nodes = contents
            .filter { !skip.contains($0.lastPathComponent) }
            .map { FileNode(url: $0, isDirectory: (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false) }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
        children = nodes
        return nodes
    }
}

final class ExplorerPanel: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let outline = NSOutlineView()
    private var root: FileNode?
    private let empty = label("no folder open\n⇧⌘O to choose one", Fonts.ui(12), Theme.faint)
    var onOpen: ((URL) -> Void)?
    let header = PanelHeader("Explorer")

    /// Whether a project folder has been opened in this panel.
    var hasFolder: Bool { root != nil }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor

        outline.headerView = nil
        outline.backgroundColor = .clear
        outline.rowHeight = 22
        outline.indentationPerLevel = 14
        outline.selectionHighlightStyle = .regular
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.action = #selector(clicked)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 240
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        header.translatesAutoresizingMaskIntoConstraints = false
        header.accessory = panelButton("Refresh", "Reload the folder", self, #selector(refresh))
        empty.alignment = .center
        empty.lineBreakMode = .byWordWrapping
        empty.maximumNumberOfLines = 2
        empty.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(scroll)
        addSubview(empty)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            empty.centerXAnchor.constraint(equalTo: centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func open(folder: URL) {
        root = FileNode(url: folder, isDirectory: true)
        empty.isHidden = true
        header.setTitle(folder.lastPathComponent.isEmpty ? "Explorer" : folder.lastPathComponent)
        outline.reloadData()
        outline.expandItem(nil, expandChildren: false)
        if let r = root {
            for child in r.load() where child.isDirectory && child.url.lastPathComponent == "src" {
                outline.expandItem(child)
            }
        }
    }

    @objc private func refresh() {
        guard let url = root?.url else { return }
        open(folder: url)
    }

    @objc private func clicked() {
        guard let node = outline.item(atRow: outline.selectedRow) as? FileNode else { return }
        if node.isDirectory {
            if outline.isItemExpanded(node) { outline.collapseItem(node) } else { outline.expandItem(node) }
        } else {
            onOpen?(node.url)
        }
    }

    func outlineView(_ v: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return root?.load().count ?? 0 }
        return (item as? FileNode)?.load().count ?? 0
    }
    func outlineView(_ v: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return root!.load()[index] }
        return (item as! FileNode).load()[index]
    }
    func outlineView(_ v: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileNode)?.isDirectory ?? false
    }
    func outlineView(_ v: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        let name = node.url.lastPathComponent
        let isSprfst = name.hasSuffix(".spf") || name == "project.sprfst"
        let icon = label(node.isDirectory ? "▸" : (isSprfst ? "◆" : "·"),
                         Fonts.ui(10), node.isDirectory ? Theme.muted : (isSprfst ? Theme.amber : Theme.faint))
        icon.widthAnchor.constraint(equalToConstant: 12).isActive = true
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label(name, Fonts.ui(12), node.isDirectory ? Theme.text : Theme.text.withAlphaComponent(0.85)))
        return row
    }
    func outlineView(_ v: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? { CompletionRow() }
}

// ---------------------------------------------------------- problems
final class ProblemsPanel: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private(set) var diagnostics: [Diagnostic] = []
    var onSelect: ((Diagnostic) -> Void)?
    let header = PanelHeader("Problems")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor

        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 46
        table.selectionHighlightStyle = .regular
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clicked)
        let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("p"))
        c.width = 320
        table.addTableColumn(c)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(_ items: [Diagnostic]) {
        diagnostics = items
        let errors = items.filter(\.isError).count
        let warnings = items.count - errors
        header.setTitle(items.isEmpty ? "Problems — none"
                                      : "Problems — \(errors) errors, \(warnings) warnings")
        table.reloadData()
    }

    @objc private func clicked() {
        guard table.selectedRow >= 0, table.selectedRow < diagnostics.count else { return }
        onSelect?(diagnostics[table.selectedRow])
    }

    func numberOfRows(in tableView: NSTableView) -> Int { diagnostics.count }

    func tableView(_ t: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let d = diagnostics[row]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 8)

        let top = NSStackView()
        top.orientation = .horizontal
        top.spacing = 6
        top.addArrangedSubview(label(d.code, Fonts.code(), d.isError ? Theme.red : Theme.amber))
        top.addArrangedSubview(label(d.message, Fonts.ui(12, weight: .medium), Theme.text))
        stack.addArrangedSubview(top)

        let where_ = "\((d.file as NSString).lastPathComponent):\(d.line):\(d.col)"
        let detail = d.fixes?.first.map { "\(where_)   \($0)" } ?? where_
        stack.addArrangedSubview(label(detail, Fonts.ui(11), Theme.muted))
        return stack
    }

    func tableView(_ t: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { CompletionRow() }
}

// ----------------------------------------------------------- outline
final class OutlinePanel: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private var items: [OutlineItem] = []
    var onSelect: ((OutlineItem) -> Void)?
    let header = PanelHeader("Outline")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor
        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 26
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clicked)
        let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("o"))
        c.width = 300
        table.addTableColumn(c)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(_ symbols: [OutlineItem]) {
        items = symbols
        header.setTitle("Outline — \(symbols.count)")
        table.reloadData()
    }

    @objc private func clicked() {
        guard table.selectedRow >= 0, table.selectedRow < items.count else { return }
        onSelect?(items[table.selectedRow])
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ t: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
        let tint: NSColor
        switch item.kind {
        case "fn", "task": tint = Theme.amber
        case "object", "data", "enum", "trait", "type": tint = Theme.blue
        case "test", "bench": tint = Theme.green
        case "app": tint = Theme.violet
        default: tint = Theme.muted
        }
        stack.addArrangedSubview(label(item.kind, Fonts.ui(10, weight: .semibold), tint))
        stack.addArrangedSubview(label(item.name, Fonts.code(), Theme.text))
        return stack
    }

    func tableView(_ t: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { CompletionRow() }
}

// ---------------------------------------------------------- debugger
final class DebuggerPanel: NSView {
    let header = PanelHeader("Debugger")
    private let transcript = NSTextView()
    private let input = NSTextField()
    private var session: Process?
    private var toDebugger: FileHandle?
    var onStopped: ((Int) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor

        transcript.isEditable = false
        transcript.backgroundColor = Theme.ink
        transcript.textColor = Theme.text
        transcript.font = Fonts.code()
        transcript.textContainerInset = NSSize(width: 10, height: 8)

        let scroll = NSScrollView()
        scroll.documentView = transcript
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        input.placeholderString = "debugger command — c continue, s step, n next, v variables, p name"
        input.font = Fonts.code()
        input.textColor = Theme.text
        input.backgroundColor = Theme.raised
        input.isBordered = false
        input.focusRingType = .none
        input.target = self
        input.action = #selector(submit)
        input.translatesAutoresizingMaskIntoConstraints = false

        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(scroll)
        addSubview(input)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: input.topAnchor, constant: -6),
            input.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            input.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            input.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            input.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    var isRunning: Bool { session?.isRunning ?? false }

    func start(file: String, breakpoints: [Int], cwd: String?) {
        stop()
        transcript.string = ""
        header.setTitle("Debugger — \((file as NSString).lastPathComponent)")

        var args = ["debug", file]
        for line in breakpoints { args.append("--break=\(line)") }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: Toolchain.shared.binary)
        task.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["SPRFST_HOME"] = Toolchain.shared.home
        env["SPRFST_UI"] = "none"
        task.environment = env
        if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        task.standardInput = inPipe
        task.standardOutput = outPipe
        task.standardError = errPipe

        let handler: (FileHandle) -> Void = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.append(text) }
        }
        outPipe.fileHandleForReading.readabilityHandler = handler
        errPipe.fileHandleForReading.readabilityHandler = handler
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.append("\n— session ended —\n") }
        }
        do { try task.run() } catch {
            append("could not start the debugger: \(error.localizedDescription)")
            return
        }
        session = task
        toDebugger = inPipe.fileHandleForWriting
        window?.makeFirstResponder(input)
    }

    func stop() {
        if session?.isRunning == true { send("q") }
        session?.terminate()
        session = nil
        toDebugger = nil
    }

    func send(_ command: String) {
        guard let toDebugger else { return }
        append("\(command)\n")
        toDebugger.write((command + "\n").data(using: .utf8)!)
    }

    @objc private func submit() {
        let text = input.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input.stringValue = ""
        send(text)
    }

    private func append(_ text: String) {
        let clean = text.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        let attributed = NSAttributedString(string: clean, attributes: [
            .font: Fonts.code(), .foregroundColor: Theme.text
        ])
        transcript.textStorage?.append(attributed)
        transcript.scrollToEndOfDocument(nil)

        // follow the debugger to the line it stopped on
        if let match = clean.range(of: #":(\d+)\s+in "#, options: .regularExpression) {
            let digits = clean[match].dropFirst().prefix(while: { $0.isNumber })
            if let line = Int(digits) { onStopped?(line) }
        }
    }
}

// --------------------------------------------------------------- git
final class GitPanel: NSView {
    let header = PanelHeader("Git")
    private let status = NSTextView()
    private let message = NSTextField()
    private let commit = NSButton(title: "Commit all", target: nil, action: nil)
    private var folder: String = "."

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor

        status.isEditable = false
        status.backgroundColor = Theme.ink
        status.textColor = Theme.text
        status.font = Fonts.code()
        status.textContainerInset = NSSize(width: 10, height: 8)

        let scroll = NSScrollView()
        scroll.documentView = status
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        message.placeholderString = "commit message"
        message.font = Fonts.ui(12)
        message.textColor = Theme.text
        message.backgroundColor = Theme.raised
        message.isBordered = false
        message.focusRingType = .none
        message.translatesAutoresizingMaskIntoConstraints = false

        commit.target = self
        commit.action = #selector(commitAll)
        commit.bezelStyle = .rounded
        commit.contentTintColor = Theme.amber
        commit.translatesAutoresizingMaskIntoConstraints = false

        header.accessory = panelButton("Refresh", "Refresh git status", self, #selector(refresh))
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(scroll)
        addSubview(message)
        addSubview(commit)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: message.topAnchor, constant: -8),
            message.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            message.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            message.bottomAnchor.constraint(equalTo: commit.topAnchor, constant: -6),
            message.heightAnchor.constraint(equalToConstant: 26),
            commit.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            commit.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            commit.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func use(folder: String) {
        self.folder = folder
        refresh()
    }

    @discardableResult
    private func git(_ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["git"] + args
        task.currentDirectoryURL = URL(fileURLWithPath: folder)
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return "git is not available" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    @objc func refresh() {
        let branch = git(["rev-parse", "--abbrev-ref", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if branch.isEmpty || branch.contains("fatal") || branch.contains("not a git repository") {
            header.setTitle("Git")
            status.string = "this folder is not a git repository\n"
            message.isEnabled = false
            commit.isEnabled = false
            return
        }
        message.isEnabled = true
        commit.isEnabled = true
        header.setTitle("Git — \(branch)")
        let changes = git(["status", "--short"])
        let log = git(["log", "--oneline", "-8"])
        status.string = (changes.isEmpty ? "working tree clean\n" : changes) + "\nrecent\n" + log
    }

    @objc private func commitAll() {
        let text = message.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            status.string = "write a commit message first\n" + status.string
            return
        }
        git(["add", "-A"])
        let result = git(["commit", "-m", text])
        message.stringValue = ""
        status.string = result + "\n"
        refresh()
    }
}
