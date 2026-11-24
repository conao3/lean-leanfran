package verify

import (
	"fmt"
	"go/ast"
	"go/constant"
	"go/token"
	"go/types"
)

func (t *translation) block(stmts []ast.Stmt) {
	before := t.body.Len()
	for _, s := range stmts {
		t.statement(s)
	}
	if t.body.Len() == before {
		t.line("pure ()")
	}
}

func (t *translation) statement(stmt ast.Stmt) {
	info := t.model.Info
	switch s := stmt.(type) {
	case *ast.EmptyStmt:
		return
	case *ast.BlockStmt:
		t.line("do")
		t.depth++
		t.block(s.List)
		t.depth--
	case *ast.ReturnStmt:
		t.returnStmt(s)
	case *ast.AssignStmt:
		t.assign(s)
	case *ast.IncDecStmt:
		name, obj := t.target(s.X)
		op := "+"
		if s.Tok == token.DEC {
			op = "-"
		}
		if b := basic(obj.Type()); b == nil || b.Info()&types.IsInteger == 0 {
			t.reject(s, "increment/decrement requires an integer")
		}
		t.line("%s := %s %s 1", name, name, op)
	case *ast.DeclStmt:
		decl, ok := s.Decl.(*ast.GenDecl)
		if !ok || decl.Tok != token.VAR && decl.Tok != token.CONST {
			t.reject(s, "unsupported local declaration")
		}
		if decl.Tok == token.CONST {
			return
		}
		for _, spec := range decl.Specs {
			v := spec.(*ast.ValueSpec)
			lhs := make([]ast.Expr, len(v.Names))
			for i, id := range v.Names {
				lhs[i] = id
			}
			if len(v.Values) == 0 {
				for _, id := range v.Names {
					if id.Name == "_" {
						continue
					}
					obj := info.Defs[id]
					_, t.fresh[obj] = obj.Type().Underlying().(*types.Slice)
					t.line("let mut %s : %s := %s", t.variable(obj), t.leanType(id, obj.Type()), t.zero(id, obj.Type()))
				}
			} else {
				t.assign(&ast.AssignStmt{Lhs: lhs, Tok: token.DEFINE, Rhs: v.Values})
			}
		}
	case *ast.IfStmt:
		if s.Init != nil {
			t.statement(s.Init)
		}
		t.line("if %s then", t.value(s.Cond, nil))
		t.depth++
		t.block(s.Body.List)
		t.depth--
		if s.Else != nil {
			t.line("else")
			t.depth++
			if b, ok := s.Else.(*ast.BlockStmt); ok {
				t.block(b.List)
			} else {
				t.statement(s.Else)
			}
			t.depth--
		}
	case *ast.ForStmt:
		if s.Init != nil {
			t.statement(s.Init)
		}
		t.def.Fallible = true
		first := t.next()
		if s.Post != nil {
			t.line("let mut %s := true", first)
		}
		t.line("for _ in Go.Loop.forever do")
		t.depth++
		if s.Post != nil {
			t.line("if %s then", first)
			t.depth++
			t.line("%s := false", first)
			t.depth--
			t.line("else")
			t.depth++
			t.statement(s.Post)
			t.depth--
		}
		if s.Cond != nil {
			t.line("unless %s do break", t.value(s.Cond, nil))
		}
		t.block(s.Body.List)
		t.depth--
	case *ast.RangeStmt:
		t.rangeStmt(s)
	case *ast.SwitchStmt:
		t.switchStmt(s)
	case *ast.BranchStmt:
		if s.Label != nil || s.Tok != token.BREAK && s.Tok != token.CONTINUE {
			t.reject(s, "unsupported branch %s", s.Tok)
		}

		t.line("%s", s.Tok)
	case *ast.ExprStmt:
		call, ok := s.X.(*ast.CallExpr)
		if !ok {
			t.reject(s, "unsupported expression statement")
		}
		if id, ok := call.Fun.(*ast.Ident); ok && info.Uses[id] == types.Universe.Lookup("panic") {
			arg := t.next()
			t.line("let %s := %s", arg, t.value(call.Args[0], nil))
			t.line("return %s", t.action("throw", "Go.Exc.panic"))
		} else {
			t.line("let _ := %s", t.call(call, false))
		}
	default:
		t.reject(stmt, "unsupported Go statement %T", stmt)
	}
}

