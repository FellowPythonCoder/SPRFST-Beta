import Foundation

public struct TypeEnv {
    public var vars: [String: TypeExpr] = [:]
    public var fns: [String: (params: [TypeExpr], ret: TypeExpr)] = [:]
    public var forms: [String: FormDecl] = [:]
    public var kinds: [String: KindDecl] = [:]
    public var objs: [String: ObjDecl] = [:]
}

public final class TypeChecker {
    public private(set) var diagnostics: [Diagnostic] = []
    public var env = TypeEnv()

    public init() {
        installBuiltins()
    }

    private func installBuiltins() {
        let I = TypeExpr("Int")
        let N = TypeExpr("Num")
        let T = TypeExpr("Text")
        let B = TypeExpr("Bool")
        let L = TypeExpr("List", [TypeExpr("Any")])
        env.fns["len"] = ([TypeExpr("Any")], I)
        env.fns["sqrt"] = ([N], N)
        env.fns["pow"] = ([N, N], N)
        env.fns["sin"] = ([N], N)
        env.fns["cos"] = ([N], N)
        env.fns["abs"] = ([N], N)
        env.fns["iabs"] = ([I], I)
        env.fns["min"] = ([I, I], I)
        env.fns["max"] = ([I, I], I)
        env.fns["now"] = ([], I)
        env.fns["clock"] = ([], N)
        env.fns["sleep"] = ([I], TypeExpr("Void"))
        env.fns["rand"] = ([I, I], I)
        env.fns["read"] = ([T], T)
        env.fns["write"] = ([T, T], I)
        env.fns["exists"] = ([T], B)
        env.fns["mkdir"] = ([T], B)
        env.fns["listdir"] = ([T], L)
        env.fns["remove"] = ([T], B)
        env.fns["http_get"] = ([T], T)
        env.fns["tcp_send"] = ([T, I, T], T)
        env.fns["db_open"] = ([T], I)
        env.fns["db_exec"] = ([I, T], I)
        env.fns["db_close"] = ([I], TypeExpr("Void"))
        env.fns["upper"] = ([T], T)
        env.fns["lower"] = ([T], T)
        env.fns["trim"] = ([T], T)
        env.fns["contains"] = ([T, T], B)
        env.fns["split"] = ([T, T], L)
        env.fns["text"] = ([TypeExpr("Any")], T)
        env.fns["int"] = ([TypeExpr("Any")], I)
        env.fns["num"] = ([TypeExpr("Any")], N)
        env.fns["gui_window"] = ([T, I, I], I)
        env.fns["gui_label"] = ([I, T, I, I], TypeExpr("Void"))
        env.fns["gui_button"] = ([I, T, I, I, I, I], I)
        env.fns["gui_run"] = ([I], TypeExpr("Void"))
        env.fns["tensor"] = ([I, I], TypeExpr("Tensor"))
        env.fns["tset"] = ([TypeExpr("Tensor"), I, I, N], TypeExpr("Void"))
        env.fns["tget"] = ([TypeExpr("Tensor"), I, I], N)
        env.fns["tmul"] = ([TypeExpr("Tensor"), TypeExpr("Tensor")], TypeExpr("Tensor"))
        env.fns["tadd"] = ([TypeExpr("Tensor"), TypeExpr("Tensor")], TypeExpr("Tensor"))
        env.fns["relu"] = ([TypeExpr("Tensor")], TypeExpr("Void"))
        env.fns["chan"] = ([I], TypeExpr("Chan"))
        env.fns["send"] = ([TypeExpr("Chan"), I], TypeExpr("Void"))
        env.fns["recv"] = ([TypeExpr("Chan")], I)
        env.fns["assert"] = ([B, T], TypeExpr("Void"))
        env.fns["push"] = ([L, TypeExpr("Any")], TypeExpr("Void"))
        env.fns["get"] = ([L, I], TypeExpr("Any"))
        env.fns["map_new"] = ([], TypeExpr("Map", [T, TypeExpr("Any")]))
        env.fns["map_set"] = ([TypeExpr("Map"), T, TypeExpr("Any")], TypeExpr("Void"))
        env.fns["map_get"] = ([TypeExpr("Map"), T], TypeExpr("Any"))
        env.fns["argc"] = ([], I)
        env.fns["argv"] = ([I], T)
    }

