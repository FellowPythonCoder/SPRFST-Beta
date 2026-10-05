// =====================================================================
//  The Studio window: top bar, editor tabs, side panels, bottom strip,
//  status bar and the command palette.
//
//  The regions are laid out with plain Auto Layout and dragged with
//  DragDivider, not with nested NSSplitViews. A split view chooses its
//  divider positions from whatever size it happens to have at the
//  time, and at build time that size is nothing — which is how the
//  first version of this window opened with a 140 point wide editor.
// =====================================================================
import AppKit

final class StudioWindowController: NSWindowController, EditorDelegate {

    // panes
    private let explorer   = ExplorerPanel()
    private let problems   = ProblemsPanel()
    private let outline    = OutlinePanel()
    private let gitPanel   = GitPanel()
    private let debugger   = DebuggerPanel()
    private let terminal   = TerminalPanel()
    private let console    = RunConsole()
    private let welcome    = WelcomeView()

    /// What is open, in tab order. One of these views is visible at a
    /// time; the strip above them is built from this list, so the tabs
    /// and the editors can never disagree.
    private let editorHost = NSView()
    private var hosted: [(path: String, label: String, view: NSView)] = []
    private var activePath: String?

    // chrome
    private let editorStrip    = TabStrip()
    private let bottomStrip    = TabStrip()
    private let inspectorStrip = TabStrip()
    private let statusBar      = NSView()
    private let statusLeft     = NSTextField(labelWithString: "")
    private let statusRight    = NSTextField(labelWithString: "")
    private let wordmark       = WordmarkView()

    // the three resizable regions
    private var leftWidth: NSLayoutConstraint!
    private var rightWidth: NSLayoutConstraint!
    private var bottomHeight: NSLayoutConstraint!
    private var leftDivider: DragDivider!
    private var rightDivider: DragDivider!
    private var bottomDivider: DragDivider!
    private var lastLeftWidth: CGFloat = 250
    private var lastRightWidth: CGFloat = 310
    private var lastBottomHeight: CGFloat = 210

    private var editors: [String: EditorView] = [:]
    private var checkTimer: Timer?
    var projectFolder: String = NSHomeDirectory()