func (t *translation) zero(node ast.Node, typ types.Type) string {
	if desc, ok := t.namedType(typ); ok && desc.ZeroCase != "" {
		return leanName(desc.Lean) + "." + leanName(desc.ZeroCase)
	}
	if _, ok := typ.Underlying().(*types.Struct); ok {
		return t.structure(node, typ, nil)
	}
	name := t.leanType(node, typ)
	switch name {
	case "Bool":
		return "false"
	case "String":
		return `""`
	case "Float":
		return "(Float.ofBits 0)"
	default:
		if _, ok := typ.Underlying().(*types.Slice); ok {
			return "#[]"
		}
		return "(0 : " + name + ")"
	}
}

func (t *translation) target(expr ast.Expr) (string, types.Object) {
	id, ok := ast.Unparen(expr).(*ast.Ident)
	if !ok {
		t.reject(expr, "unsupported assignment target")
	}
	obj := t.model.Info.Uses[id]
	if name := t.locals[obj]; name != "" {
		return name, obj
	}
	t.reject(expr, "assignment to nonlocal variable %s", id.Name)
	return "", nil
}

func (t *translation) assignmentValue(x ast.Expr, typ types.Type) string {
	if call, ok := ast.Unparen(x).(*ast.CallExpr); ok {
		if id, ok := call.Fun.(*ast.Ident); ok && t.model.Info.Uses[id] == types.Universe.Lookup("append") {
			t.reject(x, "append must update a uniquely owned local slice")
		}
	}
	return t.value(x, typ)
}

func (t *translation) assign(s *ast.AssignStmt) {
	info := t.model.Info
	if len(s.Lhs) == 1 && len(s.Rhs) == 1 && s.Tok == token.ASSIGN {
		if index, ok := s.Lhs[0].(*ast.IndexExpr); ok {
			name, obj := t.target(index.X)
			t.checkOwned(index, obj)
			idx := t.toInt(index.Index)
			val := t.value(s.Rhs[0], info.TypeOf(index))
			t.line("%s := %s", name, t.action("Go.setIndex", name, idx, val))
			return
		}
		if call, ok := ast.Unparen(s.Rhs[0]).(*ast.CallExpr); ok {
			id, ok := call.Fun.(*ast.Ident)
			if ok && info.Uses[id] == types.Universe.Lookup("append") {
				name, obj := t.target(s.Lhs[0])
				t.checkOwned(call, obj)
				a, ok := ast.Unparen(call.Args[0]).(*ast.Ident)
				if !ok || info.Uses[a] != obj {
					t.reject(call, "append must update its own slice")
				}
				typ := obj.Type().Underlying().(*types.Slice).Elem()
				out := name
				if call.Ellipsis.IsValid() {
					out = "(" + name + " ++ " + t.value(call.Args[1], obj.Type()) + ")"
				} else {
					for _, arg := range call.Args[1:] {
						out = apply("Array.push", out, t.value(arg, typ))
					}
				}
				t.line("%s := %s", name, out)
				return
			}
		}
	}
	if s.Tok != token.ASSIGN && s.Tok != token.DEFINE {
		op, ok := map[token.Token]token.Token{token.ADD_ASSIGN: token.ADD, token.SUB_ASSIGN: token.SUB, token.MUL_ASSIGN: token.MUL}[s.Tok]
		if !ok {
			t.reject(s, "unsupported compound assignment %s", s.Tok)
		}
		name, obj := t.target(s.Lhs[0])
		typ := obj.Type()
		value := t.value(s.Rhs[0], typ)
		t.line("%s := %s", name, t.binary(s, op, name, value, typ, typ))
		return
	}
	var vals []string
	if len(s.Rhs) == 1 && len(s.Lhs) > 1 {
		typ, ok := info.TypeOf(s.Rhs[0]).(*types.Tuple)
		if !ok || typ.Len() != len(s.Lhs) {
			t.reject(s, "multiple assignment requires matching values")
		}
		rhs := t.value(s.Rhs[0], nil)
		for range s.Lhs {
			vals = append(vals, t.next())
		}
		t.line("let %s := %s", tuple(vals), rhs)
	} else {
		for i, rhs := range s.Rhs {
			var typ types.Type
			if id, ok := s.Lhs[i].(*ast.Ident); ok && info.Defs[id] != nil {
				typ = info.Defs[id].Type()
			} else {
				typ = info.TypeOf(s.Lhs[i])
				if id, ok := s.Lhs[i].(*ast.Ident); ok && id.Name == "_" {
					typ = nil
				}
			}
			val := t.next()
			t.line("let %s := %s", val, t.assignmentValue(rhs, typ))
			vals = append(vals, val)
		}
	}
	for i, lhs := range s.Lhs {
		id, ok := lhs.(*ast.Ident)
		if !ok {
			t.reject(lhs, "multi-assignment requires variable targets")
		}
		if id.Name == "_" {
			continue
		}
		if obj := info.Defs[id]; s.Tok == token.DEFINE && obj != nil {
			if i < len(s.Rhs) {
				_, t.fresh[obj] = ast.Unparen(s.Rhs[i]).(*ast.CompositeLit)
			}
			t.line("let mut %s : %s := %s", t.variable(obj), t.leanType(id, obj.Type()), vals[i])
		} else {
			name, _ := t.target(lhs)
			t.line("%s := %s", name, vals[i])
		}
	}
}

