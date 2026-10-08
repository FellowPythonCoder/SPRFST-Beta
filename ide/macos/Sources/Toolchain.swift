// =====================================================================
//  Toolchain — everything Studio asks the compiler to do.
//
//  Two channels:
//    * a long lived `sprfst studio` process for anything interactive
//      (diagnostics, outline, completion, hover, definition, format)
//    * short lived `sprfst <verb>` runs for build, test, run and git
// =====================================================================
import Foundation

struct Diagnostic: Decodable {
    let level: String
    let code: String
    let message: String
    let file: String
    let line: Int
    let col: Int
    let endLine: Int?
    let endCol: Int?
    let notes: [String]?
    let fixes: [String]?

    enum CodingKeys: String, CodingKey {
        case level, code, message, file, line, col
        case endLine = "end_line", endCol = "end_col"
        case notes, fixes
    }

    var isError: Bool { level == "error" }
}

struct OutlineItem: Decodable {
    let kind: String
    let name: String
    let line: Int
    let col: Int
    let start: Int
    let end: Int
    let detail: String
}

struct SemanticToken: Decodable {
    let line: Int
    let col: Int
    let len: Int
    let kind: String
}

struct Completion: Decodable {
    let label: String
    let detail: String
    let doc: String
    let kind: String
}

struct HoverInfo: Decodable {
    let ok: Bool
    let kind: String?
    let name: String?
    let type: String?
    let signature: String?
    let doc: String?
    let module: String?
    let line: Int?
    let col: Int?
    let file: String?
}

struct RunResult {
    let output: String
    let errors: String
    let exitCode: Int32
    let seconds: Double
}

/// Finds and drives the `sprfst` binary.
final class Toolchain {
    static let shared = Toolchain()

    private(set) var binary: String = ""
    private(set) var home: String = ""
    private var service: Process?
    private var toService: FileHandle?
    private var fromService: FileHandle?
    private var buffer = Data()
    private let lock = NSLock()

    var version: String = "unknown"

    private init() { locate() }

