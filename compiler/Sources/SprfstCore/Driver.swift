import Foundation

public struct PackageManifest: Equatable, Sendable {
    public var name: String
    public var version: String
    public var entry: String
    public var deps: [String]
    public static func parse(_ text: String) -> PackageManifest {
        var name = "app", version = "0.1.0", entry = "src/main.spf"
        var deps: [String] = []
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("name:") { name = line.dropFirst(5).trimmingCharacters(in: .whitespaces) }
            if line.hasPrefix("version:") { version = line.dropFirst(8).trimmingCharacters(in: .whitespaces) }
            if line.hasPrefix("entry:") { entry = line.dropFirst(6).trimmingCharacters(in: .whitespaces) }
            if line.hasPrefix("dep:") { deps.append(line.dropFirst(4).trimmingCharacters(in: .whitespaces)) }
        }
        return PackageManifest(name: name, version: version, entry: entry, deps: deps)
    }
}

public struct CompileOptions: Sendable {
    public var release: Bool
    public var emitIR: Bool
    public var debug: Bool
    public var jobs: Int
    public var output: String?
    public init(release: Bool = false, emitIR: Bool = false, debug: Bool = true, jobs: Int = 0, output: String? = nil) {
        self.release = release
        self.emitIR = emitIR
        self.debug = debug
        self.jobs = jobs
        self.output = output
    }
}

public struct CompileResult: Sendable {
    public var success: Bool
    public var diagnostics: [Diagnostic]
    public var binary: String?
    public var stdout: String
    public var stderr: String
}

public enum SprfstPaths {
    public static var root: URL {
        if let e = ProcessInfo.processInfo.environment["SPRFST_HOME"] {
            return URL(fileURLWithPath: e)
        }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        var dir = exe.deletingLastPathComponent()
        for _ in 0..<10 {
            let rt = dir.appendingPathComponent("runtime/sprfst_rt.h")
            if FileManager.default.fileExists(atPath: rt.path) { return dir.standardizedFileURL }
            let bundled = dir.appendingPathComponent("Resources/toolchain/runtime/sprfst_rt.h")
            if FileManager.default.fileExists(atPath: bundled.path) {
                return dir.appendingPathComponent("Resources/toolchain").standardizedFileURL
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("runtime/sprfst_rt.h").path) {
            return cwd
        }
        return URL(fileURLWithPath: "/usr/local/lib/sprfst")
    }
    public static var runtimeDir: URL { root.appendingPathComponent("runtime") }
    public static var stdDir: URL { root.appendingPathComponent("std") }
    public static var examplesDir: URL { root.appendingPathComponent("examples") }
    public static var docsDir: URL { root.appendingPathComponent("docs") }
    public static var packagesDir: URL {
        let h = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sprfst/packages")
        try? FileManager.default.createDirectory(at: h, withIntermediateDirectories: true)
        return h
    }
}

public enum Driver {
    public static func findProject(from dir: URL) -> URL? {
        var d = dir
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: d.appendingPathComponent("package.spm").path) { return d }
            let p = d.deletingLastPathComponent()
            if p.path == d.path { break }
            d = p
        }
        return nil
    }

    public static func sourceFiles(in project: URL) -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default
        guard let en = fm.enumerator(at: project, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in en {
            if url.path.contains("/.sprfst/") { continue }
            if url.pathExtension == "spf" { out.append(url) }
        }
        return out.sorted { $0.path < $1.path }
    }

    public static func compile(project: URL, options: CompileOptions = CompileOptions()) -> CompileResult {
        let t0 = Date()
        var diags: [Diagnostic] = []
        let manifestPath = project.appendingPathComponent("package.spm")
        let manifestText = (try? String(contentsOf: manifestPath, encoding: .utf8)) ?? "name: app\nentry: src/main.spf\n"
        let manifest = PackageManifest.parse(manifestText)
        var files = sourceFiles(in: project)
        let std = SprfstPaths.stdDir
        if let en = FileManager.default.enumerator(at: std, includingPropertiesForKeys: nil) {
            for case let url as URL in en where url.pathExtension == "spf" { files.append(url) }
        }
        var programs: [Program] = []
        var sources: [String: String] = [:]
        for f in files {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            sources[f.path] = src
            do {
                let prog = try FrontEnd.parse(source: src, file: f.path)
                programs.append(prog)
            } catch let e as ParseError {
                diags.append(e.diagnostic)
            } catch {
                diags.append(Diagnostic(.error, SourcePos(file: f.path, line: 1, column: 1), error.localizedDescription))
            }
        }
        if diags.contains(where: { $0.severity == .error }) {
            return CompileResult(success: false, diagnostics: diags, binary: nil, stdout: "", stderr: format(diags, sources: sources))
        }
        let checker = TypeChecker()
        for p in programs { checker.check(p) }
        diags.append(contentsOf: checker.diagnostics)
        if checker.diagnostics.contains(where: { $0.severity == .error }) {
            return CompileResult(success: false, diagnostics: diags, binary: nil, stdout: "", stderr: format(diags, sources: sources))
        }
        var optimized: [Program] = []
        for p in programs {
            optimized.append(Optimizer.optimize(p).program)
        }
        var cg = Codegen()
        let cCode = cg.emit(optimized)
        let cache = project.appendingPathComponent(".sprfst/cache")
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let cFile = cache.appendingPathComponent("out.c")
        try? cCode.write(to: cFile, atomically: true, encoding: .utf8)
        let binDir = project.appendingPathComponent(".sprfst/bin")
        try? FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        let binary = options.output.map { URL(fileURLWithPath: $0) } ?? binDir.appendingPathComponent(manifest.name)
        let rt = SprfstPaths.runtimeDir
        var args = [
            "-arch", "arm64",
            "-std=c11",
            "-I", rt.path,
            cFile.path,
            rt.appendingPathComponent("sprfst_rt.c").path,
            "-lsqlite3",
            "-lpthread",
            "-lm",
            "-o", binary.path
        ]
        if options.release {
            args.insert(contentsOf: ["-O3", "-DNS_BLOCK_ASSERTIONS"], at: 0)
        } else {
            args.insert(contentsOf: ["-O1", "-g"], at: 0)
        }
        let gui = rt.appendingPathComponent("sprfst_gui.m")
        if FileManager.default.fileExists(atPath: gui.path) {
            args.append(contentsOf: [gui.path, "-framework", "Cocoa", "-fobjc-arc"])
        }
        let clang = hostClang()
        let (st, so, se) = run(clang, args, cwd: project)
        let dt = Date().timeIntervalSince(t0)
        if st != 0 {
            diags.append(Diagnostic(.error, SourcePos(file: cFile.path, line: 1, column: 1), "clang failed"))
            return CompileResult(success: false, diagnostics: diags, binary: nil, stdout: so, stderr: se + "\n" + format(diags, sources: sources))
        }
        var notes = "compiled \(manifest.name) in \(String(format: "%.2f", dt))s\n"
        notes += format(diags, sources: sources)
        return CompileResult(success: true, diagnostics: diags, binary: binary.path, stdout: notes, stderr: se)
    }

    public static func runProject(project: URL, options: CompileOptions = CompileOptions(), args: [String] = []) -> CompileResult {
        let r = compile(project: project, options: options)
        guard r.success, let bin = r.binary else { return r }
        let (st, so, se) = run(bin, args, cwd: project)
        return CompileResult(success: st == 0, diagnostics: r.diagnostics, binary: bin, stdout: so, stderr: se)
    }

    public static func format(source: String) -> String {
        Formatter.format(source)
    }

    public static func lint(project: URL) -> [Diagnostic] {
        Linter.lint(project: project)
    }

    public static func format(_ diags: [Diagnostic], sources: [String: String]) -> String {
        diags.map { d in
            d.formatted(source: sources[d.pos.file])
        }.joined()
    }

    public static func hostClang() -> String {
        [" /usr/bin/clang", "/Library/Developer/CommandLineTools/usr/bin/clang"]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "clang"
    }

    @discardableResult
    public static func run(_ cmd: String, _ args: [String], cwd: URL? = nil, env: [String: String] = [:]) -> (Int32, String, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        if !env.isEmpty {
            var e = ProcessInfo.processInfo.environment
            for (k, v) in env { e[k] = v }
            p.environment = e
        }
        let o = Pipe(), e = Pipe()
        p.standardOutput = o
        p.standardError = e
        do { try p.run() } catch {
            return (1, "", error.localizedDescription)
        }
        p.waitUntilExit()
        let so = String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let se = String(data: e.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, so, se)
    }
}

