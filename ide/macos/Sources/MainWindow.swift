// =====================================================================
//  The Studio window: welcome screen, editor tabs, side panels,
//  bottom strip, status bar and the command palette.
// =====================================================================
import AppKit

final class StudioWindowController: NSWindowController, EditorDelegate, NSTabViewDelegate {

    // panes
    private let explorer   = ExplorerPanel()
    private let problems   = ProblemsPanel()
    private let outline    = OutlinePanel()
    private let gitPanel   = GitPanel()
    private let debugger   = DebuggerPanel()
    private let terminal   = TerminalPanel()
    private let console    = RunConsole()
    private let tabs       = NSTabView()
    private let statusBar  = NSView()
    private let statusLeft = NSTextField(labelWithString: "")
    private let statusRight = NSTextField(labelWithString: "")
    private let welcome    = WelcomeView()

    private var editors: [String: EditorView] = [:]
    private var checkTimer: Timer?
    var projectFolder: String = FileManager.default.currentDirectoryPath

    // ---------------------------------------------------------- setup
    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1420, height: 900),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "SPRFST Studio"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = Theme.ink
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 980, height: 620)
        window.center()
        self.init(window: window)
        build()
        showWelcome()
    }

    private func build() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Theme.ink.cgColor

        // left column: explorer over outline
        let left = NSSplitView()
        left.isVertical = false
        left.dividerStyle = .thin
        left.addArrangedSubview(explorer)
        left.addArrangedSubview(outline)

        // right column: problems over git over debugger
        let right = NSSplitView()
        right.isVertical = false
        right.dividerStyle = .thin
        right.addArrangedSubview(problems)
        right.addArrangedSubview(gitPanel)
        right.addArrangedSubview(debugger)

        // bottom strip
        let bottom = NSTabView()
        bottom.tabViewType = .topTabsBezelBorder
        bottom.appearance = NSAppearance(named: .darkAqua)
        let consoleTab = NSTabViewItem(identifier: "console")
        consoleTab.label = "Run"
        consoleTab.view = console
        let terminalTab = NSTabViewItem(identifier: "terminal")
        terminalTab.label = "Terminal"
        terminalTab.view = terminal
        bottom.addTabViewItem(consoleTab)
        bottom.addTabViewItem(terminalTab)

        // centre: editor tabs over the bottom strip
        tabs.tabViewType = .topTabsBezelBorder
        tabs.appearance = NSAppearance(named: .darkAqua)
        tabs.delegate = self

        let centreStack = NSSplitView()
        centreStack.isVertical = false
        centreStack.dividerStyle = .thin
        centreStack.addArrangedSubview(tabs)
        centreStack.addArrangedSubview(bottom)

        let main = NSSplitView()
        main.isVertical = true
        main.dividerStyle = .thin
        main.addArrangedSubview(left)
        main.addArrangedSubview(centreStack)
        main.addArrangedSubview(right)

        // status bar
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = Theme.panel.cgColor
        for field in [statusLeft, statusRight] {
            field.font = Fonts.ui(11)
            field.textColor = Theme.muted
            field.backgroundColor = .clear
            field.isBezeled = false
            field.isEditable = false
            field.translatesAutoresizingMaskIntoConstraints = false
            statusBar.addSubview(field)
        }
        NSLayoutConstraint.activate([
            statusLeft.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 14),
            statusLeft.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            statusRight.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -14),
            statusRight.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])

        let column = NSStackView()
        column.orientation = .vertical
        column.spacing = 0
        column.distribution = .fill
        column.translatesAutoresizingMaskIntoConstraints = false
        main.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        column.addArrangedSubview(main)
        column.addArrangedSubview(statusBar)
        column.fill(content)
        statusBar.heightAnchor.constraint(equalToConstant: 24).isActive = true
        statusBar.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        main.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        DispatchQueue.main.async {
            main.setPosition(268, ofDividerAt: 0)
            main.setPosition(main.bounds.width - 330, ofDividerAt: 1)
            centreStack.setPosition(centreStack.bounds.height - 230, ofDividerAt: 0)
            left.setPosition(left.bounds.height * 0.62, ofDividerAt: 0)
            right.setPosition(right.bounds.height * 0.38, ofDividerAt: 0)
            right.setPosition(right.bounds.height * 0.68, ofDividerAt: 1)
        }

        // wiring
        explorer.onOpen = { [weak self] url in self?.open(path: url.path) }
        problems.onSelect = { [weak self] d in
            self?.open(path: d.file)
            self?.currentEditor?.go(toLine: d.line, column: d.col)
        }
        outline.onSelect = { [weak self] item in self?.currentEditor?.go(toLine: item.line, column: item.col) }
        debugger.onStopped = { [weak self] line in self?.currentEditor?.setExecutionLine(line) }
        welcome.onOpenFolder = { [weak self] in self?.chooseFolder() }
        welcome.onNewProject = { [weak self] in self?.newProject() }
        welcome.onOpenGuide = { NSApp.sendAction(#selector(AppDelegate.openGuidebook), to: nil, from: nil) }
        welcome.onOpenExample = { [weak self] path in self?.open(path: path) }

        updateStatus()
    }

    // ------------------------------------------------------- welcome
    private func showWelcome() {
        let item = NSTabViewItem(identifier: "welcome")
        item.label = "Welcome"
        item.view = welcome
        tabs.addTabViewItem(item)
    }

    // ------------------------------------------------- opening things
    var currentEditor: EditorView? {
        tabs.selectedTabViewItem?.view as? EditorView
    }

    var currentPath: String? { currentEditor?.path }

    func open(folder: String) {
        projectFolder = folder
        explorer.open(folder: URL(fileURLWithPath: folder))
        gitPanel.use(folder: folder)
        terminal.use(folder: folder)
        window?.title = "SPRFST Studio — " + (folder as NSString).lastPathComponent
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: folder))

        // open the entry file if there is one
        for candidate in ["src/main.spf", "main.spf"] {
            let path = folder + "/" + candidate
            if FileManager.default.fileExists(atPath: path) { open(path: path); break }
        }
        updateStatus()
    }

    func open(path: String) {
        if let existing = editors[path] {
            for item in tabs.tabViewItems where item.view === existing {
                tabs.selectTabViewItem(item)
                return
            }
        }
        guard FileManager.default.fileExists(atPath: path) else { return }

        let editor = EditorView(frame: .zero)
        editor.delegate = self
        editor.load(path: path)
        editors[path] = editor

        let item = NSTabViewItem(identifier: path)
        item.label = (path as NSString).lastPathComponent
        item.view = editor
        tabs.addTabViewItem(item)
        tabs.selectTabViewItem(item)

        if tabs.tabViewItems.first?.identifier as? String == "welcome", tabs.numberOfTabViewItems > 1 {
            tabs.removeTabViewItem(tabs.tabViewItems[0])
        }
        refreshAnalysis()
    }

    @objc func closeCurrentTab() {
        guard let item = tabs.selectedTabViewItem else { return }
        if let editor = item.view as? EditorView {
            if editor.isDirty { editor.save() }
            editors.removeValue(forKey: editor.path)
        }
        tabs.removeTabViewItem(item)
        if tabs.numberOfTabViewItems == 0 { showWelcome() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url { open(folder: url.path) }
    }

    private func newProject() {
        let panel = NSSavePanel()
        panel.title = "New SPRFST project"
        panel.nameFieldStringValue = "my-app"
        panel.prompt = "Create"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let parent = url.deletingLastPathComponent().path
        let name = url.lastPathComponent
        _ = try? Toolchain.shared.runOnce(["new", name], cwd: parent)
        open(folder: url.path)
    }

    // -------------------------------------------------- live analysis
    func editorDidChange(_ editor: EditorView) {
        updateStatus()
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            editor.save()                           // the compiler reads from disk
            self?.refreshAnalysis()
        }
    }

    func editorRequestsSave(_ editor: EditorView) {
        editor.save()
        refreshAnalysis()
    }

    func editor(_ editor: EditorView, toggledBreakpointAt line: Int) {
        updateStatus()
    }

    func editor(_ editor: EditorView, jumpTo file: String, line: Int) {
        open(path: file)
        currentEditor?.go(toLine: line)
    }

    func refreshAnalysis() {
        guard let editor = currentEditor, !editor.path.isEmpty else { return }
        let path = editor.path
        DispatchQueue.global(qos: .userInitiated).async {
            let diagnostics = Toolchain.shared.diagnostics(for: path)
            let symbols = Toolchain.shared.outline(for: path)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentEditor?.path == path else { return }
                self.problems.show(diagnostics)
                self.outline.show(symbols)
                editor.markProblems(diagnostics.filter { ($0.file as NSString).lastPathComponent
                                                        == (path as NSString).lastPathComponent })
                self.updateStatus()
            }
        }
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        refreshAnalysis()
        updateStatus()
        gitPanel.refresh()
    }

    private func updateStatus() {
        let version = Toolchain.shared.isAvailable ? Toolchain.shared.version : "compiler not found"
        if let editor = currentEditor {
            let (line, column) = editor.caretLineColumn
            statusLeft.stringValue = "\((editor.path as NSString).lastPathComponent)\(editor.isDirty ? " •" : "")   line \(line), column \(column)"
            let marks = editor.breakpoints
            statusRight.stringValue = (marks.isEmpty ? "" : "\(marks.count) breakpoints   ") + version
        } else {
            statusLeft.stringValue = projectFolder
            statusRight.stringValue = version
        }
    }

    // ------------------------------------------------------- commands
    @objc func saveDocument(_ sender: Any?) {
        currentEditor?.save()
        refreshAnalysis()
        updateStatus()
    }

    @objc func runProject(_ sender: Any?) {
        currentEditor?.save()
        let target = currentPath ?? projectFolder
        console.runWithFigures(file: target, cwd: projectFolder)
    }

    @objc func buildProject(_ sender: Any?) {
        currentEditor?.save()
        console.run(arguments: ["build", projectFolder], cwd: projectFolder, title: "build")
    }

    @objc func testProject(_ sender: Any?) {
        currentEditor?.save()
        console.run(arguments: ["test", projectFolder], cwd: projectFolder, title: "tests")
    }

    @objc func checkProject(_ sender: Any?) {
        currentEditor?.save()
        refreshAnalysis()
        console.run(arguments: ["check", currentPath ?? projectFolder], cwd: projectFolder, title: "check")
    }

    @objc func formatDocument(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        if let formatted = Toolchain.shared.formatted(editor.path), formatted != editor.text {
            let caret = editor.textView.selectedRange()
            editor.text = formatted
            editor.save()
            editor.textView.setSelectedRange(NSRange(location: min(caret.location, formatted.count), length: 0))
        }
    }

    @objc func stopRunning(_ sender: Any?) {
        console.stop()
        debugger.stop()
    }

    @objc func startDebugging(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        debugger.start(file: editor.path, breakpoints: editor.breakpoints, cwd: projectFolder)
    }

    @objc func debugContinue(_ sender: Any?) { debugger.send("c") }
    @objc func debugStepInto(_ sender: Any?)  { debugger.send("s") }
    @objc func debugStepOver(_ sender: Any?)  { debugger.send("n") }
    @objc func debugStepOut(_ sender: Any?)   { debugger.send("o") }
    @objc func debugVariables(_ sender: Any?) { debugger.send("v") }
    @objc func debugStack(_ sender: Any?)     { debugger.send("k") }

    @objc func toggleBreakpoint(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.toggleBreakpoint(line: editor.caretLineColumn.0)
    }

    @objc func focusTerminal(_ sender: Any?) { terminal.focusInput() }

    @objc func completeHere(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        let items = Toolchain.shared.completions(for: editor.path, offset: editor.caretOffset)
        editor.showCompletions(items)
    }

    @objc func showHover(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        if let info = Toolchain.shared.hover(for: editor.path, offset: editor.caretOffset), info.ok {
            editor.showHover(info)
        }
    }

    @objc func goToDefinition(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        guard let info = Toolchain.shared.definition(for: editor.path, offset: editor.caretOffset),
              info.ok, let line = info.line else { return }
        if let file = info.file, file != editor.path { open(path: file) }
        currentEditor?.go(toLine: line, column: info.col ?? 1)
    }

    @objc func renameSymbol(_ sender: Any?) {
        guard let editor = currentEditor else { return }
        editor.save()
        let (name, spans) = Toolchain.shared.occurrences(for: editor.path, offset: editor.caretOffset)
        guard !name.isEmpty, !spans.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Rename ‘\(name)’"
        alert.informativeText = "\(spans.count) places in this file will change."
        let field = NSTextField(string: name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let replacement = field.stringValue
        guard !replacement.isEmpty, replacement != name else { return }

        var text = editor.text as NSString
        for span in spans.sorted(by: { $0.start > $1.start }) {
            guard span.start >= 0, span.end <= text.length else { continue }
            text = text.replacingCharacters(in: NSRange(location: span.start, length: span.end - span.start),
                                            with: replacement) as NSString
        }
        editor.text = text as String
        editor.save()
        refreshAnalysis()
    }

    @objc func openCommandPalette(_ sender: Any?) {
        guard let window else { return }
        let palette = CommandPalette(commands: paletteCommands())
        palette.present(over: window)
    }

    private func paletteCommands() -> [PaletteCommand] {
        var commands: [PaletteCommand] = [
            PaletteCommand(title: "Run", subtitle: "⌘R", action: { [weak self] in self?.runProject(nil) }),
            PaletteCommand(title: "Build", subtitle: "⌘B", action: { [weak self] in self?.buildProject(nil) }),
            PaletteCommand(title: "Test", subtitle: "⌘U", action: { [weak self] in self?.testProject(nil) }),
            PaletteCommand(title: "Check", subtitle: "type check", action: { [weak self] in self?.checkProject(nil) }),
            PaletteCommand(title: "Format", subtitle: "⌃⌘F", action: { [weak self] in self?.formatDocument(nil) }),
            PaletteCommand(title: "Debug", subtitle: "⌘D", action: { [weak self] in self?.startDebugging(nil) }),
            PaletteCommand(title: "Toggle breakpoint", subtitle: "⌘\\", action: { [weak self] in self?.toggleBreakpoint(nil) }),
            PaletteCommand(title: "Go to definition", subtitle: "⌃⌘J", action: { [weak self] in self?.goToDefinition(nil) }),
            PaletteCommand(title: "Rename", subtitle: "⌃⌘E", action: { [weak self] in self?.renameSymbol(nil) }),
            PaletteCommand(title: "Open folder…", subtitle: "⇧⌘O", action: { [weak self] in self?.chooseFolder() }),
            PaletteCommand(title: "New project…", subtitle: "⇧⌘N", action: { [weak self] in self?.newProject() }),
            PaletteCommand(title: "Guidebook", subtitle: "⌘0", action: {
                NSApp.sendAction(#selector(AppDelegate.openGuidebook), to: nil, from: nil) }),
            PaletteCommand(title: "Terminal", subtitle: "⌃`", action: { [weak self] in self?.focusTerminal(nil) }),
            PaletteCommand(title: "Generate documentation", subtitle: "sprfst docs", action: { [weak self] in
                guard let self else { return }
                self.console.run(arguments: ["docs", self.projectFolder], cwd: self.projectFolder, title: "docs") }),
            PaletteCommand(title: "Lint", subtitle: "sprfst lint", action: { [weak self] in
                guard let self else { return }
                self.console.run(arguments: ["lint", self.projectFolder], cwd: self.projectFolder, title: "lint") })
        ]
        // every symbol in the open file is reachable from the palette
        for item in outlineItems() {
            commands.append(PaletteCommand(title: item.name, subtitle: "\(item.kind)  line \(item.line)",
                                           action: { [weak self] in self?.currentEditor?.go(toLine: item.line) }))
        }
        return commands
    }

    private func outlineItems() -> [OutlineItem] {
        guard let path = currentPath else { return [] }
        return Toolchain.shared.outline(for: path)
    }
}

// ------------------------------------------------------ welcome view
final class WelcomeView: NSView {
    var onOpenFolder: (() -> Void)?
    var onNewProject: (() -> Void)?
    var onOpenGuide: (() -> Void)?
    var onOpenExample: ((String) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.ink.cgColor

        let logo = LogoView(frame: .zero)
        logo.showPlate = false
        logo.translatesAutoresizingMaskIntoConstraints = false

        let title = label("SPRFST Studio", Fonts.hand(42), Theme.text)
        let tagline = label("a small, fast language and the place to write it", Fonts.ui(14), Theme.muted)
        let version = label(Toolchain.shared.isAvailable
                            ? Toolchain.shared.version
                            : "the sprfst compiler was not found — set it in Settings",
                            Fonts.ui(11), Toolchain.shared.isAvailable ? Theme.faint : Theme.red)

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 12
        actions.addArrangedSubview(bigButton("New project", .amber) { [weak self] in self?.onNewProject?() })
        actions.addArrangedSubview(bigButton("Open folder", .edge) { [weak self] in self?.onOpenFolder?() })
        actions.addArrangedSubview(bigButton("Guidebook", .edge) { [weak self] in self?.onOpenGuide?() })

        let examples = NSStackView()
        examples.orientation = .vertical
        examples.alignment = .leading
        examples.spacing = 4
        examples.addArrangedSubview(label("EXAMPLES", Fonts.ui(10, weight: .semibold), Theme.faint))
        for path in WelcomeView.exampleFiles().prefix(8) {
            let name = (path as NSString).lastPathComponent
            let button = NSButton(title: name, target: nil, action: nil)
            button.isBordered = false
            button.font = Fonts.code()
            button.contentTintColor = Theme.amberLight
            button.alignment = .left
            button.target = self
            button.action = #selector(openExample(_:))
            button.identifier = NSUserInterfaceItemIdentifier(path)
            examples.addArrangedSubview(button)
        }

        let column = NSStackView(views: [logo, title, tagline, version, actions, examples])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 108),
            logo.heightAnchor.constraint(equalToConstant: 108)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func openExample(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        onOpenExample?(path)
    }

    static func exampleFiles() -> [String] {
        var roots: [String] = []
        if let r = Bundle.main.resourcePath { roots.append(r + "/examples") }
        if Toolchain.shared.isAvailable { roots.append(Toolchain.shared.home + "/examples") }
        roots.append(FileManager.default.currentDirectoryPath + "/examples")
        for root in roots {
            let files = ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? [])
                .filter { $0.hasSuffix(".spf") }.sorted()
            if !files.isEmpty { return files.map { root + "/" + $0 } }
        }
        return []
    }

    private func bigButton(_ title: String, _ tint: NSColor, _ action: @escaping () -> Void) -> NSView {
        let button = ActionButton(title: title, action: action)
        button.wantsLayer = true
        button.isBordered = false
        button.font = Fonts.ui(13, weight: .medium)
        button.contentTintColor = tint == .amber ? Theme.ink : Theme.text
        button.layer?.backgroundColor = (tint == .amber ? Theme.amber : Theme.edge).cgColor
        button.layer?.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        return button
    }
}

extension NSColor {
    static var amber: NSColor { Theme.amber }
    static var edge: NSColor { Theme.edge }
}

final class ActionButton: NSButton {
    private let handler: () -> Void
    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(frame: .zero)
        self.title = title
        self.bezelStyle = .rounded
        self.target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

// -------------------------------------------------- command palette
struct PaletteCommand {
    let title: String
    let subtitle: String
    let action: () -> Void
}

final class CommandPalette: NSWindow, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let field = NSTextField()
    private let table = NSTableView()
    private let all: [PaletteCommand]
    private var shown: [PaletteCommand] = []

    init(commands: [PaletteCommand]) {
        all = commands
        shown = commands
        super.init(contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .modalPanel

        let box = NSView().painted(Theme.raised, radius: 14)
        box.layer?.borderColor = Theme.edge.cgColor
        box.layer?.borderWidth = 1
        contentView = box

        field.placeholderString = "Type a command or a symbol…"
        field.font = Fonts.ui(16)
        field.textColor = Theme.text
        field.backgroundColor = .clear
        field.isBordered = false
        field.focusRingType = .none
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 32
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(choose)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.width = 580
        table.addTableColumn(col)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(field)
        box.addSubview(scroll)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
            field.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 18),
            field.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -18),
            scroll.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8)
        ])
        if !shown.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
    }

    func present(over parent: NSWindow) {
        let frame = parent.frame
        setFrameOrigin(NSPoint(x: frame.midX - 310, y: frame.midY - 40))
        parent.addChildWindow(self, ordered: .above)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(field)
    }

    override var canBecomeKey: Bool { true }

    func controlTextDidChange(_ obj: Notification) {
        let query = field.stringValue.lowercased()
        shown = query.isEmpty ? all : all.filter {
            $0.title.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
        }
        table.reloadData()
        if !shown.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: dismiss()
        case 36: choose()
        case 125 where table.selectedRow < shown.count - 1:
            table.selectRowIndexes([table.selectedRow + 1], byExtendingSelection: false)
            table.scrollRowToVisible(table.selectedRow)
        case 126 where table.selectedRow > 0:
            table.selectRowIndexes([table.selectedRow - 1], byExtendingSelection: false)
            table.scrollRowToVisible(table.selectedRow)
        default: super.keyDown(with: event)
        }
    }

    private func dismiss() {
        parent?.removeChildWindow(self)
        orderOut(nil)
    }

    @objc private func choose() {
        let row = table.selectedRow
        guard row >= 0, row < shown.count else { return }
        let command = shown[row]
        dismiss()
        DispatchQueue.main.async { command.action() }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ t: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let command = shown[row]
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        stack.addArrangedSubview(label(command.title, Fonts.ui(13), Theme.text))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(label(command.subtitle, Fonts.ui(11), Theme.muted))
        return stack
    }

    func tableView(_ t: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { CompletionRow() }
}
