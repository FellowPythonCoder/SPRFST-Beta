// =====================================================================
//  SPRFST Studio — application entry point, menus and settings.
// =====================================================================
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var studio: StudioWindowController?
    var guidebook: GuidebookWindow?
    private var pendingFiles: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = LogoView.image(size: 512)
        buildMenu()

        let window = StudioWindowController()
        studio = window
        window.showWindow(nil)
        window.window?.makeKeyAndOrderFront(nil)

        // a folder on the command line, or the folder of the first file
        let args = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-") }
        if let first = args.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: first, isDirectory: &isDirectory) {
                if isDirectory.boolValue { window.open(folder: first) }
                else {
                    window.open(folder: (first as NSString).deletingLastPathComponent)
                    window.open(path: first)
                }
            }
        }
        for file in pendingFiles { openFile(file) }
        pendingFiles.removeAll()

        if !Toolchain.shared.isAvailable { askForCompiler() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        if studio == nil { pendingFiles.append(filename); return true }
        openFile(filename)
        return true
    }

    private func openFile(_ path: String) {
        guard let studio else { return }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            studio.open(folder: path)
        } else {
            let folder = (path as NSString).deletingLastPathComponent
            if studio.projectFolder != folder { studio.open(folder: folder) }
            studio.open(path: path)
        }
        studio.window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        Toolchain.shared.stopService()
    }

    // ----------------------------------------------------- compiler
    private func askForCompiler() {
        let alert = NSAlert()
        alert.messageText = "The sprfst compiler was not found"
        alert.informativeText = """
        Studio drives the real compiler for everything it shows: diagnostics, \
        completion, running, testing and debugging. Point it at your sprfst binary, \
        or install one with  make install.
        """
        alert.addButton(withTitle: "Choose…")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        chooseCompiler(nil)
    }

    @objc func chooseCompiler(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Choose the sprfst binary"
        if panel.runModal() == .OK, let url = panel.url {
            Toolchain.shared.use(binary: url.path)
            studio?.refreshAnalysis()
        }
    }

    // ---------------------------------------------------- guidebook
    @objc func openGuidebook(_ sender: Any?) {
        if guidebook == nil { guidebook = GuidebookWindow() }
        guidebook?.showWindow(nil)
        guidebook?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showAbout(_ sender: Any?) {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "About SPRFST Studio"
        panel.backgroundColor = Theme.ink
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.center()

        let logo = LogoView(frame: .zero)
        logo.showPlate = false
        logo.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            logo,
            label("SPRFST Studio", Fonts.hand(28), Theme.text),
            label(Toolchain.shared.isAvailable ? Toolchain.shared.version : "compiler not found",
                  Fonts.ui(12), Theme.muted),
            label("A small, fast language and the place to write it.", Fonts.ui(12), Theme.muted)
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 96),
            logo.heightAnchor.constraint(equalToConstant: 96)
        ])
        panel.makeKeyAndOrderFront(nil)
    }

    // ----------------------------------------------------- settings
    @objc func openSettings(_ sender: Any?) {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Settings"
        panel.backgroundColor = Theme.ink
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.center()

        let fontPopup = NSPopUpButton()
        fontPopup.addItems(withTitles: Fonts.Face.allCases.map(\.rawValue))
        fontPopup.selectItem(withTitle: Fonts.current.rawValue)
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged(_:))

        let sizeStepper = NSSlider(value: Double(Fonts.size), minValue: 10, maxValue: 22,
                                   target: self, action: #selector(sizeChanged(_:)))
        sizeStepper.numberOfTickMarks = 13
        sizeStepper.allowsTickMarkValuesOnly = true

        let compiler = NSButton(title: "Choose the sprfst binary…", target: self, action: #selector(chooseCompiler(_:)))
        compiler.bezelStyle = .rounded

        let grid = NSStackView(views: [
            label("Editor font", Fonts.ui(12, weight: .medium), Theme.text), fontPopup,
            label("Font size", Fonts.ui(12, weight: .medium), Theme.text), sizeStepper,
            label("Compiler", Fonts.ui(12, weight: .medium), Theme.text), compiler,
            label(Toolchain.shared.isAvailable ? Toolchain.shared.binary : "not found", Fonts.ui(10), Theme.muted)
        ])
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 10
        grid.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        grid.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(grid)
        grid.fill(panel.contentView!)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func fontChanged(_ sender: NSPopUpButton) {
        guard let face = Fonts.Face(rawValue: sender.titleOfSelectedItem ?? "") else { return }
        Fonts.current = face
        studio?.currentEditor?.reloadSyntax()
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        Fonts.size = CGFloat(sender.doubleValue.rounded())
        studio?.currentEditor?.reloadSyntax()
    }

    // --------------------------------------------------------- menu
    private func buildMenu() {
        let main = NSMenu()

        // application
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SPRFST Studio", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide SPRFST Studio", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit SPRFST Studio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // file
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        add(fileMenu, "New project…", #selector(StudioWindowController.openCommandPalette(_:)), "n", [.command, .shift])
        add(fileMenu, "Open folder…", #selector(StudioWindowController.openCommandPalette(_:)), "o", [.command, .shift])
        fileMenu.addItem(.separator())
        add(fileMenu, "Save", #selector(StudioWindowController.saveDocument(_:)), "s", [.command])
        add(fileMenu, "Format", #selector(StudioWindowController.formatDocument(_:)), "f", [.command, .control])
        fileMenu.addItem(.separator())
        add(fileMenu, "Close tab", #selector(StudioWindowController.closeCurrentTab), "w", [.command])
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        // edit
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        add(editMenu, "Undo", Selector(("undo:")), "z", [.command])
        add(editMenu, "Redo", Selector(("redo:")), "z", [.command, .shift])
        editMenu.addItem(.separator())
        add(editMenu, "Cut", #selector(NSText.cut(_:)), "x", [.command])
        add(editMenu, "Copy", #selector(NSText.copy(_:)), "c", [.command])
        add(editMenu, "Paste", #selector(NSText.paste(_:)), "v", [.command])
        add(editMenu, "Select all", #selector(NSText.selectAll(_:)), "a", [.command])
        editMenu.addItem(.separator())
        add(editMenu, "Complete", #selector(StudioWindowController.completeHere(_:)), " ", [.control])
        add(editMenu, "Quick help", #selector(StudioWindowController.showHover(_:)), "i", [.command, .control])
        add(editMenu, "Go to definition", #selector(StudioWindowController.goToDefinition(_:)), "j", [.command, .control])
        add(editMenu, "Rename…", #selector(StudioWindowController.renameSymbol(_:)), "e", [.command, .control])
        editItem.submenu = editMenu
        main.addItem(editItem)

        // run
        let runItem = NSMenuItem()
        let runMenu = NSMenu(title: "Run")
        add(runMenu, "Run", #selector(StudioWindowController.runProject(_:)), "r", [.command])
        add(runMenu, "Build", #selector(StudioWindowController.buildProject(_:)), "b", [.command])
        add(runMenu, "Test", #selector(StudioWindowController.testProject(_:)), "u", [.command])
        add(runMenu, "Check", #selector(StudioWindowController.checkProject(_:)), "k", [.command, .shift])
        runMenu.addItem(.separator())
        add(runMenu, "Start debugging", #selector(StudioWindowController.startDebugging(_:)), "d", [.command])
        add(runMenu, "Continue", #selector(StudioWindowController.debugContinue(_:)), "y", [.command, .control])
        add(runMenu, "Step into", #selector(StudioWindowController.debugStepInto(_:)), "i", [.command, .shift])
        add(runMenu, "Step over", #selector(StudioWindowController.debugStepOver(_:)), "o", [.command, .shift])
        add(runMenu, "Step out", #selector(StudioWindowController.debugStepOut(_:)), "p", [.command, .shift])
        add(runMenu, "Toggle breakpoint", #selector(StudioWindowController.toggleBreakpoint(_:)), "\\", [.command])
        runMenu.addItem(.separator())
        add(runMenu, "Stop", #selector(StudioWindowController.stopRunning(_:)), ".", [.command])
        runItem.submenu = runMenu
        main.addItem(runItem)

        // view
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        add(viewMenu, "Command palette", #selector(StudioWindowController.openCommandPalette(_:)), "p", [.command, .shift])
        add(viewMenu, "Terminal", #selector(StudioWindowController.focusTerminal(_:)), "`", [.control])
        viewMenu.addItem(.separator())
        add(viewMenu, "Enter full screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control, .shift])
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        // help
        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        add(helpMenu, "SPRFST Guidebook", #selector(openGuidebook(_:)), "0", [.command])
        helpItem.submenu = helpMenu
        main.addItem(helpItem)

        NSApp.mainMenu = main
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector,
                     _ key: String, _ modifiers: NSEvent.ModifierFlags) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