    public func check(_ program: Program) {
        for f in program.forms { env.forms[f.name] = f }
        for k in program.kinds { env.kinds[k.name] = k }
        for o in program.objs { env.objs[o.name] = o }
        for fn in program.fns + program.tests {
            let ps = fn.params.map { $0.type ?? TypeExpr("Any") }
            env.fns[fn.name] = (ps, fn.ret ?? TypeExpr("Void"))
        }
        for k in program.keeps {
            let t = infer(k.2, env: env.vars)
            if let d = k.1, !compatible(d, t) {
                diagnostics.append(Diagnostic(.error, k.3, "keep '\(k.0)' expected \(d.description), found \(t.description)"))
            }
            env.vars[k.0] = k.1 ?? t
        }
        for fn in program.fns + program.tests {
            checkFn(fn)
        }
        for f in program.forms {
            for m in f.methods { checkFn(m, extra: ["self": TypeExpr(f.name)]) }
        }
        for o in program.objs {
            for m in o.methods { checkFn(m, extra: ["self": TypeExpr(o.name)]) }
        }
    }

    private func checkFn(_ fn: FnDecl, extra: [String: TypeExpr] = [:]) {
        var locals = env.vars
        for (k, v) in extra { locals[k] = v }
        for p in fn.params { locals[p.name] = p.type ?? TypeExpr("Any") }
        for s in fn.body { checkStmt(s, locals: &locals, ret: fn.ret ?? TypeExpr("Void")) }
    }

    private func checkStmt(_ s: Stmt, locals: inout [String: TypeExpr], ret: TypeExpr) {
        switch s {
        case .hold(let n, let ty, let e, let p):
            let t = infer(e, env: locals)
            if let ty, !compatible(ty, t) {
                diagnostics.append(Diagnostic(.error, p, "hold '\(n)' expected \(ty.description), found \(t.description)"))
            }
            locals[n] = ty ?? t
        case .keep(let n, let ty, let e, let p):
            let t = infer(e, env: locals)
            if let ty, !compatible(ty, t) {
                diagnostics.append(Diagnostic(.error, p, "keep '\(n)' expected \(ty.description), found \(t.description)"))
            }
            locals[n] = ty ?? t
        case .assign(let t, let e, let p):
            let a = infer(t, env: locals)
            let b = infer(e, env: locals)
            if !compatible(a, b) {
                diagnostics.append(Diagnostic(.warning, p, "assignment types \(a.description) and \(b.description) differ"))
            }
        case .expr(let e):
            _ = infer(e, env: locals)
        case .when(let c, let b, let o, let el, _):
            _ = infer(c, env: locals)
            var l = locals
            for st in b { checkStmt(st, locals: &l, ret: ret) }
            for (oc, ob) in o {
                _ = infer(oc, env: locals)
                var ll = locals
                for st in ob { checkStmt(st, locals: &ll, ret: ret) }
            }
            if let el {
                var ll = locals
                for st in el { checkStmt(st, locals: &ll, ret: ret) }
            }
        case .each(let n, let e, let b, _):
            _ = infer(e, env: locals)
            var l = locals
            l[n] = TypeExpr("Int")
            for st in b { checkStmt(st, locals: &l, ret: ret) }
        case .loopWhile(let c, let b, _):
            _ = infer(c, env: locals)
            var l = locals
            for st in b { checkStmt(st, locals: &l, ret: ret) }
        case .match(let e, let arms, _):
            _ = infer(e, env: locals)
            for arm in arms {
                var l = locals
                for bind in arm.1 { l[bind] = TypeExpr("Any") }
                for st in arm.2 { checkStmt(st, locals: &l, ret: ret) }
            }
        case .give(let e, let p):
            if let e {
                let t = infer(e, env: locals)
                if !compatible(ret, t) && ret.name != "Void" && ret.name != "Any" {
                    diagnostics.append(Diagnostic(.error, p, "give expected \(ret.description), found \(t.description)"))
                }
            }
        case .rise(let e, _): _ = infer(e, env: locals)
        case .rescue(let b, let n, let h, _):
            var l = locals
            for st in b { checkStmt(st, locals: &l, ret: ret) }
            var lh = locals
            lh[n] = TypeExpr("Text")
            for st in h { checkStmt(st, locals: &lh, ret: ret) }
        case .spawn(let b, _):
            var l = locals
            for st in b { checkStmt(st, locals: &l, ret: ret) }
        case .breakS, .continueS: break
        case .show(let args, _):
            for a in args { _ = infer(a, env: locals) }
        }
    }

