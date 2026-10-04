import Foundation

public final class Codegen {
    private var out = ""
    private var tmp = 0
    private var indentN = 0
    private var locals: [String: String] = [:]
    private var forms: [String: FormDecl] = [:]
    private var kinds: [String: KindDecl] = [:]
    private var objs: [String: ObjDecl] = [:]
    private var fnRets: [String: String] = [:]
    private var globalNames: Set<String> = []

    public init() {}

    public func emit(_ programs: [Program]) -> String {
        out = """
        #include "sprfst_rt.h"
        #include <stdlib.h>
        #include <string.h>
        #include <stdio.h>
        #include <stdbool.h>
        #include <stdint.h>
        #include <setjmp.h>

        static jmp_buf spf_err_jmp;
        static SpfText* spf_err_val = NULL;
        static void sprfst_assert(bool c, SpfText* m) { if (!c) spf_panic(spf_text_cstr(m)); }

        """
        for p in programs {
            for f in p.forms { forms[f.name] = f }
            for k in p.kinds { kinds[k.name] = k }
            for o in p.objs { objs[o.name] = o }
            for fn in p.fns { fnRets[fn.name] = cType(fn.ret) }
            for k in p.keeps { globalNames.insert(k.0) }
        }
        for (_, f) in forms { emitForm(f) }
        for (_, k) in kinds { emitKind(k) }
        for (_, o) in objs { emitObj(o) }
        for p in programs {
            for fn in p.fns { emitFnProto(fn) }
        }
        emitLine("")
        for p in programs {
            for k in p.keeps {
                let ct = cType(k.1)
                emitLine("static \(ct) g_\(sanitize(k.0));")
            }
        }
        for p in programs {
            for fn in p.fns { emitFn(fn, globals: p.keeps) }
            for f in p.forms { for m in f.methods { emitMethod(f.name, m) } }
            for o in p.objs { for m in o.methods { emitMethod(o.name, m) } }
        }
        emitMain(programs)
        return out
    }

    private func emitForm(_ f: FormDecl) {
        emitLine("typedef struct {")
        indentN += 1
        for field in f.fields {
            emitLine("\(cType(field.type)) \(sanitize(field.name));")
        }
        if f.fields.isEmpty { emitLine("int _pad;") }
        indentN -= 1
        emitLine("} form_\(sanitize(f.name));")
        let args = f.fields.enumerated().map { "\(cType($0.element.type)) a\($0.offset)" }.joined(separator: ", ")
        emitLine("static form_\(sanitize(f.name))* \(sanitize(f.name))_new(\(args.isEmpty ? "void" : args)) {")
        indentN += 1
        emitLine("form_\(sanitize(f.name))* o = (form_\(sanitize(f.name))*)calloc(1, sizeof(*o));")
        for (i, field) in f.fields.enumerated() {
            emitLine("o->\(sanitize(field.name)) = a\(i);")
        }
        emitLine("return o;")
        indentN -= 1
        emitLine("}")
    }

    private func emitKind(_ k: KindDecl) {
        emitLine("typedef struct { int tag; int64_t a; int64_t b; void* p; } kind_\(sanitize(k.name));")
        for (i, v) in k.variants.enumerated() {
            emitLine("#define KIND_\(sanitize(k.name))_\(sanitize(v.name)) \(i)")
        }
    }

    private func emitObj(_ o: ObjDecl) {
        emitLine("typedef struct {")
        indentN += 1
        for field in o.fields {
            emitLine("\(cType(field.type)) \(sanitize(field.name));")
        }
        if o.fields.isEmpty { emitLine("int _pad;") }
        indentN -= 1
        emitLine("} obj_\(sanitize(o.name));")
        emitLine("static obj_\(sanitize(o.name))* \(sanitize(o.name))_new(void) {")
        indentN += 1
        emitLine("return (obj_\(sanitize(o.name))*)calloc(1, sizeof(obj_\(sanitize(o.name))));")
        indentN -= 1
        emitLine("}")
    }