func (t *translation) checkOwned(node ast.Node, obj types.Object) {
	st, ok := obj.Type().Underlying().(*types.Slice)
	if !ok || basic(st.Elem()) == nil || !t.fresh[obj] {
		t.reject(node, "slice writes require a uniquely owned local slice literal of scalar elements")
	}
	info := t.model.Info
	var stack []ast.Node
	ast.Inspect(t.model.Decl.Body, func(n ast.Node) bool {
		if n == nil {
			stack = stack[:len(stack)-1]
			return false
		}
		if id, ok := n.(*ast.Ident); ok && info.Uses[id] == obj {
			var parent ast.Node
			if len(stack) > 0 {
				parent = stack[len(stack)-1]
			}
			allowed := false
			switch use := parent.(type) {
			case *ast.IndexExpr:
				allowed = use.X == id
			case *ast.ReturnStmt:
				allowed = true
			case *ast.CallExpr:
				if builtin, ok := use.Fun.(*ast.Ident); ok && len(use.Args) > 0 && use.Args[0] == id {
					callee := info.Uses[builtin]
					allowed = callee == types.Universe.Lookup("len") || callee == types.Universe.Lookup("append")
				}
			case *ast.AssignStmt:
				for _, lhs := range use.Lhs {
					if lhs == id && len(use.Lhs) == 1 && len(use.Rhs) == 1 {
						_, lit := ast.Unparen(use.Rhs[0]).(*ast.CompositeLit)
						c, call := ast.Unparen(use.Rhs[0]).(*ast.CallExpr)
						if call {
							f, builtin := c.Fun.(*ast.Ident)
							call = builtin && info.Uses[f] == types.Universe.Lookup("append")
						}
						allowed = lit || call
					}
				}
			}
			if !allowed {
				t.reject(id, "write to a slice used outside an unaliased local expression")
			}
		}
		stack = append(stack, n)
		return true
	})
}

func (t *translation) returnStmt(s *ast.ReturnStmt) {
	info := t.model.Info
	if len(s.Results) == 1 && t.result.Len() > 1 {
		call, ok := ast.Unparen(s.Results[0]).(*ast.CallExpr)
		if !ok {
			t.reject(s, "expected a multi-result call")
		}
		t.line("return %s", t.call(call, t.def.errorPair))
		return
	}
	var values []string
	if len(s.Results) == 0 && t.result.Len() > 0 {
		for i := range t.result.Len() {
			values = append(values, t.variable(t.result.At(i)))
		}
	}
	for i, value := range s.Results {
		if t.def.errorPair && i == 1 {
			if id, ok := ast.Unparen(value).(*ast.Ident); ok && info.Uses[id] == types.Universe.Lookup("nil") {
				break
			}
			msg := t.errorMessage(value)
			t.line("let _ := %s", values[0])
			t.line("return %s", t.action("throw", apply("Go.Exc.error", msg)))
			return
		}
		values = append(values, t.value(value, t.result.At(i).Type()))
	}
	t.line("return %s", tuple(values))
}