    public func infer(_ e: Expr, env: [String: TypeExpr]) -> TypeExpr {
        switch e {
        case .int: return TypeExpr("Int")
        case .num: return TypeExpr("Num")
        case .text: return TypeExpr("Text")
        case .bool: return TypeExpr("Bool")
        case .none: return TypeExpr("Opt", [TypeExpr("Any")])
        case .ident(let n, let p):
            if let t = env[n] { return t }
            if self.env.fns[n] != nil { return TypeExpr("Fn") }
            if self.env.forms[n] != nil || self.env.objs[n] != nil || self.env.kinds[n] != nil {
                return TypeExpr(n)
            }
            diagnostics.append(Diagnostic(.error, p, "unknown name '\(n)'", hint: "declare it with hold or keep"))
            return TypeExpr("Any")
        case .binary(let op, let l, let r, _):
            let lt = infer(l, env: env)
            let rt = infer(r, env: env)
            if op == "+" && (lt.name == "Text" || rt.name == "Text") { return TypeExpr("Text") }
            if ["and", "or", "==", "!=", "<", ">", "<=", ">="].contains(op) { return TypeExpr("Bool") }
            if lt.name == "Num" || rt.name == "Num" { return TypeExpr("Num") }
            return TypeExpr("Int")
        case .unary: return TypeExpr("Int")
        case .call(let c, let args, let p):
            for a in args { _ = infer(a, env: env) }
            if case .ident(let n, _) = c, let fn = self.env.fns[n] {
                if fn.params.count != args.count && n != "show" {
                    diagnostics.append(Diagnostic(.error, p, "'\(n)' expects \(fn.params.count) argument(s), got \(args.count)"))
                }
                return fn.ret
            }
            if case .ident(let n, _) = c, self.env.forms[n] != nil { return TypeExpr(n) }
            if case .member(let recv, let m, _) = c {
                _ = infer(recv, env: env)
                if m == "len" { return TypeExpr("Int") }
            }
            return TypeExpr("Any")
        case .index(let a, let i, _):
            _ = infer(i, env: env)
            let t = infer(a, env: env)
            if t.name == "List" { return t.args.first ?? TypeExpr("Any") }
            if t.name == "Text" { return TypeExpr("Text") }
            return TypeExpr("Any")
        case .member(let e, let name, _):
            let t = infer(e, env: env)
            if let f = self.env.forms[t.name]?.fields.first(where: { $0.name == name }) {
                return f.type
            }
            if let f = self.env.objs[t.name]?.fields.first(where: { $0.name == name }) {
                return f.type
            }
            return TypeExpr("Any")
        case .list(let xs, _):
            let inner = xs.first.map { infer($0, env: env) } ?? TypeExpr("Any")
            return TypeExpr("List", [inner])
        case .map: return TypeExpr("Map", [TypeExpr("Text"), TypeExpr("Any")])
        case .construct(let n, let fs, _):
            for f in fs { _ = infer(f.1, env: env) }
            return TypeExpr(n)
        case .closure: return TypeExpr("Fn")
        case .range: return TypeExpr("List", [TypeExpr("Int")])
        }
    }

    private func compatible(_ a: TypeExpr, _ b: TypeExpr) -> Bool {
        if a.name == "Any" || b.name == "Any" { return true }
        if a.name == "Void" { return true }
        if a.name == "Num" && b.name == "Int" { return true }
        return a.name == b.name
    }
}