    private func emitFnProto(_ fn: FnDecl) {
        if fn.name == "main" { return }
        let args = fn.params.map { "\(cType($0.type)) \(sanitize($0.name))" }.joined(separator: ", ")
        emitLine("static \(cType(fn.ret)) \(sanitize(fn.name))(\(args.isEmpty ? "void" : args));")
    }

    private func emitFn(_ fn: FnDecl, globals: [(String, TypeExpr?, Expr, SourcePos)]) {
        locals = [:]
        for g in globals { locals[g.0] = cType(g.1) }
        for p in fn.params { locals[p.name] = cType(p.type) }
        if fn.name == "main" {
            emitLine("static int sprfst_user_main(void) {")
        } else {
            let args = fn.params.map { "\(cType($0.type)) \(sanitize($0.name))" }.joined(separator: ", ")
            emitLine("static \(cType(fn.ret)) \(sanitize(fn.name))(\(args.isEmpty ? "void" : args)) {")
        }
        indentN += 1
        for st in fn.body { emitStmt(st) }
        if fn.name == "main" { emitLine("return 0;") }
        else if cType(fn.ret) == "int64_t" { emitLine("return 0;") }
        else if cType(fn.ret) == "double" { emitLine("return 0.0;") }
        else if cType(fn.ret) == "bool" { emitLine("return false;") }
        else if cType(fn.ret) != "void" { emitLine("return NULL;") }
        indentN -= 1
        emitLine("}")
    }

    private func emitMethod(_ typeName: String, _ fn: FnDecl) {
        locals = ["self": "void*"]
        for p in fn.params { locals[p.name] = cType(p.type) }
        var args = ["void* self"]
        args.append(contentsOf: fn.params.filter { $0.name != "self" }.map { "\(cType($0.type)) \(sanitize($0.name))" })
        emitLine("static \(cType(fn.ret)) \(sanitize(typeName))_\(sanitize(fn.name))(\(args.joined(separator: ", "))) {")
        indentN += 1
        emitLine("form_\(sanitize(typeName))* typed_self = (form_\(sanitize(typeName))*)self;")
        locals["self"] = "form_\(sanitize(typeName))*"
        for st in fn.body { emitStmt(st) }
        if cType(fn.ret) == "int64_t" { emitLine("return 0;") }
        else if cType(fn.ret) == "double" { emitLine("return 0.0;") }
        else if cType(fn.ret) == "bool" { emitLine("return false;") }
        else if cType(fn.ret) != "void" { emitLine("return NULL;") }
        indentN -= 1
        emitLine("}")
    }

    private func emitMain(_ programs: [Program]) {
        emitLine("int main(int argc, char** argv) {")
        indentN += 1
        emitLine("spf_init(argc, argv);")
        for p in programs {
            for k in p.keeps {
                let (c, t) = emitExpr(k.2)
                emitLine("g_\(sanitize(k.0)) = (\(cType(k.1)))(\(c));")
                locals[k.0] = t
            }
        }
        emitLine("int rc = sprfst_user_main();")
        emitLine("spf_shutdown();")
        emitLine("return rc;")
        indentN -= 1
        emitLine("}")
    }