    // ---------------------------------------------------------- setup
    convenience init() {
        var size = NSSize(width: 1420, height: 900)
        if let visible = NSScreen.main?.visibleFrame.size {
            size.width = min(size.width, visible.width - 40)
            size.height = min(size.height, visible.height - 40)
        }
        // not .fullSizeContentView: the title bar is drawn over the top
        // 28 points of the content, which swallowed the whole top bar
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "SPRFST Studio"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = Theme.ink
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 900, height: 560)
        window.center()
        self.init(window: window)
        build()
        showWelcome()
    }

    private func build() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Theme.ink.cgColor

        let top = buildTopBar()
        let body = buildBody()
        buildStatusBar()

        for view in [top, body, statusBar] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let underTop = Hairline(horizontal: true)
        let overStatus = Hairline(horizontal: true)
        content.addSubview(underTop)
        content.addSubview(overStatus)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: content.topAnchor),
            top.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            top.heightAnchor.constraint(equalToConstant: Theme.topBarHeight),

            underTop.topAnchor.constraint(equalTo: top.bottomAnchor),
            underTop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            underTop.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            body.topAnchor.constraint(equalTo: underTop.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: overStatus.topAnchor),

            overStatus.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            overStatus.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            overStatus.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: Theme.statusHeight)
        ])

        wire()
        updateStatus()
    }

    // ------------------------------------------------------- top bar
    private func buildTopBar() -> NSView {
        let bar = NSView().painted(Theme.panel)

        wordmark.subtitle = nil
        wordmark.translatesAutoresizingMaskIntoConstraints = false

        let actions = NSStackView(views: [
            BarButton("Run", kind: .primary) { [weak self] in self?.runProject(nil) },
            BarButton("Stop") { [weak self] in self?.stopRunning(nil) },
            BarButton("Build") { [weak self] in self?.buildProject(nil) },
            BarButton("Test") { [weak self] in self?.testProject(nil) },
            BarButton("Debug") { [weak self] in self?.startDebugging(nil) },
            BarButton("Guidebook") { _ = NSApp.sendAction(#selector(AppDelegate.openGuidebook), to: nil, from: nil) },
            BarButton("⌘P") { [weak self] in self?.openCommandPalette(nil) }
        ])
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.translatesAutoresizingMaskIntoConstraints = false

        bar.addSubview(wordmark)
        bar.addSubview(actions)
        NSLayoutConstraint.activate([
            wordmark.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 18),
            wordmark.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            wordmark.widthAnchor.constraint(equalToConstant: 132),
            wordmark.heightAnchor.constraint(equalToConstant: 26),
            actions.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -14),
            actions.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            actions.leadingAnchor.constraint(greaterThanOrEqualTo: wordmark.trailingAnchor, constant: 20)
        ])
        return bar
    }

    // ---------------------------------------------------------- body
    private func buildBody() -> NSView {
        let body = NSView()

        let centre = buildCentre()
        let inspector = buildInspector()
        for view in [explorer, centre, inspector] {
            view.translatesAutoresizingMaskIntoConstraints = false
            body.addSubview(view)
        }

        leftWidth = explorer.widthAnchor.constraint(equalToConstant: lastLeftWidth)
        rightWidth = inspector.widthAnchor.constraint(equalToConstant: lastRightWidth)
        leftDivider = DragDivider(.width, leftWidth, sign: 1, from: 170, to: 520)
        rightDivider = DragDivider(.width, rightWidth, sign: -1, from: 220, to: 560)
        body.addSubview(leftDivider)
        body.addSubview(rightDivider)

        NSLayoutConstraint.activate([
            leftWidth, rightWidth,

            explorer.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            explorer.topAnchor.constraint(equalTo: body.topAnchor),
            explorer.bottomAnchor.constraint(equalTo: body.bottomAnchor),

            leftDivider.leadingAnchor.constraint(equalTo: explorer.trailingAnchor),
            leftDivider.topAnchor.constraint(equalTo: body.topAnchor),
            leftDivider.bottomAnchor.constraint(equalTo: body.bottomAnchor),

            centre.leadingAnchor.constraint(equalTo: leftDivider.trailingAnchor),
            centre.topAnchor.constraint(equalTo: body.topAnchor),
            centre.bottomAnchor.constraint(equalTo: body.bottomAnchor),

            rightDivider.leadingAnchor.constraint(equalTo: centre.trailingAnchor),
            rightDivider.topAnchor.constraint(equalTo: body.topAnchor),
            rightDivider.bottomAnchor.constraint(equalTo: body.bottomAnchor),

            inspector.leadingAnchor.constraint(equalTo: rightDivider.trailingAnchor),
            inspector.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            inspector.topAnchor.constraint(equalTo: body.topAnchor),
            inspector.bottomAnchor.constraint(equalTo: body.bottomAnchor)
        ])
        return body
    }

    private func buildCentre() -> NSView {
        let centre = NSView().painted(Theme.ink)

        editorHost.translatesAutoresizingMaskIntoConstraints = false
        editorHost.wantsLayer = true
        editorHost.layer?.backgroundColor = Theme.ink.cgColor

        let bottom = buildBottom()
        bottom.translatesAutoresizingMaskIntoConstraints = false
        bottomHeight = bottom.heightAnchor.constraint(equalToConstant: lastBottomHeight)
        bottomDivider = DragDivider(.height, bottomHeight, sign: 1, from: 90, to: 640)

        centre.addSubview(editorStrip)
        centre.addSubview(editorHost)
        centre.addSubview(bottomDivider)
        centre.addSubview(bottom)

        NSLayoutConstraint.activate([
            bottomHeight,

            editorStrip.topAnchor.constraint(equalTo: centre.topAnchor),
            editorStrip.leadingAnchor.constraint(equalTo: centre.leadingAnchor),
            editorStrip.trailingAnchor.constraint(equalTo: centre.trailingAnchor),

            editorHost.topAnchor.constraint(equalTo: editorStrip.bottomAnchor),
            editorHost.leadingAnchor.constraint(equalTo: centre.leadingAnchor),
            editorHost.trailingAnchor.constraint(equalTo: centre.trailingAnchor),
            editorHost.bottomAnchor.constraint(equalTo: bottomDivider.topAnchor),

            bottomDivider.leadingAnchor.constraint(equalTo: centre.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: centre.trailingAnchor),
            bottomDivider.bottomAnchor.constraint(equalTo: bottom.topAnchor),

            bottom.leadingAnchor.constraint(equalTo: centre.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: centre.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: centre.bottomAnchor)
        ])
        return centre
    }

    private func buildBottom() -> NSView {
        let host = NSView().painted(Theme.ink)
        console.translatesAutoresizingMaskIntoConstraints = false
        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.isHidden = true

        host.addSubview(bottomStrip)
        host.addSubview(console)
        host.addSubview(terminal)

        let clear = BarButton("Clear") { [weak self] in self?.console.clear() }
        bottomStrip.accessories.addArrangedSubview(clear)

        NSLayoutConstraint.activate([
            bottomStrip.topAnchor.constraint(equalTo: host.topAnchor),
            bottomStrip.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            bottomStrip.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            console.topAnchor.constraint(equalTo: bottomStrip.bottomAnchor),
            console.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            console.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            console.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            terminal.topAnchor.constraint(equalTo: bottomStrip.bottomAnchor),
            terminal.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            terminal.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        let run = TabButton("Run", target: self, action: #selector(showRunPane))
        let shell = TabButton("Terminal", target: self, action: #selector(showTerminalPane))
        run.isActive = true
        bottomStrip.setTabs([run, shell])
        return host
    }

    @objc private func showRunPane() {
        console.isHidden = false
        terminal.isHidden = true
        markStrip(bottomStrip, active: 0)
    }

    @objc private func showTerminalPane() {
        console.isHidden = true
        terminal.isHidden = false
        markStrip(bottomStrip, active: 1)
        terminal.focusInput()
    }

    // ----------------------------------------------------- inspector
    private var inspectorPanels: [NSView] = []

    private func buildInspector() -> NSView {
        let host = NSView().painted(Theme.panel)
        inspectorPanels = [problems, outline, gitPanel, debugger]

        host.addSubview(inspectorStrip)
        NSLayoutConstraint.activate([
            inspectorStrip.topAnchor.constraint(equalTo: host.topAnchor),
            inspectorStrip.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            inspectorStrip.trailingAnchor.constraint(equalTo: host.trailingAnchor)
        ])
        for panel in inspectorPanels {
            panel.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(panel)
            NSLayoutConstraint.activate([
                panel.topAnchor.constraint(equalTo: inspectorStrip.bottomAnchor),
                panel.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                panel.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                panel.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
            panel.isHidden = true
        }
        problems.isHidden = false

        let buttons = [
            TabButton("Problems", target: self, action: #selector(showProblemsPane)),
            TabButton("Outline", target: self, action: #selector(showOutlinePane)),
            TabButton("Git", target: self, action: #selector(showGitPane)),
            TabButton("Debug", target: self, action: #selector(showDebugPane))
        ]
        buttons[0].isActive = true
        inspectorStrip.setTabs(buttons)
        return host
    }

    private func showInspector(_ index: Int) {
        for (i, panel) in inspectorPanels.enumerated() { panel.isHidden = i != index }
        markStrip(inspectorStrip, active: index)
    }

    @objc private func showProblemsPane() { showInspector(0) }
    @objc private func showOutlinePane()  { showInspector(1) }
    @objc private func showGitPane()      { showInspector(2); gitPanel.refresh() }
    @objc private func showDebugPane()    { showInspector(3) }

    private func markStrip(_ strip: TabStrip, active: Int) {
        for (i, view) in strip.tabs.arrangedSubviews.enumerated() {
            (view as? TabButton)?.isActive = (i == active)
        }
    }

    // ----------------------------------------------------- status bar
    private func buildStatusBar() {
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = Theme.panel.cgColor
        for field in [statusLeft, statusRight] {
            field.font = Fonts.ui(11)
            field.textColor = Theme.muted
            field.backgroundColor = .clear
            field.isBezeled = false
            field.isEditable = false
            field.drawsBackground = false
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            statusBar.addSubview(field)
        }
        NSLayoutConstraint.activate([
            statusLeft.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 16),
            statusLeft.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            statusRight.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -16),
            statusRight.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            statusLeft.trailingAnchor.constraint(lessThanOrEqualTo: statusRight.leadingAnchor, constant: -20)
        ])
    }

    // --------------------------------------------------------- wiring
    private func wire() {
        explorer.onOpen = { [weak self] url in self?.open(path: url.path) }
        problems.onSelect = { [weak self] d in
            self?.open(path: d.file)
            self?.currentEditor?.go(toLine: d.line, column: d.col)
        }
        outline.onSelect = { [weak self] item in self?.currentEditor?.go(toLine: item.line, column: item.col) }
        debugger.onStopped = { [weak self] line in self?.currentEditor?.setExecutionLine(line) }
        welcome.onOpenFolder = { [weak self] in self?.chooseFolder() }
        welcome.onNewProject = { [weak self] in self?.newProject() }
        welcome.onOpenGuide = { _ = NSApp.sendAction(#selector(AppDelegate.openGuidebook), to: nil, from: nil) }
        welcome.onOpenExample = { [weak self] path in self?.open(path: path) }
    }

    // ------------------------------------------------------- welcome
    private func showWelcome() {
        if !hosted.contains(where: { $0.path == "welcome" }) {
            host(welcome, path: "welcome", label: "Welcome")
        }
        show(path: "welcome")
    }

    /// Put a view in the editor area. They all sit on top of each
    /// other, filling it; only the active one is visible.
    private func host(_ view: NSView, path: String, label: String) {
        view.translatesAutoresizingMaskIntoConstraints = false
        editorHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: editorHost.topAnchor),
            view.leadingAnchor.constraint(equalTo: editorHost.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: editorHost.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: editorHost.bottomAnchor)
        ])
        hosted.append((path: path, label: label, view: view))
    }

    private func show(path: String) {
        activePath = path
        for entry in hosted { entry.view.isHidden = entry.path != path }
        rebuildTabs()
        if let editor = currentEditor { window?.makeFirstResponder(editor.textView) }
        refreshAnalysis()
        updateStatus()
    }

    /// The strip is rebuilt from the list of open files every time it
    /// changes, so it cannot drift out of step with them.
    private func rebuildTabs() {
        var buttons: [TabButton] = []
        for entry in hosted {
            let path = entry.path
            let button = TabButton(entry.label, closable: path != "welcome",
                                   target: self, action: #selector(selectTab(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(path)
            button.isActive = path == activePath
            button.onClose = { [weak self] in self?.closeTab(path: path) }
            buttons.append(button)
        }
        editorStrip.setTabs(buttons)
    }

    @objc private func selectTab(_ sender: TabButton) {
        guard let path = sender.identifier?.rawValue else { return }
        show(path: path)
    }

    // ------------------------------------------------- opening things
    var currentEditor: EditorView? {
        guard let activePath else { return nil }
        return hosted.first(where: { $0.path == activePath })?.view as? EditorView
    }

    var currentPath: String? { currentEditor?.path }

    func open(folder: String) {
        projectFolder = folder
        explorer.open(folder: URL(fileURLWithPath: folder))
        gitPanel.use(folder: folder)
        terminal.use(folder: folder)
        window?.title = "SPRFST Studio — " + (folder as NSString).lastPathComponent
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: folder))

        for candidate in ["src/main.spf", "main.spf"] {
            let path = folder + "/" + candidate
            if FileManager.default.fileExists(atPath: path) { open(path: path); break }
        }
        updateStatus()
    }

    /// Examples live inside the application bundle, which nobody should
    /// be editing. The first time one is opened it is copied somewhere
    /// the user owns, and that copy is what opens.
    private func writableCopy(of path: String) -> String {
        let fm = FileManager.default
        guard path.hasPrefix(Bundle.main.bundlePath + "/") else { return path }
        let home = NSHomeDirectory() + "/Documents/SPRFST Examples"
        let source = (path as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: home, withIntermediateDirectories: true)
        for name in (try? fm.contentsOfDirectory(atPath: source)) ?? [] where name.hasSuffix(".spf") {
            let target = home + "/" + name
            if !fm.fileExists(atPath: target) {
                try? fm.copyItem(atPath: source + "/" + name, toPath: target)
            }
        }
        let copy = home + "/" + (path as NSString).lastPathComponent
        return fm.fileExists(atPath: copy) ? copy : path
    }

    func open(path rawPath: String) {
        let path = writableCopy(of: rawPath)
        if hosted.contains(where: { $0.path == path }) {
            show(path: path)
            return
        }
        guard FileManager.default.fileExists(atPath: path) else { return }

        // a loose file with no project open: follow it home
        if !explorer.hasFolder || !path.hasPrefix(projectFolder + "/") {
            if !path.hasPrefix(projectFolder + "/") {
                projectFolder = (path as NSString).deletingLastPathComponent
            }
            explorer.open(folder: URL(fileURLWithPath: projectFolder))
            gitPanel.use(folder: projectFolder)
            terminal.use(folder: projectFolder)
            window?.title = "SPRFST Studio — " + (projectFolder as NSString).lastPathComponent
        }

        let editor = EditorView(frame: .zero)
        editor.delegate = self
        editor.load(path: path)
        editors[path] = editor
        host(editor, path: path, label: (path as NSString).lastPathComponent)

        // the welcome screen steps aside once there is something to edit
        if let index = hosted.firstIndex(where: { $0.path == "welcome" }), hosted.count > 1 {
            hosted[index].view.removeFromSuperview()
            hosted.remove(at: index)
        }
        show(path: path)
    }

    @objc func closeCurrentTab() {
        guard let activePath else { return }
        closeTab(path: activePath)
    }

    private func closeTab(path: String) {
        guard let index = hosted.firstIndex(where: { $0.path == path }) else { return }
        if let editor = hosted[index].view as? EditorView {
            if editor.isDirty { editor.save() }
            editors.removeValue(forKey: editor.path)
        }
        hosted[index].view.removeFromSuperview()
        hosted.remove(at: index)
        if hosted.isEmpty {
            showWelcome()
        } else {
            show(path: hosted[min(index, hosted.count - 1)].path)
        }
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

    private func updateStatus() {
        let version = Toolchain.shared.isAvailable ? Toolchain.shared.version : "compiler not found"
        if let editor = currentEditor {
            let (line, column) = editor.caretLineColumn
            statusLeft.stringValue = "\((editor.path as NSString).lastPathComponent)"
                + (editor.isDirty ? "  •" : "")
                + "    line \(line), column \(column)"
            let marks = editor.breakpoints
            statusRight.stringValue = (marks.isEmpty ? "" : "\(marks.count) breakpoints    ") + version
        } else {
            statusLeft.stringValue = (projectFolder as NSString).abbreviatingWithTildeInPath
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
        showRunPane()
        let target = currentPath ?? projectFolder
        console.runWithFigures(file: target, cwd: projectFolder)
    }

    @objc func buildProject(_ sender: Any?) {
        currentEditor?.save()
        showRunPane()
        console.run(arguments: ["build", projectFolder], cwd: projectFolder, title: "build")
    }

    @objc func testProject(_ sender: Any?) {
        currentEditor?.save()
        showRunPane()
        console.run(arguments: ["test", projectFolder], cwd: projectFolder, title: "tests")
    }

    @objc func checkProject(_ sender: Any?) {
        currentEditor?.save()
        refreshAnalysis()
        showRunPane()
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
        showInspector(3)
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

    @objc func focusTerminal(_ sender: Any?) { showTerminalPane() }

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

    // --------------------------------------------------- panel toggles
    @objc func toggleExplorer(_ sender: Any?) {
        if leftWidth.constant > 1 {
            lastLeftWidth = leftWidth.constant
            leftWidth.constant = 0
            leftDivider.isHidden = true
        } else {
            leftWidth.constant = lastLeftWidth
            leftDivider.isHidden = false
        }
    }

    @objc func toggleInspector(_ sender: Any?) {
        if rightWidth.constant > 1 {
            lastRightWidth = rightWidth.constant
            rightWidth.constant = 0
            rightDivider.isHidden = true
        } else {
            rightWidth.constant = lastRightWidth
            rightDivider.isHidden = false
        }
    }

    @objc func toggleBottom(_ sender: Any?) {
        if bottomHeight.constant > 1 {
            lastBottomHeight = bottomHeight.constant
            bottomHeight.constant = 0
            bottomDivider.isHidden = true
        } else {
            bottomHeight.constant = lastBottomHeight
            bottomDivider.isHidden = false
        }
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
                _ = NSApp.sendAction(#selector(AppDelegate.openGuidebook), to: nil, from: nil) }),
            PaletteCommand(title: "Terminal", subtitle: "⌃`", action: { [weak self] in self?.focusTerminal(nil) }),
            PaletteCommand(title: "Hide or show the explorer", subtitle: "⌘1", action: { [weak self] in self?.toggleExplorer(nil) }),
            PaletteCommand(title: "Hide or show the inspector", subtitle: "⌘2", action: { [weak self] in self?.toggleInspector(nil) }),
            PaletteCommand(title: "Hide or show the bottom panel", subtitle: "⌘3", action: { [weak self] in self?.toggleBottom(nil) }),
            PaletteCommand(title: "Generate documentation", subtitle: "sprfst docs", action: { [weak self] in
                guard let self else { return }
                self.console.run(arguments: ["docs", self.projectFolder], cwd: self.projectFolder, title: "docs") }),
            PaletteCommand(title: "Lint", subtitle: "sprfst lint", action: { [weak self] in
                guard let self else { return }
                self.console.run(arguments: ["lint", self.projectFolder], cwd: self.projectFolder, title: "lint") })
        ]
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

        let title = label("SPRFST Studio", Fonts.hand(46, weight: .semibold), Theme.text)
        let tagline = label("a small, fast language and the place to write it", Fonts.ui(14), Theme.muted)
        let version = label(Toolchain.shared.isAvailable
                            ? Toolchain.shared.version
                            : "the sprfst compiler was not found — set it in Settings",
                            Fonts.ui(11), Toolchain.shared.isAvailable ? Theme.faint : Theme.red)

        let actions = NSStackView(views: [
            BarButton("New project", kind: .primary) { [weak self] in self?.onNewProject?() },
            BarButton("Open folder") { [weak self] in self?.onOpenFolder?() },
            BarButton("Guidebook") { [weak self] in self?.onOpenGuide?() }
        ])
        actions.orientation = .horizontal
        actions.spacing = 10

        let examples = NSStackView()
        examples.orientation = .vertical
        examples.alignment = .leading
        examples.spacing = 2
        examples.addArrangedSubview(label("EXAMPLES", Fonts.ui(10, weight: .semibold), Theme.faint))
        for path in WelcomeView.exampleFiles().prefix(8) {
            let name = (path as NSString).lastPathComponent
            let button = NSButton(title: name, target: self, action: #selector(openExample(_:)))
            button.isBordered = false
            button.font = Fonts.ui(12)
            button.contentTintColor = Theme.amberLight
            button.alignment = .left
            button.identifier = NSUserInterfaceItemIdentifier(path)
            examples.addArrangedSubview(button)
        }

        let column = NSStackView(views: [logo, title, tagline, version, actions, examples])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 16
        column.setCustomSpacing(26, after: version)
        column.setCustomSpacing(30, after: actions)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 104),
            logo.heightAnchor.constraint(equalToConstant: 104)
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
}

extension NSColor {
    static var amber: NSColor { Theme.amber }
    static var edge: NSColor { Theme.edge }
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
        table.gridStyleMask = []
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
