// =====================================================================
//  The bottom strip: a real terminal, the run console and the
//  playground readout (output, errors, time and memory).
// =====================================================================
import AppKit

/// Shared output view with ANSI colour handling.
final class OutputView: NSView {
    let textView = StudioTextView(editable: false)
    private let scroll = NSScrollView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        mountTextView(textView, in: scroll, editable: false)
        textView.backgroundColor = Theme.ink
        textView.textColor = Theme.text
        textView.font = Fonts.code()
        textView.textContainerInset = NSSize(width: 12, height: 10)
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.ink
        scroll.fill(self)
    }
    required init?(coder: NSCoder) { fatalError() }

    func clear() { textView.string = "" }

    /// Turns the compiler's ANSI colours into real attributes so the
    /// diagnostics look the same inside Studio as in the terminal.
    func append(_ raw: String, fallback: NSColor = Theme.text) {
        var colour = fallback
        var buffer = ""
        var index = raw.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            textView.textStorage?.append(NSAttributedString(string: buffer, attributes: [
                .font: Fonts.code(), .foregroundColor: colour
            ]))
            buffer = ""
        }

        while index < raw.endIndex {
            let ch = raw[index]
            if ch == "\u{1B}", raw.index(after: index) < raw.endIndex,
               raw[raw.index(after: index)] == "[" {
                flush()
                var cursor = raw.index(index, offsetBy: 2)
                var code = ""
                while cursor < raw.endIndex, raw[cursor] != "m" {
                    code.append(raw[cursor])
                    cursor = raw.index(after: cursor)
                }
                colour = OutputView.colour(for: code, fallback: fallback)
                index = cursor < raw.endIndex ? raw.index(after: cursor) : cursor
                continue
            }
            buffer.append(ch)
            index = raw.index(after: index)
        }
        flush()
        textView.scrollToEndOfDocument(nil)
    }

    private static func colour(for code: String, fallback: NSColor) -> NSColor {
        if code.isEmpty || code == "0" { return fallback }
        if code == "1" { return Theme.text }
        if code == "2" { return Theme.muted }
        if code.hasPrefix("38;5;") {
            switch code.dropFirst(5) {
            case "214": return Theme.amber
            case "203": return Theme.red
            case "114": return Theme.green
            case "75":  return Theme.blue
            case "245": return Theme.muted
            default:    return fallback
            }
        }
        return fallback
    }
}

/// A working shell, so the project can be driven without leaving Studio.
final class TerminalPanel: NSView {
    private let output = OutputView()
    private let input = NSTextField()
    private var shell: Process?
    private var toShell: FileHandle?
    private var history: [String] = []
    private var historyIndex = 0
    var folder: String = NSHomeDirectory()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.ink.cgColor

        input.placeholderString = "a real shell — sprfst run .  ·  sprfst test  ·  git status"
        input.font = Fonts.code()
        input.textColor = Theme.text
        input.backgroundColor = Theme.raised
        input.isBordered = false
        input.focusRingType = .none
        input.target = self
        input.action = #selector(submit)

        output.translatesAutoresizingMaskIntoConstraints = false
        input.translatesAutoresizingMaskIntoConstraints = false
        addSubview(output)
        addSubview(input)
        NSLayoutConstraint.activate([
            output.topAnchor.constraint(equalTo: topAnchor),
            output.leadingAnchor.constraint(equalTo: leadingAnchor),
            output.trailingAnchor.constraint(equalTo: trailingAnchor),
            output.bottomAnchor.constraint(equalTo: input.topAnchor, constant: -6),
            input.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            input.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            input.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            input.heightAnchor.constraint(equalToConstant: 26)
        ])
        startShell()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func startShell() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-i"]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["PS1"] = "\\w $ "
        if Toolchain.shared.isAvailable {
            let bin = (Toolchain.shared.binary as NSString).deletingLastPathComponent
            env["PATH"] = bin + ":" + (env["PATH"] ?? "/usr/bin:/bin")
            env["SPRFST_HOME"] = Toolchain.shared.home
        }
        task.environment = env
        task.currentDirectoryURL = URL(fileURLWithPath: folder)

        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        task.standardInput = inPipe
        task.standardOutput = outPipe
        task.standardError = errPipe
        let handler: (FileHandle) -> Void = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.output.append(s) }
        }
        outPipe.fileHandleForReading.readabilityHandler = handler
        errPipe.fileHandleForReading.readabilityHandler = handler
        do { try task.run() } catch {
            output.append("could not start a shell\n", fallback: Theme.red)
            return
        }
        shell = task
        toShell = inPipe.fileHandleForWriting
    }

    func use(folder: String) {
        self.folder = folder
        run("cd '\(folder)'")
    }

    func run(_ command: String) {
        guard let toShell else { return }
        output.append("\n❯ \(command)\n", fallback: Theme.amber)
        toShell.write((command + "\n").data(using: .utf8)!)
    }

    func focusInput() { window?.makeFirstResponder(input) }

    @objc private func submit() {
        let command = input.stringValue
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        history.append(command)
        historyIndex = history.count
        input.stringValue = ""
        run(command)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126 where historyIndex > 0:                 // up
            historyIndex -= 1
            input.stringValue = history[historyIndex]
        case 125 where historyIndex < history.count - 1: // down
            historyIndex += 1
            input.stringValue = history[historyIndex]
        default: super.keyDown(with: event)
        }
    }
}