    private func emitStmt(_ s: Stmt) {
        switch s {
        case .hold(let n, let ty, let e, _):
            let (c, t) = emitExpr(e)
            let ct = ty != nil ? cType(ty) : t
            emitLine("\(ct) \(sanitize(n)) = (\(ct))(\(c));")
            locals[n] = ct
        case .keep(let n, let ty, let e, _):
            let (c, t) = emitExpr(e)
            let ct = ty != nil ? cType(ty) : t
            emitLine("const \(ct) \(sanitize(n)) = (\(ct))(\(c));")
            locals[n] = ct
        case .assign(let target, let e, _):
            let (c, _) = emitExpr(e)
            switch target {
            case .ident(let n, _):
                emitLine("\(sanitize(n)) = \(c);")
            case .member(let recv, let field, _):
                let (rc, _) = emitExpr(recv)
                emitLine("\(rc)->\(sanitize(field)) = \(c);")
            case .index(let a, let i, _):
                let (ac, _) = emitExpr(a)
                let (ic, _) = emitExpr(i)
                emitLine("spf_list_set_int(\(ac), \(ic), (int64_t)(\(c)));")
            default:
                emitLine("/* unsupported assign */;")
            }
        case .expr(let e):
            let (c, _) = emitExpr(e)
            emitLine("(void)(\(c));")
        case .when(let cnd, let body, let orws, let el, _):
            let (c, _) = emitExpr(cnd)
            emitLine("if (\(asBool(c))) {")
            indentN += 1
            body.forEach(emitStmt)
            indentN -= 1
            emitLine("}")
            for (oc, ob) in orws {
                let (cc, _) = emitExpr(oc)
                emitLine("else if (\(asBool(cc))) {")
                indentN += 1
                ob.forEach(emitStmt)
                indentN -= 1
                emitLine("}")
            }
            if let el {
                emitLine("else {")
                indentN += 1
                el.forEach(emitStmt)
                indentN -= 1
                emitLine("}")
            }
        case .each(let n, let e, let body, _):
            switch e {
            case .range(let a, let b, let inc, _):
                let (ca, _) = emitExpr(a)
                let (cb, _) = emitExpr(b)
                let nm = sanitize(n)
                emitLine("for (int64_t \(nm) = \(ca); \(nm) \(inc ? "<=" : "<") \(cb); \(nm)++) {")
                locals[n] = "int64_t"
                indentN += 1
                body.forEach(emitStmt)
                indentN -= 1
                emitLine("}")
            default:
                let (ce, _) = emitExpr(e)
                let tmpL = fresh("lst")
                let nm = sanitize(n)
                emitLine("SpfList* \(tmpL) = \(ce);")
                emitLine("for (int64_t \(nm)_i = 0; \(nm)_i < spf_list_len(\(tmpL)); \(nm)_i++) {")
                indentN += 1
                emitLine("int64_t \(nm) = spf_list_get_int(\(tmpL), \(nm)_i);")
                locals[n] = "int64_t"
                body.forEach(emitStmt)
                indentN -= 1
                emitLine("}")
            }
        case .loopWhile(let cnd, let body, _):
            let (c, _) = emitExpr(cnd)
            emitLine("while (\(asBool(c))) {")
            indentN += 1
            body.forEach(emitStmt)
            indentN -= 1
            emitLine("}")
        case .match(let e, let arms, _):
            let (ce, _) = emitExpr(e)
            let tag = fresh("tag")
            emitLine("int \(tag) = (\(ce))->tag;")
            emitLine("switch (\(tag)) {")
            for (i, arm) in arms.enumerated() {
                if arm.0 == "_" {
                    emitLine("default: {")
                } else {
                    let parts = arm.0.split(separator: ".").map(String.init)
                    if parts.count == 2 {
                        emitLine("case KIND_\(sanitize(parts[0]))_\(sanitize(parts[1])): {")
                    } else {
                        emitLine("case \(i): {")
                    }
                }
                indentN += 1
                for (bi, b) in arm.1.enumerated() {
                    let field = bi == 0 ? "a" : (bi == 1 ? "b" : "a")
                    emitLine("int64_t \(sanitize(b)) = (\(ce))->\(field);")
                    locals[b] = "int64_t"
                }
                arm.2.forEach(emitStmt)
                emitLine("break;")
                indentN -= 1
                emitLine("}")
            }
            emitLine("}")
        case .give(let e, _):
            if let e {
                let (c, _) = emitExpr(e)
                emitLine("return \(c);")
            } else {
                emitLine("return 0;")
            }
        case .rise(let e, _):
            let (c, t) = emitExpr(e)
            if t.contains("SpfText") {
                emitLine("spf_err_val = \(c); longjmp(spf_err_jmp, 1);")
            } else {
                emitLine("spf_err_val = spf_text_from_cstr(\"error\"); longjmp(spf_err_jmp, 1);")
            }
        case .rescue(let body, let n, let handler, _):
            emitLine("if (setjmp(spf_err_jmp) == 0) {")
            indentN += 1
            body.forEach(emitStmt)
            indentN -= 1
            emitLine("} else {")
            indentN += 1
            emitLine("SpfText* \(sanitize(n)) = spf_err_val;")
            locals[n] = "SpfText*"
            handler.forEach(emitStmt)
            indentN -= 1
            emitLine("}")
        case .spawn(let body, _):
            emitLine("{")
            indentN += 1
            body.forEach(emitStmt)
            indentN -= 1
            emitLine("}")
        case .breakS: emitLine("break;")
        case .continueS: emitLine("continue;")
        case .show(let args, _):
            for a in args {
                let (c, t) = emitExpr(a)
                emitShow(c, t)
            }
            emitLine("spf_newline();")
        }
    }

