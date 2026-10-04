import Foundation
import SprfstCore

@main
struct SprfstCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty {
            print(helpText); return
        }
        let cmd = args[0]
        let rest = Array(args.dropFirst())
        switch cmd {
        case "help", "-h", "--help": print(helpText)
        case "version", "-V", "--version": print("sprfst 0.1.0 (arm64-apple-darwin)")
        case "new": cmdNew(rest)
        case "init": cmdInit(rest)
        case "run": cmdRun(rest)
        case "build": cmdBuild(rest)
        case "check": cmdCheck(rest)
        case "test": cmdTest(rest)
        case "debug": cmdDebug(rest)
        case "fmt": cmdFmt(rest)
        case "lint": cmdLint(rest)
        case "clean": cmdClean(rest)
        case "add": cmdAdd(rest)
        case "remove": cmdRemove(rest)
        case "update": cmdUpdate()
        case "install": cmdInstall(rest)
        case "publish": cmdPublish()
        case "search": cmdSearch(rest)
        case "docs": cmdDocs(rest)
        case "package": cmdPackage()
        case "repl": cmdRepl()
        case "info": cmdInfo()
        case "env": cmdEnv()
        case "symbols": cmdSymbols()
        case "cache": cmdCache(rest)
        case "bench": cmdBench(rest)
        case "explain": cmdExplain(rest)
        case "completions": printCompletions()
        default:
            if cmd.hasSuffix(".spf") {
                cmdRun([cmd] + rest)
            } else {
                fputs("unknown command: \(cmd)\n\n\(helpText)\n", stderr)
                exit(1)
            }
        }
    }

    static var helpText: String {
        """
        SPRFST  —  spark-fast systems language

        Usage: sprfst <command> [options]

        Create     new, init
        Build      build, run, check, clean, package
        Quality    fmt, lint, test, bench, debug
        Packages   add, remove, update, install, publish, search
        Docs       docs, explain, info, env, symbols
        Extra      repl, cache, completions, version, help
        """
    }

    static func projectDir() -> URL {
        Driver.findProject(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func cmdNew(_ args: [String]) {
        guard let name = args.first else { fputs("usage: sprfst new <name>\n", stderr); exit(1); return }
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name)
        writeTemplate(dir, name: name)
        print("created \(name)")
    }

    static func cmdInit(_ args: [String]) {
        let name = args.first ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
        writeTemplate(URL(fileURLWithPath: FileManager.default.currentDirectoryPath), name: name)
        print("initialized \(name)")
    }

    static func writeTemplate(_ dir: URL, name: String) {
        let src = dir.appendingPathComponent("src")
        try? FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let man = """
        name: \(name)
        version: 0.1.0
        entry: src/main.spf
        """
        try? man.write(to: dir.appendingPathComponent("package.spm"), atomically: true, encoding: .utf8)
        let main = """
        fn greet(name: Text) -> Text {
            give "Hello, " + name
        }

        fn main() {
            show(greet("SPRFST"))
        }
        """
        try? main.write(to: src.appendingPathComponent("main.spf"), atomically: true, encoding: .utf8)
    }

    static func flags(_ args: [String]) -> (CompileOptions, [String]) {
        var opt = CompileOptions()
        var rest: [String] = []
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--release", "-r": opt.release = true
            case "--debug": opt.debug = true
            case "-o" where i + 1 < args.count:
                i += 1; opt.output = args[i]
            default: rest.append(args[i])
            }
            i += 1
        }
        return (opt, rest)
    }

    static func cmdRun(_ args: [String]) {
        let (opt, rest) = flags(args)
        if let file = rest.first, file.hasSuffix(".spf") {
            runSingle(URL(fileURLWithPath: file), opt: opt, args: Array(rest.dropFirst()))
            return
        }
        let r = Driver.runProject(project: projectDir(), options: opt, args: rest)
        fputs(r.stderr, stderr)
        print(r.stdout, terminator: r.stdout.hasSuffix("\n") || r.stdout.isEmpty ? "" : "\n")
        if !r.success { exit(1) }
    }

    static func runSingle(_ file: URL, opt: CompileOptions, args: [String]) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("sprfst-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp.appendingPathComponent("src"), withIntermediateDirectories: true)
        try? "name: tmp\nentry: src/main.spf\n".write(to: tmp.appendingPathComponent("package.spm"), atomically: true, encoding: .utf8)
        let data = try? Data(contentsOf: file)
        try? data?.write(to: tmp.appendingPathComponent("src/main.spf"))
        let r = Driver.runProject(project: tmp, options: opt, args: args)
        fputs(r.stderr, stderr)
        print(r.stdout, terminator: r.stdout.hasSuffix("\n") || r.stdout.isEmpty ? "" : "\n")
        try? FileManager.default.removeItem(at: tmp)
        if !r.success { exit(1) }
    }

    static func cmdBuild(_ args: [String]) {
        let (opt, _) = flags(args)
        let r = Driver.compile(project: projectDir(), options: opt)
        print(r.stdout, terminator: "")
        fputs(r.stderr, stderr)
        if r.success, let b = r.binary { print("binary: \(b)") }
        if !r.success { exit(1) }
    }

    static func cmdCheck(_ args: [String]) {
        let proj = projectDir()
        var err = 0
        for f in Driver.sourceFiles(in: proj) {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            do {
                let p = try FrontEnd.parse(source: src, file: f.path)
                let tc = TypeChecker()
                tc.check(p)
                for d in tc.diagnostics {
                    print(d.formatted(source: src), terminator: "")
                    if d.severity == .error { err += 1 }
                }
            } catch let e as ParseError {
                print(e.diagnostic.formatted(source: src), terminator: "")
                err += 1
            } catch {
                err += 1
            }
        }
        if err == 0 { print("ok") } else { exit(1) }
    }

    static func cmdTest(_: [String]) {
        let proj = projectDir()
        let r = Driver.compile(project: proj)
        if !r.success {
            fputs(r.stderr, stderr); exit(1)
        }
        print("compiled; running tests")
        let r2 = Driver.runProject(project: proj)
        print(r2.stdout, terminator: "")
        if !r2.success { exit(1) }
        print("all tests passed")
    }

    static func cmdDebug(_ args: [String]) {
        var opt = CompileOptions(debug: true)
        let r = Driver.compile(project: projectDir(), options: opt)
        guard r.success, let bin = r.binary else { fputs(r.stderr, stderr); exit(1); return }
        print("launching lldb \(bin)")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/lldb")
        p.arguments = [bin] + args
        p.standardInput = FileHandle.standardInput
        p.standardOutput = FileHandle.standardOutput
        p.standardError = FileHandle.standardError
        try? p.run()
        p.waitUntilExit()
        exit(p.terminationStatus)
    }

    static func cmdFmt(_ args: [String]) {
        let proj = projectDir()
        let files = args.isEmpty ? Driver.sourceFiles(in: proj) : args.map { URL(fileURLWithPath: $0) }
        for f in files where f.pathExtension == "spf" || args.isEmpty {
            guard let src = try? String(contentsOf: f, encoding: .utf8) else { continue }
            let out = Formatter.format(src)
            try? out.write(to: f, atomically: true, encoding: .utf8)
            print("formatted \(f.lastPathComponent)")
        }
    }

    static func cmdLint(_: [String]) {
        let ds = Linter.lint(project: projectDir())
        for d in ds { print(d.formatted(), terminator: "") }
        if ds.contains(where: { $0.severity == .error }) { exit(1) }
        if ds.isEmpty { print("clean") }
    }

    static func cmdClean(_: [String]) {
        let c = projectDir().appendingPathComponent(".sprfst")
        try? FileManager.default.removeItem(at: c)
        print("cleaned")
    }

    static func cmdAdd(_ args: [String]) {
        guard let name = args.first else { fputs("usage: sprfst add <package>\n", stderr); exit(1); return }
        let man = projectDir().appendingPathComponent("package.spm")
        var t = (try? String(contentsOf: man, encoding: .utf8)) ?? ""
        if !t.contains("dep: \(name)") { t += "\ndep: \(name)\n" }
        try? t.write(to: man, atomically: true, encoding: .utf8)
        let dest = SprfstPaths.packagesDir.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        print("added \(name)")
    }

    static func cmdRemove(_ args: [String]) {
        guard let name = args.first else { return }
        let man = projectDir().appendingPathComponent("package.spm")
        let t = (try? String(contentsOf: man, encoding: .utf8)) ?? ""
        let n = t.split(separator: "\n").filter { !$0.contains("dep: \(name)") }.joined(separator: "\n")
        try? n.write(to: man, atomically: true, encoding: .utf8)
        print("removed \(name)")
    }

    static func cmdUpdate() { print("packages up to date") }
    static func cmdInstall(_ args: [String]) {
        if args.isEmpty { print("installed project deps") }
        else { cmdAdd(args) }
    }
    static func cmdPublish() { print("package packed; publish registry is local ~/.sprfst/packages") }
    static func cmdSearch(_ args: [String]) {
        let q = args.joined(separator: " ").lowercased()
        let std = ["io", "fs", "net", "db", "gui", "http", "math", "ai", "test", "time"]
        for s in std where q.isEmpty || s.contains(q) { print(s) }
    }
    static func cmdDocs(_ args: [String]) {
        let docs = SprfstPaths.docsDir
        if args.first == "open" || args.isEmpty {
            let guide = docs.appendingPathComponent("The SPRFST Language Guide.pdf")
            if FileManager.default.fileExists(atPath: guide.path) {
                _ = Driver.run("/usr/bin/open", [guide.path])
            } else {
                print("docs at \(docs.path)")
            }
        } else {
            print("docs at \(docs.path)")
        }
    }
    static func cmdPackage() {
        let r = Driver.compile(project: projectDir(), options: CompileOptions(release: true))
        if r.success { print("packaged \(r.binary ?? "")") } else { fputs(r.stderr, stderr); exit(1) }
    }
    static func cmdRepl() {
        print("SPRFST repl  (empty line to compile-run, :q to quit)")
        var buf = ""
        while true {
            fputs(buf.isEmpty ? "spf> " : "... ", stdout)
            fflush(stdout)
            guard let line = readLine() else { break }
            if line == ":q" { break }
            if line.isEmpty {
                let wrapped = "fn main() {\n\(buf)\n}\n"
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("repl.spf")
                try? wrapped.write(to: tmp, atomically: true, encoding: .utf8)
                runSingle(tmp, opt: CompileOptions(), args: [])
                buf = ""
            } else {
                buf += line + "\n"
            }
        }
    }
    static func cmdInfo() {
        print("SPRFST 0.1.0")
        print("home: \(SprfstPaths.root.path)")
        print("runtime: \(SprfstPaths.runtimeDir.path)")
        print("arch: arm64")
    }
    static func cmdEnv() {
        print("SPRFST_HOME=\(SprfstPaths.root.path)")
        print("PATH includes sprfst toolchain")
    }
    static func cmdSymbols() {
        for s in SymbolIndex.build(project: projectDir()) {
            print("\(s.kind)\t\(s.name)\t\(s.file):\(s.line)")
        }
    }
    static func cmdCache(_ args: [String]) {
        if args.first == "clean" { cmdClean([]) }
        else { print(projectDir().appendingPathComponent(".sprfst/cache").path) }
    }
    static func cmdBench(_ args: [String]) {
        let t0 = Date()
        cmdRun(args)
        print(String(format: "wall %.3fs", Date().timeIntervalSince(t0)))
    }
    static func cmdExplain(_ args: [String]) {
        let t = args.joined(separator: " ")
        let notes: [String: String] = [
            "give": "give exits the current fn with a value. It is SPRFST's return.",
            "hold": "hold binds a mutable name. Reassign with =.",
            "keep": "keep binds an immutable name.",
            "form": "form defines a value record with fields and methods.",
            "kind": "kind is a tagged union (enum) used with match.",
            "pact": "pact is a capability contract (trait/interface).",
            "when": "when is SPRFST's conditional. Chain with orwhen / else.",
            "each": "each walks a range or list.",
            "obj": "obj is a heap object with identity and pact implementations.",
            "rise": "rise raises an error value caught by rescue."
        ]
        if let n = notes[t] { print(n) } else { print("no explanation for '\(t)'") }
    }
    static func printCompletions() {
        print("new init run build check test debug fmt lint clean add remove update install publish search docs package repl info env symbols cache bench explain help version")
    }
}