/// The run console: output plus the figures the spec asks for.
final class RunConsole: NSView {
    private let output = OutputView()
    private let stats = NSTextField(labelWithString: "")
    private var task: Process?
    var onFinished: ((Int32) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Theme.ink.cgColor

        stats.font = Fonts.ui(11)
        stats.textColor = Theme.muted
        stats.backgroundColor = .clear
        stats.isBezeled = false
        stats.isEditable = false

        output.translatesAutoresizingMaskIntoConstraints = false
        stats.translatesAutoresizingMaskIntoConstraints = false
        addSubview(output)
        addSubview(stats)
        NSLayoutConstraint.activate([
            output.topAnchor.constraint(equalTo: topAnchor),
            output.leadingAnchor.constraint(equalTo: leadingAnchor),
            output.trailingAnchor.constraint(equalTo: trailingAnchor),
            output.bottomAnchor.constraint(equalTo: stats.topAnchor, constant: -4),
            stats.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stats.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stats.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    var isRunning: Bool { task?.isRunning ?? false }

    func clear() {
        output.clear()
        stats.stringValue = ""
    }

    func stop() {
        task?.terminate()
        task = nil
        stats.stringValue = "stopped"
    }

    func run(arguments: [String], cwd: String?, title: String) {
        stop()
        output.clear()
        output.append("❯ sprfst \(arguments.joined(separator: " "))\n\n", fallback: Theme.amber)
        stats.stringValue = "running \(title)…"

        task = Toolchain.shared.runStreaming(arguments, cwd: cwd, onLine: { [weak self] text, isError in
            self?.output.append(text, fallback: isError ? Theme.text : Theme.text)
        }, onFinish: { [weak self] code, seconds in
            guard let self else { return }
            let colour = code == 0 ? Theme.green : Theme.red
            self.output.append("\n— finished with exit code \(code) —\n", fallback: colour)
            self.stats.stringValue = String(format: "exit %d   %.0f ms", code, seconds * 1000)
            self.task = nil
            self.onFinished?(code)
        })
    }

    /// Runs with --time so the compiler reports instructions and memory.
    func runWithFigures(file: String, cwd: String?) {
        stop()
        output.clear()
        output.append("❯ sprfst run \((file as NSString).lastPathComponent) --time\n\n", fallback: Theme.amber)
        var captured = ""
        task = Toolchain.shared.runStreaming(["run", file, "--time"], cwd: cwd, onLine: { [weak self] text, _ in
            captured += text
            self?.output.append(text)
        }, onFinish: { [weak self] code, seconds in
            guard let self else { return }
            let clean = captured.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
            var figures = String(format: "exit %d   wall %.0f ms", code, seconds * 1000)
            if let line = clean.components(separatedBy: "\n").last(where: { $0.contains("instr") }) {
                figures += "   " + line.trimmingCharacters(in: .whitespaces)
            }
            self.stats.stringValue = figures
            self.output.append("\n— \(figures) —\n", fallback: code == 0 ? Theme.green : Theme.red)
            self.task = nil
            self.onFinished?(code)
        })
    }
}