    private func emitShow(_ c: String, _ t: String) {
        if t == "int64_t" { emitLine("spf_show_int(\(c));") }
        else if t == "double" { emitLine("spf_show_num(\(c));") }
        else if t == "bool" { emitLine("spf_show_bool(\(c));") }
        else if t.contains("SpfText") { emitLine("spf_show_text(\(c));") }
        else { emitLine("spf_show_cstr(\"<value>\");") }
    }

    private func emitExpr(_ e: Expr) -> (String, String) {
        switch e {
        case .int(let v, _): return ("INT64_C(\(v))", "int64_t")
        case .num(let v, _): return ("\(v)", "double")
        case .text(let s, _):
            let esc = escapeC(s)
            return ("spf_text_from_cstr(\"\(esc)\")", "SpfText*")
        case .bool(let v, _): return (v ? "true" : "false", "bool")
        case .none: return ("NULL", "void*")
        case .ident(let n, _):
            if globalNames.contains(n) {
                return ("g_\(sanitize(n))", locals[n] ?? "int64_t")
            }
            if let t = locals[n] {
                if n == "self" { return ("typed_self", t) }
                return (sanitize(n), t)
            }
            if forms[n] != nil { return (sanitize(n) + "_new", "fn") }
            return (sanitize(n), "int64_t")
        case .binary(let op, let l, let r, _):
            let (lc, lt) = emitExpr(l)
            let (rc, rt) = emitExpr(r)
            if op == "+" && (lt.contains("SpfText") || rt.contains("SpfText")) {
                let a = lt.contains("SpfText") ? lc : "spf_text_from_cstr(\"\")"
                let b = rt.contains("SpfText") ? rc : "spf_text_from_int((int64_t)(\(rc)))"
                if !lt.contains("SpfText") {
                    return ("spf_text_concat(spf_text_from_int((int64_t)(\(lc))), \(rt.contains("SpfText") ? rc : "spf_text_from_int((int64_t)(\(rc)))"))", "SpfText*")
                }
                if !rt.contains("SpfText") {
                    let conv = rt == "double" ? "spf_text_from_num(\(rc))" : "spf_text_from_int((int64_t)(\(rc)))"
                    return ("spf_text_concat(\(lc), \(conv))", "SpfText*")
                }
                return ("spf_text_concat(\(a), \(b))", "SpfText*")
            }
            let cop = ["and": "&&", "or": "||"][op] ?? op
            let ty: String
            if ["==", "!=", "<", ">", "<=", ">=", "&&", "||", "and", "or"].contains(op) { ty = "bool" }
            else if lt == "double" || rt == "double" { ty = "double" }
            else { ty = "int64_t" }
            return ("(\(lc) \(cop) \(rc))", ty)
        case .unary(let op, let x, _):
            let (c, t) = emitExpr(x)
            if op == "!" { return ("!(\(asBool(c)))", "bool") }
            return ("(-(\(c)))", t)
        case .call(let callee, let args, _):
            return emitCall(callee, args)
        case .index(let a, let i, _):
            let (ac, at) = emitExpr(a)
            let (ic, _) = emitExpr(i)
            if at.contains("SpfText") {
                return ("spf_text_slice(\(ac), \(ic), (\(ic))+1)", "SpfText*")
            }
            return ("spf_list_get_int(\(ac), \(ic))", "int64_t")
        case .member(let recv, let name, _):
            if case .ident(let tn, _) = recv, let kind = kinds[tn] {
                // Color.Red
                if let idx = kind.variants.firstIndex(where: { $0.name == name }) {
                    let v = fresh("k")
                    emitLine("kind_\(sanitize(tn))* \(v) = (kind_\(sanitize(tn))*)calloc(1, sizeof(*\(v)));")
                    emitLine("\(v)->tag = \(idx);")
                    return (v, "kind_\(sanitize(tn))*")
                }
            }
            let (rc, rt) = emitExpr(recv)
            if name == "len" {
                if rt.contains("SpfText") { return ("spf_text_len(\(rc))", "int64_t") }
                if rt.contains("SpfList") { return ("spf_list_len(\(rc))", "int64_t") }
            }
            if rt.hasPrefix("form_") || rt.hasPrefix("obj_") || rt.hasSuffix("*") {
                return ("(\(rc)->\(sanitize(name)))", fieldCType(rt, name))
            }
            return ("0", "int64_t")
        case .list(let xs, _):
            let v = fresh("list")
            emitLine("SpfList* \(v) = spf_list_new();")
            for x in xs {
                let (c, t) = emitExpr(x)
                if t.contains("SpfText") || t.contains("*") && t != "int64_t" && t != "double" && t != "bool" {
                    emitLine("spf_list_push_ptr(\(v), \(c));")
                } else if t == "double" {
                    emitLine("spf_list_push_num(\(v), \(c));")
                } else if t == "bool" {
                    emitLine("spf_list_push_bool(\(v), \(c));")
                } else {
                    emitLine("spf_list_push_int(\(v), (int64_t)(\(c)));")
                }
            }
            return (v, "SpfList*")
        case .map(let pairs, _):
            let v = fresh("map")
            emitLine("SpfMap* \(v) = spf_map_new();")
            for (k, val) in pairs {
                let (kc, _) = emitExpr(k)
                let (vc, _) = emitExpr(val)
                emitLine("spf_map_set_ptr(\(v), \(kc), (void*)(intptr_t)(\(vc)));")
            }
            return (v, "SpfMap*")
        case .construct(let n, let fields, _):
            if let form = forms[n] {
                var ordered: [String] = []
                for f in form.fields {
                    if let pair = fields.first(where: { $0.0 == f.name }) {
                        let (c, _) = emitExpr(pair.1)
                        ordered.append(c)
                    } else {
                        ordered.append(zero(cType(f.type)))
                    }
                }
                return ("\(sanitize(n))_new(\(ordered.joined(separator: ", ")))", "form_\(sanitize(n))*")
            }
            if objs[n] != nil {
                let v = fresh("obj")
                emitLine("obj_\(sanitize(n))* \(v) = \(sanitize(n))_new();")
                for (fn, fe) in fields {
                    let (c, _) = emitExpr(fe)
                    emitLine("\(v)->\(sanitize(fn)) = \(c);")
                }
                return (v, "obj_\(sanitize(n))*")
            }
            return ("NULL", "void*")
        case .closure:
            return ("NULL", "void*")
        case .range(let a, let b, _, _):
            let (ca, _) = emitExpr(a)
            let (cb, _) = emitExpr(b)
            let v = fresh("rng")
            emitLine("SpfList* \(v) = spf_list_new();")
            emitLine("for (int64_t i_ = \(ca); i_ < \(cb); i_++) spf_list_push_int(\(v), i_);")
            return (v, "SpfList*")
        }
    }