public enum Formatter {
    public static func format(_ source: String) -> String {
        var s = source.replacingOccurrences(of: "\t", with: "    ")
        while s.contains("  \n") { s = s.replacingOccurrences(of: "  \n", with: "\n") }
        var lines: [String] = []
        var indent = 0
        for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
            var l = String(line).trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("}") { indent = max(0, indent - 1) }
            lines.append(String(repeating: "    ", count: indent) + l)
            if l.hasSuffix("{") { indent += 1 }
        }
        if !s.hasSuffix("\n") { return lines.joined(separator: "\n") + "\n" }
        return lines.joined(separator: "\n")
    }
}

public enum Linter {
    public static func lint(project: URL) -> [Diagnostic] {
        var d: [Diagnostic] = []
        for f in Driver.sourceFiles(in: project) {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            let lines = src.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() {
                if line.hasSuffix(" ") {
                    d.append(Diagnostic(.warning, SourcePos(file: f.path, line: i + 1, column: line.count), "trailing whitespace"))
                }
                if line.contains("TODO") {
                    d.append(Diagnostic(.note, SourcePos(file: f.path, line: i + 1, column: 1), "TODO comment"))
                }
            }
            do {
                _ = try FrontEnd.parse(source: src, file: f.path)
            } catch let e as ParseError {
                d.append(e.diagnostic)
            } catch {}
        }
        return d
    }
}

public enum SymbolIndex {
    public struct Symbol {
        public var name: String
        public var kind: String
        public var file: String
        public var line: Int
    }
    public static func build(project: URL) -> [Symbol] {
        var out: [Symbol] = []
        for f in Driver.sourceFiles(in: project) {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            guard let p = try? FrontEnd.parse(source: src, file: f.path) else { continue }
            for fn in p.fns { out.append(Symbol(name: fn.name, kind: "fn", file: f.path, line: fn.pos.line)) }
            for form in p.forms { out.append(Symbol(name: form.name, kind: "form", file: f.path, line: form.pos.line)) }
            for k in p.kinds { out.append(Symbol(name: k.name, kind: "kind", file: f.path, line: k.pos.line)) }
            for o in p.objs { out.append(Symbol(name: o.name, kind: "obj", file: f.path, line: o.pos.line)) }
        }
        return out
    }
}