func (t *translation) errorMessage(expr ast.Expr) string {
	c, ok := ast.Unparen(expr).(*ast.CallExpr)
	if ok && len(c.Args) == 1 {
		s, sel := ast.Unparen(c.Fun).(*ast.SelectorExpr)
		if sel {
			f, fn := t.model.Info.Uses[s.Sel].(*types.Func)
			if fn && f.Pkg() != nil {
				key := f.Pkg().Path() + "." + f.Name()
				v := t.model.Info.Types[c.Args[0]].Value
				if v != nil && v.Kind() == constant.String && (key == "errors.New" || key == "fmt.Errorf") {
					message := constant.StringVal(v)
					if key == "fmt.Errorf" {
						message = fmt.Sprintf(message, []any{}...)
					}
					return leanString(message)
				}
			}
		}
	}
	t.reject(expr, "expected nil, errors.New or fmt.Errorf with a constant message")
	return ""
}

func (t *translation) rangeStmt(s *ast.RangeStmt) {
	info := t.model.Info
	typ := info.TypeOf(s.X)
	val := t.value(s.X, nil)
	item, index := t.next(), t.next()
	binding := item
	var carrier string
	var indexType types.Type
	if b := basic(typ); b != nil && b.Info()&types.IsInteger != 0 {
		carrier = "List.range " + t.integer(s.X, val, typ, true)
		item = index
		indexType = typ
	} else if _, slice := typ.Underlying().(*types.Slice); slice {
		carrier = "(Array.toList " + val + ").zipIdx"
		item = tuple([]string{item, index})
		indexType = types.Typ[types.Int]
	} else {
		t.reject(s.X, "range requires an integer or slice")
	}
	t.line("for %s in %s do", item, carrier)
	t.depth++
	num := t.leanType(s.X, indexType)
	if s.Key != nil {
		t.rangeBinding(s, s.Key, apply(num+".ofNat", index))
	}
	if s.Value != nil {
		t.rangeBinding(s, s.Value, binding)
	}
	t.block(s.Body.List)
	t.depth--
}

func (t *translation) rangeBinding(s *ast.RangeStmt, expr ast.Expr, value string) {
	id, ok := expr.(*ast.Ident)
	if !ok {
		t.reject(expr, "range requires variable targets")
	}
	if id.Name == "_" {
		return
	}
	if s.Tok == token.DEFINE {
		t.line("let mut %s := %s", t.variable(t.model.Info.Defs[id]), value)
	} else {
		name, _ := t.target(expr)
		t.line("%s := %s", name, value)
	}
}

func (t *translation) switchStmt(s *ast.SwitchStmt) {
	if s.Init != nil {
		t.statement(s.Init)
	}
	var tag string
	var typ types.Type
	if s.Tag != nil {
		tag = t.next()
		typ = t.model.Info.TypeOf(s.Tag)
		t.line("let %s := %s", tag, t.value(s.Tag, nil))
	}
	var defaultCase *ast.CaseClause
	branches := 0
	for _, stmt := range s.Body.List {
		c := stmt.(*ast.CaseClause)
		if c.List == nil {
			defaultCase = c
			continue
		}
		for _, condition := range c.List {
			b := t.value(condition, typ)
			if s.Tag != nil {
				b = t.binary(condition, token.EQL, tag, b, typ, typ)
			}
			t.line("if %s then", b)
			t.depth++
			t.caseBody(c)
			t.depth--
			t.line("else")
			t.depth++
			branches++
		}
	}
	if defaultCase != nil {
		t.caseBody(defaultCase)
	} else if branches > 0 {
		t.line("pure ()")
	}
	t.depth -= branches
}

func (t *translation) caseBody(c *ast.CaseClause) {
	var stop, next ast.Node
	for _, stmt := range c.Body {
		ast.Inspect(stmt, func(n ast.Node) bool {
			switch b := n.(type) {
			case *ast.ForStmt, *ast.RangeStmt:
				return false
			case *ast.SwitchStmt:
				ast.Inspect(b.Body, func(inner ast.Node) bool {
					switch s := inner.(type) {
					case *ast.ForStmt, *ast.RangeStmt:
						return false
					case *ast.BranchStmt:
						if s.Tok == token.CONTINUE {
							next = s
						}
					}
					return true
				})
				return false
			case *ast.BranchStmt:
				switch b.Tok {
				case token.BREAK:
					stop = b
				case token.CONTINUE:
					next = b
				}
			}
			return true
		})
	}
	if stop == nil {
		t.block(c.Body)
		return
	}
	if next != nil {
		t.reject(next, "case combines a switch break with continue to an enclosing loop")
	}
	t.line("for _ in [()] do")
	t.depth++
	t.block(c.Body)
	t.depth--
}