    private func emitCall(_ callee: Expr, _ args: [Expr]) -> (String, String) {
        var cargs: [(String, String)] = []
        for a in args { cargs.append(emitExpr(a)) }
        func join() -> String { cargs.map(\.0).joined(separator: ", ") }

        if case .ident(let n, _) = callee {
            switch n {
            case "len":
                let t = cargs[0].1
                if t.contains("SpfText") { return ("spf_text_len(\(cargs[0].0))", "int64_t") }
                return ("spf_list_len(\(cargs[0].0))", "int64_t")
            case "sqrt": return ("spf_sqrt((double)(\(cargs[0].0)))", "double")
            case "pow": return ("spf_pow((double)(\(cargs[0].0)), (double)(\(cargs[1].0)))", "double")
            case "sin": return ("spf_sin((double)(\(cargs[0].0)))", "double")
            case "cos": return ("spf_cos((double)(\(cargs[0].0)))", "double")
            case "abs": return ("spf_abs((double)(\(cargs[0].0)))", "double")
            case "iabs": return ("spf_iabs(\(cargs[0].0))", "int64_t")
            case "min": return ("spf_min_i(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "max": return ("spf_max_i(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "now": return ("spf_now_ms()", "int64_t")
            case "clock": return ("spf_clock()", "double")
            case "sleep": return ("(spf_sleep_ms(\(cargs[0].0)), 0)", "int64_t")
            case "rand": return ("spf_rand_int(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "read": return ("spf_fs_read(\(cargs[0].0))", "SpfText*")
            case "write": return ("spf_fs_write(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "exists": return ("spf_fs_exists(\(cargs[0].0))", "bool")
            case "mkdir": return ("spf_fs_mkdir(\(cargs[0].0))", "bool")
            case "listdir": return ("spf_fs_list(\(cargs[0].0))", "SpfList*")
            case "remove": return ("spf_fs_remove(\(cargs[0].0))", "bool")
            case "http_get": return ("spf_http_get(\(cargs[0].0))", "SpfText*")
            case "tcp_send": return ("spf_net_tcp_send(\(cargs[0].0), \(cargs[1].0), \(cargs[2].0))", "SpfText*")
            case "db_open": return ("spf_db_open(\(cargs[0].0))", "int64_t")
            case "db_exec": return ("spf_db_exec(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "db_close": return ("(spf_db_close(\(cargs[0].0)), 0)", "int64_t")
            case "upper": return ("spf_text_upper(\(cargs[0].0))", "SpfText*")
            case "lower": return ("spf_text_lower(\(cargs[0].0))", "SpfText*")
            case "trim": return ("spf_text_trim(\(cargs[0].0))", "SpfText*")
            case "contains": return ("spf_text_contains(\(cargs[0].0), \(cargs[1].0))", "bool")
            case "split": return ("spf_text_split(\(cargs[0].0), \(cargs[1].0))", "SpfList*")
            case "text":
                let t = cargs[0].1
                if t.contains("SpfText") { return (cargs[0].0, "SpfText*") }
                if t == "double" { return ("spf_text_from_num(\(cargs[0].0))", "SpfText*") }
                return ("spf_text_from_int((int64_t)(\(cargs[0].0)))", "SpfText*")
            case "int":
                if cargs[0].1.contains("SpfText") { return ("spf_text_to_int(\(cargs[0].0))", "int64_t") }
                return ("((int64_t)(\(cargs[0].0)))", "int64_t")
            case "num":
                if cargs[0].1.contains("SpfText") { return ("spf_text_to_num(\(cargs[0].0))", "double") }
                return ("((double)(\(cargs[0].0)))", "double")
            case "gui_window": return ("spf_gui_window(\(join()))", "int64_t")
            case "gui_label": return ("(spf_gui_label(\(join())), 0)", "int64_t")
            case "gui_button": return ("spf_gui_button(\(join()))", "int64_t")
            case "gui_run": return ("(spf_gui_run(\(cargs[0].0)), 0)", "int64_t")
            case "tensor": return ("spf_tensor_new(\(cargs[0].0), \(cargs[1].0))", "SpfTensor*")
            case "tset": return ("(spf_tensor_set(\(join())), 0)", "int64_t")
            case "tget": return ("spf_tensor_get(\(join()))", "double")
            case "tmul": return ("spf_tensor_mul(\(cargs[0].0), \(cargs[1].0))", "SpfTensor*")
            case "tadd": return ("spf_tensor_add(\(cargs[0].0), \(cargs[1].0))", "SpfTensor*")
            case "relu": return ("(spf_tensor_relu(\(cargs[0].0)), 0)", "int64_t")
            case "chan": return ("spf_chan_new(\(cargs[0].0))", "SpfChan*")
            case "send": return ("(spf_chan_send_int(\(cargs[0].0), \(cargs[1].0)), 0)", "int64_t")
            case "recv": return ("spf_chan_recv_int(\(cargs[0].0))", "int64_t")
            case "assert":
                let msg = cargs.count > 1 ? cargs[1].0 : "spf_text_from_cstr(\"assert\")"
                return ("(sprfst_assert(\(asBool(cargs[0].0)), \(msg)), 0)", "int64_t")
            case "push":
                emitLine("spf_list_push_int(\(cargs[0].0), (int64_t)(\(cargs[1].0)));")
                return ("0", "int64_t")
            case "get": return ("spf_list_get_int(\(cargs[0].0), \(cargs[1].0))", "int64_t")
            case "map_new": return ("spf_map_new()", "SpfMap*")
            case "map_set": return ("(spf_map_set_ptr(\(cargs[0].0), \(cargs[1].0), (void*)(intptr_t)(\(cargs[2].0))), 0)", "int64_t")
            case "map_get": return ("((int64_t)(intptr_t)spf_map_get_ptr(\(cargs[0].0), \(cargs[1].0)))", "int64_t")
            case "argc": return ("spf_argc()", "int64_t")
            case "argv": return ("spf_argv(\(cargs[0].0))", "SpfText*")
            default:
                if forms[n] != nil {
                    return ("\(sanitize(n))_new(\(join()))", "form_\(sanitize(n))*")
                }
                let rt = fnRets[n] ?? "int64_t"
                return ("\(sanitize(n))(\(join()))", rt)
            }
        }
        if case .member(let recv, let name, _) = callee {
            let (rc, rt) = emitExpr(recv)
            var typeName = rt
            typeName = typeName.replacingOccurrences(of: "form_", with: "").replacingOccurrences(of: "obj_", with: "").replacingOccurrences(of: "*", with: "")
            let rest = cargs.map(\.0)
            let all = ([rc] + rest).joined(separator: ", ")
            return ("\(sanitize(typeName))_\(sanitize(name))(\(all))", fnRets[name] ?? "int64_t")
        }
        return ("0", "int64_t")
    }

    private func fieldCType(_ recvTy: String, _ name: String) -> String {
        let tn = recvTy.replacingOccurrences(of: "form_", with: "").replacingOccurrences(of: "obj_", with: "").replacingOccurrences(of: "*", with: "")
        if let f = forms[tn]?.fields.first(where: { $0.name == name }) { return cType(f.type) }
        if let f = objs[tn]?.fields.first(where: { $0.name == name }) { return cType(f.type) }
        return "int64_t"
    }

    private func cType(_ t: TypeExpr?) -> String {
        guard let t else { return "int64_t" }
        switch t.name {
        case "Int", "Byte": return "int64_t"
        case "Num": return "double"
        case "Bool": return "bool"
        case "Text": return "SpfText*"
        case "List": return "SpfList*"
        case "Map": return "SpfMap*"
        case "Set": return "SpfSet*"
        case "Chan": return "SpfChan*"
        case "Tensor": return "SpfTensor*"
        case "Void": return "void"
        case "Any": return "void*"
        default:
            if forms[t.name] != nil { return "form_\(sanitize(t.name))*" }
            if objs[t.name] != nil { return "obj_\(sanitize(t.name))*" }
            if kinds[t.name] != nil { return "kind_\(sanitize(t.name))*" }
            return "int64_t"
        }
    }

    private func zero(_ t: String) -> String {
        if t == "double" { return "0.0" }
        if t == "bool" { return "false" }
        if t.contains("*") { return "NULL" }
        return "0"
    }

    private func asBool(_ c: String) -> String { "(\(c))" }
    private func fresh(_ p: String) -> String { tmp += 1; return "_\(p)\(tmp)" }
    private func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "-", with: "_")
    }
    private func escapeC(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
    private func emitLine(_ s: String) {
        out += String(repeating: "  ", count: indentN) + s + "\n"
    }
}