    // ----------------------------------------------------------- setup
    private func locate() {
        let bundled = Bundle.main.bundlePath + "/Contents/Resources/sprfst"
        let bundledHome = Bundle.main.bundlePath + "/Contents/Resources"
        var candidates: [(String, String)] = [(bundled, bundledHome)]
        if let saved = UserDefaults.standard.string(forKey: "sprfst.binary") {
            candidates.insert((saved, (saved as NSString).deletingLastPathComponent + "/.."), at: 0)
        }
        candidates += [
            ("/usr/local/bin/sprfst", "/usr/local/lib/sprfst"),
            ("/opt/homebrew/bin/sprfst", "/opt/homebrew/lib/sprfst"),
            (NSHomeDirectory() + "/.sprfst/bin/sprfst", NSHomeDirectory() + "/.sprfst")
        ]
        for (bin, h) in candidates where FileManager.default.isExecutableFile(atPath: bin) {
            binary = bin
            home = h
            break
        }
        if !binary.isEmpty {
            version = (try? runOnce(["version"]).output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        }
    }

    var isAvailable: Bool { !binary.isEmpty }

    func use(binary path: String) {
        binary = path
        home = (path as NSString).deletingLastPathComponent + "/.."
        UserDefaults.standard.set(path, forKey: "sprfst.binary")
        stopService()
    }

    // ------------------------------------------------- one shot verbs
    @discardableResult
    func runOnce(_ arguments: [String], cwd: String? = nil, stdin: String? = nil) throws -> RunResult {
        guard isAvailable else {
            return RunResult(output: "", errors: "the sprfst compiler was not found", exitCode: 127, seconds: 0)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        if !home.isEmpty { env["SPRFST_HOME"] = home }
        env["SPRFST_UI"] = env["SPRFST_UI"] ?? "json"
        task.environment = env
        if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        let out = Pipe(), err = Pipe(), inp = Pipe()
        task.standardOutput = out
        task.standardError = err
        task.standardInput = inp

        let started = Date()
        try task.run()
        if let stdin { inp.fileHandleForWriting.write(stdin.data(using: .utf8)!) }
        inp.fileHandleForWriting.closeFile()

        let oData = out.fileHandleForReading.readDataToEndOfFile()
        let eData = err.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        return RunResult(output: String(data: oData, encoding: .utf8) ?? "",
                         errors: String(data: eData, encoding: .utf8) ?? "",
                         exitCode: task.terminationStatus,
                         seconds: Date().timeIntervalSince(started))
    }

    /// Run a program and stream its output back line by line.
    func runStreaming(_ arguments: [String], cwd: String?,
                      onLine: @escaping (String, Bool) -> Void,
                      onFinish: @escaping (Int32, Double) -> Void) -> Process? {
        guard isAvailable else { onFinish(127, 0); return nil }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        if !home.isEmpty { env["SPRFST_HOME"] = home }
        env["SPRFST_UI"] = "json"
        task.environment = env
        if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }

        let out = Pipe(), err = Pipe()
        task.standardOutput = out
        task.standardError = err
        let started = Date()

        out.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.isEmpty { return }
            if let s = String(data: d, encoding: .utf8) {
                DispatchQueue.main.async { onLine(s, false) }
            }
        }
        err.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.isEmpty { return }
            if let s = String(data: d, encoding: .utf8) {
                DispatchQueue.main.async { onLine(s, true) }
            }
        }
        task.terminationHandler = { t in
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onFinish(t.terminationStatus, Date().timeIntervalSince(started)) }
        }
        do { try task.run() } catch { onFinish(1, 0); return nil }
        return task
    }

    // ------------------------------------------------ language service
    private func startService() {
        guard service == nil, isAvailable else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binary)
        task.arguments = ["studio"]
        var env = ProcessInfo.processInfo.environment
        if !home.isEmpty { env["SPRFST_HOME"] = home }
        task.environment = env

        let toIn = Pipe(), fromOut = Pipe()
        task.standardInput = toIn
        task.standardOutput = fromOut
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return }

        service = task
        toService = toIn.fileHandleForWriting
        fromService = fromOut.fileHandleForReading
        _ = readLine_()            // the handshake
    }

    func stopService() {
        service?.terminate()
        service = nil
        toService = nil
        fromService = nil
        buffer.removeAll()
    }

    private func readLine_() -> String? {
        guard let handle = fromService else { return nil }
        while true {
            if let idx = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<idx)
                buffer.removeSubrange(buffer.startIndex...idx)
                return String(data: line, encoding: .utf8)
            }
            let chunk = handle.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
    }

    /// Send one request and decode the single JSON line that comes back.
    private func ask(_ request: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        startService()
        guard let out = toService else { return nil }
        guard let payload = (request + "\n").data(using: .utf8) else { return nil }
        out.write(payload)
        guard let line = readLine_() else {
            stopService()
            return nil
        }
        return line.data(using: .utf8)
    }

    private struct Wrapper<T: Decodable>: Decodable {
        let ok: Bool
        let value: T?
    }

    func diagnostics(for path: String) -> [Diagnostic] {
        struct Reply: Decodable { let ok: Bool; let diagnostics: [Diagnostic] }
        guard let data = ask("check \(path)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return reply.diagnostics
    }

    func outline(for path: String) -> [OutlineItem] {
        struct Reply: Decodable { let ok: Bool; let symbols: [OutlineItem] }
        guard let data = ask("outline \(path)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return reply.symbols
    }

    func tokens(for path: String) -> [SemanticToken] {
        struct Reply: Decodable { let ok: Bool; let tokens: [SemanticToken] }
        guard let data = ask("tokens \(path)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return reply.tokens
    }

    func completions(for path: String, offset: Int) -> [Completion] {
        struct Reply: Decodable { let ok: Bool; let items: [Completion] }
        guard let data = ask("complete \(path) \(offset)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return reply.items
    }

    func hover(for path: String, offset: Int) -> HoverInfo? {
        guard let data = ask("hover \(path) \(offset)") else { return nil }
        return try? JSONDecoder().decode(HoverInfo.self, from: data)
    }

    func definition(for path: String, offset: Int) -> HoverInfo? {
        guard let data = ask("define \(path) \(offset)") else { return nil }
        return try? JSONDecoder().decode(HoverInfo.self, from: data)
    }

    struct RenameSpan: Decodable { let start: Int; let end: Int }
    func occurrences(for path: String, offset: Int) -> (String, [RenameSpan]) {
        struct Reply: Decodable { let ok: Bool; let name: String?; let occurrences: [RenameSpan]? }
        guard let data = ask("rename \(path) \(offset)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return ("", []) }
        return (reply.name ?? "", reply.occurrences ?? [])
    }

    func formatted(_ path: String) -> String? {
        struct Reply: Decodable { let ok: Bool; let changed: Bool; let text: String }
        guard let data = ask("format \(path)"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return nil }
        return reply.text
    }

    struct NativeDoc: Decodable { let module: String; let name: String; let sig: String; let doc: String }
    lazy var natives: [NativeDoc] = {
        struct Reply: Decodable { let ok: Bool; let natives: [NativeDoc] }
        guard let data = ask("natives"),
              let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return reply.natives
    }()
}
