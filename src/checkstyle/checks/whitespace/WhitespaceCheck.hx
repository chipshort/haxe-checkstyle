package checkstyle.checks.whitespace;

import checkstyle.token.TokenTree;
import checkstyle.Checker.Ast;
import checkstyle.checks.whitespace.WhitespaceCheckBase.WhitespacePolicyCheck;

using Lambda;
using checkstyle.utils.TokenTreeCheckUtils;
using checkstyle.utils.ConditionalUtils;

@name("Whitespace")
@desc("Checks that whitespace is present or absent around a token in a specific context.")
class WhitespaceCheck extends Check {

	public var policies:Array<AdvancedWhitespacePolicy>;
	public var tokens:Array<WhitespaceToken>;
	public var contexts:Array<String>;
	public var ignore:Array<WhitespaceType>;

	var convertedContexts:Array<ContextSelector>;

	public function new() {
		super(AST);

		tokens = [
			MAP_ARROW, ASSIGN, UNARY, COMPARE, BITWISE, BOOL
		];
		policies = [AROUND];
		contexts = [
			OBJECT_DECL,
			FUNCTION,
			VAR,
			SWITCH,
			TRY_CATCH,
			ARRAY_ACCESS,
			BLOCK,
			CLASS,
			INTERFACE,
			TYPEDEF,
			ABSTRACT,
			ENUM,
			TYPE_DECL,
			BINOP
		];
		ignore = [];
	}

	function violation(tok:TokenTree, p:String) {
		logPos('Whitespace policy "$p" violated by "${TokenDefPrinter.toString(tok.tok)}"', tok.pos);
	}

	override function actualRun() {
		var tokenList:Array<TokenDef> = [];

		for (token in tokens) {
			switch (token) {
				case ASSIGN:
					tokenList = tokenList.concat([
						Binop(OpAssign),
						Binop(OpAssignOp(OpAdd)),
						Binop(OpAssignOp(OpSub)),
						Binop(OpAssignOp(OpMult)),
						Binop(OpAssignOp(OpDiv)),
						Binop(OpAssignOp(OpMod)),
						Binop(OpAssignOp(OpShl)),
						Binop(OpAssignOp(OpShr)),
						Binop(OpAssignOp(OpUShr)),
						Binop(OpAssignOp(OpOr)),
						Binop(OpAssignOp(OpAnd)),
						Binop(OpAssignOp(OpXor))
					]);
				case UNARY:
					tokenList = tokenList.concat([
						Unop(OpNot),
						Unop(OpIncrement),
						Unop(OpDecrement)
					]);
				case COMPARE:
					tokenList = tokenList.concat([
						Binop(OpGt),
						Binop(OpLt),
						Binop(OpGte),
						Binop(OpLte),
						Binop(OpEq),
						Binop(OpNotEq)
					]);
				case ARITHMETIC:
					tokenList = tokenList.concat([
						Binop(OpAdd),
						Binop(OpSub),
						Binop(OpMult),
						Binop(OpDiv),
						Binop(OpMod)
					]);
				case BITWISE:
					tokenList = tokenList.concat([
						Binop(OpAnd),
						Binop(OpOr),
						Binop(OpXor),
						Binop(OpShl),
						Binop(OpShr),
						Binop(OpUShr)
					]);
				case BOOL:
					tokenList.push(Binop(OpBoolAnd));
					tokenList.push(Binop(OpBoolOr));
				case MAP_ARROW:
					tokenList.push(Binop(OpArrow));
				case COMMA:
					tokenList.push(Comma);
				case SEMICOLON:
					tokenList.push(Semicolon);
				case POPEN:
					tokenList.push(POpen);
				case PCLOSE:
					tokenList.push(PClose);
				case BROPEN:
					tokenList.push(BrOpen);
				case BRCLOSE:
					tokenList.push(BrClose);
				case BKOPEN:
					tokenList.push(BkOpen);
				case BKCLOSE:
					tokenList.push(BkClose);
				case DBLDOT:
					tokenList.push(DblDot);
				case DOT:
					tokenList.push(Dot);
				case INTERVAL:
					tokenList.push(Binop(OpInterval));
				case FUNCTION_ARROW:
					tokenList.push(Arrow);
				case LT:
					tokenList.push(Binop(OpLt));
				case GT:
					tokenList.push(Binop(OpGt));
				case QUESTION:
					tokenList.push(Question);
			}
		}
		if (tokenList.length <= 0) return;

		convertedContexts = contexts.map(function (s) return ContextSelector.fromString(s));

		checkTokens(checker.getTokenTree(), tokenList);
	}

	function walkFile(ast:Ast, token:TokenTree, stack:List<TokenContext>) {
		for (decl in ast.decls) walkTypeDecl(decl, token, stack);
	}

	function walkTypeDecl(type:TypeDecl, token:TokenTree, stack:List<TokenContext>):Bool {
		if (type == null) return false;

		if (!checkPos(type.pos, token)) return false;

		switch (type.decl) {
			case EClass(d):
				var isInterface = false;
				for (flag in d.flags) {
					switch (flag) {
						case HInterface:
							isInterface = true;
							break;
						case HExtern, HPrivate, HExtends(_), HImplements(_):
					}
				}
				stack.push(isInterface ? INTERFACE : CLASS);

				walkDefinition(d, token, stack);
				walkFields(d.data, token, stack);
			case EEnum(d):
				stack.push(ENUM);
				walkDefinition(d, token, stack);
				walkEnumConstructors(d.data, token, stack);
			case EAbstract(a):
				stack.push(ABSTRACT);
				walkDefinition(a, token, stack);
				walkFields(a.data, token, stack);
			case EImport(_, _):
				stack.push(IMPORT);
				//for (i in sl) checkPos(i.pos, token);
			case ETypedef(d):
				stack.push(TYPEDEF);
				walkDefinition(d, token, stack);
				walkComplexType(d.data, token, stack);
			case EUsing(_): //no position
		}

		return false;
	}

	function walkTypeParams(params:Array<TypeParam>, token:TokenTree, stack:List<TokenContext>):Bool {
		if (params == null) return false;

		for (p in params) {
			switch (p) {
				case TPType(t):
					walkComplexType(t, token, stack);
				case TPExpr(e):
					if (walkExpr(e, token, stack)) return true;
			}
		}
		return false;
	}

	function walkComplexType(type:ComplexType, token:TokenTree, stack:List<TokenContext>):Bool {
		if (type == null) return false;

		switch (type) {
			case TPath(p):
				walkTypeParams(p.params, token, stack);
			case TFunction(args, ret):
				for (a in args) walkComplexType(a, token, stack);
				walkComplexType(ret, token, stack);
			case TAnonymous(fields):
				var tmpStack = new List<TokenContext>();
				if (walkFields(fields, token, tmpStack)) {
					stack.push(ANON_STRUCTURE);
					//copy temporary stack over
					for (elem in stack) tmpStack.add(elem);
					stack.clear();
					for (elem in tmpStack) stack.add(elem);
					return true;
				}
			case TParent(t):
				walkComplexType(t, token, stack);
			case TExtend(p, fields):
				for (path in p) walkTypeParams(path.params, token, stack);
				walkFields(fields, token, stack);
			case TOptional(t):
				walkComplexType(t, token, stack);
		}
		return false;
	}

	function walkEnumConstructors(consts:Array<EnumConstructor>, token:TokenTree, stack:List<TokenContext>):Bool {
		if (consts == null) return false;

		for (c in consts) {
			var isMeta = walkMetadata(c.meta, token, stack);
			if (!isMeta && !checkPos(c.pos, token)) continue;
			walkParams(c.params, token, stack);
			if (isMeta) stack.push(META);
		}
		return false;
	}

	function walkFields(fields:Array<Field>, token:TokenTree, stack:List<TokenContext>):Bool {
		if (fields == null) return false;

		for (f in fields) {
			var isMeta = walkMetadata(f.meta, token, stack);
			if (!isMeta && !checkPos(f.pos, token)) continue;
			switch (f.kind) {
				case FVar(t, e):
					stack.push(VAR);
					walkComplexType(t, token, stack);
					walkExpr(e, token, stack);
				case FFun(f):
					walkFunction(f, token, stack);
				case FProp(_, _, t, e):
					stack.push(PROPERTY);
					walkComplexType(t, token, stack);
					walkExpr(e, token, stack);
			}
			if (isMeta) stack.push(META);
			return true;
		}

		return false;
	}

	function walkDefinition<A, B>(d:Definition<A, B>, token:TokenTree, stack:List<TokenContext>):Bool {
		if (d == null) return false;

		walkParams(d.params, token, stack);
		if (walkMetadata(d.meta, token, stack)) stack.push(META);

		return true;
	}

	function walkParams(params:Array<TypeParamDecl>, token:TokenTree, stack:List<TokenContext>):Bool {
		if (params == null) return false;

		for (p in params) {
			//cannot check for param itself, only metadata has position
			for (meta in p.meta) {
				if (checkPos(meta.pos, token)) {
					stack.push(META);
					for (e in meta.params) walkExpr(e, token, stack);
					return true;
				}
			}
			walkParams(p.params, token, stack);
		}

		return false;
	}

	function walkFunction(func:Function, token:TokenTree, stack:List<TokenContext>):Bool {
		if (func == null) return false;

		stack.push(FUNCTION);
		walkParams(func.params, token, stack);
		if (func.args != null) {
			for (arg in func.args) {
				//only metadata again
				walkComplexType(arg.type, token, stack);
				if (walkMetadata(arg.meta, token, stack)) stack.push(META);
			}
		}
		walkExpr(func.expr, token, stack);

		return true;
	}

	function walkMetadata(meta:Metadata, token:TokenTree, stack:List<TokenContext>):Bool {
		if (meta == null) return false;

		for (m in meta) {
			for (e in m.params) {
				if (walkExpr(e, token, stack)) return true;
			}
			if (checkPos(m.pos, token)) return true;

			//need to fall back to tokens here because the positions do not include the parentheses
			// At
			//  |- Const(CIdent(metaname))
			//      |- POpen
			//          |- parameters
			//          |- PClose
			if (token.is(PClose)) { //find corresponding POpen
				while (token.tok != null) {
					switch (token.tok) {
						case POpen: break;
						default:
					}
					token = token.parent;
				}
			}
			if (token.is(POpen) && token.parent != null && token.parent.parent != null) {
				switch (token.parent.tok) {
					case Const(CIdent(_)):
					default: return false;
				}
				switch (token.parent.parent.tok) {
					case At: return true;
					default: return false;
				}
			}
		}

		return false;
	}

	function checkPos(pos:Position, token:TokenTree):Bool {
		return token.pos.min >= pos.min && token.pos.max <= pos.max;
	}

	function walkExpr(expr:Expr, token:TokenTree, stack:List<TokenContext>, ignorePosOnce = false):Bool {
		if (expr == null || expr.expr == null) return false;
		var isWithin = checkPos(expr.pos, token);
		if (!ignorePosOnce && !isWithin) return false;

		switch (expr.expr) {
			case EConst(CIdent(_)):
			case EConst(_):
				stack.push(LITERAL);
			case EArray(e1, e2):
				stack.push(ARRAY_ACCESS);
				if (walkExpr(e1, token, stack)) return true;
				if (walkExpr(e2, token, stack)) return true;
			case EBinop(_, e1, e2):
				stack.push(BINOP);
				if (walkExpr(e1, token, stack)) return true;
				if (walkExpr(e2, token, stack)) return true;
			case EField(e, field):
				stack.push(FIELD_ACCESS);
				if (walkExpr(e, token, stack)) return true;
			case EParenthesis(e):
				stack.push(PARENTHESES);
				if (walkExpr(e, token, stack)) return true;
			case EObjectDecl(fields):
				stack.push(OBJECT_DECL);
				for (f in fields) {
					if (walkExpr(f.expr, token, stack)) return true;
				}
			case EArrayDecl(vals):
				if (vals.length > 0 && vals[0].expr.match(EBinop(OpArrow, _, _))) {
					stack.push(MAP);
				}
				else {
					stack.push(ARRAY);
				}

				for (v in vals) {
					if (walkExpr(v, token, stack)) return true;
				}
			case ECall(e, params):
				stack.push(FUNCTION_CALL);
				if (walkExpr(e, token, stack)) return true;
				for (p in params) {
					if (walkExpr(p, token, stack)) return true;
				}
			case ENew(_, params):
				stack.push(CONSTRUCTOR_CALL);
				for (p in params) if (walkExpr(p, token, stack)) return true;
			case EUnop(_, _, e):
				stack.add(UNOP);
				if (walkExpr(e, token, stack)) return true;
			case EVars(vars):
				stack.push(VAR);
				for (v in vars) if (walkExpr(v.expr, token, stack)) return true;
			case EFunction(_, f):
				walkFunction(f, token, stack);
			case EBlock(exprs):
				stack.push(BLOCK);
				for (e in exprs) if (walkExpr(e, token, stack)) return true;
			case EFor(it, expr):
				stack.push(FOR);
				if (walkExpr(it, token, stack)) return true;
				if (walkExpr(expr, token, stack)) return true;
			case EIn(e1, e2):
				if (walkExpr(e1, token, stack)) return true;
				if (walkExpr(e2, token, stack)) return true;
			case EIf(cond, eif, eelse):
				stack.push(IF_ELSE);
				if (walkExpr(cond, token, stack)) return true;
				if (walkExpr(eif, token, stack)) return true;
				if (walkExpr(eelse, token, stack)) return true;
			case EWhile(cond, e, _):
				stack.push(WHILE);
				if (walkExpr(cond, token, stack)) return true;
				if (walkExpr(e, token, stack)) return true;
			case ESwitch(e, cases, edef):
				stack.push(SWITCH);
				for (c in cases) {
					if (walkCase(c, token, stack)) return true;
				}
				if (walkDefault(edef, token, stack)) return true;
			case ETry(e, catches):
				stack.push(TRY_CATCH);
				if (walkExpr(e, token, stack)) return true;
				for (c in catches) {
					if (walkExpr(c.expr, token, stack)) return true;
				}
			case EReturn(e):
				if (walkExpr(e, token, stack)) return true;
			case EBreak:
				return true;
			case EContinue:
				return true;
			case EUntyped(e):
				if (walkExpr(e, token, stack)) return true;
			case EThrow(e):
				if (walkExpr(e, token, stack)) return true;
			case ECast(e, _):
				stack.push(FUNCTION_CALL); //maybe add own context here
				if (walkExpr(e, token, stack)) return true;
			case EDisplay(_, _): //ignore
			case EDisplayNew(_): //ignore
			case ETernary(cond, eif, eelse):
				stack.push(TERNARY);
				if (walkExpr(cond, token, stack)) return true;
				if (walkExpr(eif, token, stack)) return true;
				if (walkExpr(eelse, token, stack)) return true;
			case ECheckType(e, _):
				if (walkExpr(e, token, stack)) return true;
			case EMeta(_, e):
				stack.push(META);
				if (walkExpr(e, token, stack)) return true;
		}

		return isWithin;
	}

	function walkDefault(expr:Expr, token:TokenTree, stack:List<TokenContext>):Bool {
		if (expr == null) return false;

		var tmpStack = new List<TokenContext>();
		if (walkExpr(expr, token, tmpStack, true)) {
			stack.push(CASE);
			//copy temporary stack over
			for (elem in stack) tmpStack.add(elem);
			stack.clear();
			for (elem in tmpStack) stack.add(elem);
			return true;
		}
		return false;
	}

	function walkCase(c:Case, token:TokenTree, stack:List<TokenContext>):Bool {
		if (c == null) return false;

		var hit = false;
		var tmpStack = new List<TokenContext>();
		for (v in c.values) {
			if (walkExpr(v, token, tmpStack)) hit = true;
		}
		if (walkExpr(c.guard, token, tmpStack)) hit = true;
		if (walkExpr(c.expr, token, tmpStack, true)) hit = true;

		if (hit) {
			stack.push(CASE);
			//copy temporary stack over
			for (elem in stack) tmpStack.add(elem);
			stack.clear();
			for (elem in tmpStack) stack.add(elem);
		}

		return hit;
	}

	function checkTokens(root:TokenTree, toks:Array<TokenDef>) {
		if (policies == null || policies.empty() || policies.contains(IGNORE)) return;
		var tokenList:Array<TokenTree> = root.filter(toks, ALL);
		checkTokenList(tokenList);
	}

	function checkTokenList(tokenList:Array<TokenTree>) {
		for (tok in tokenList) {
			if (isPosSuppressed(tok.pos)) continue;
			if (!checkContext(tok)) continue;

			checkWhitespace(tok);
		}
	}

	function checkWhitespaceExt(tok:TokenTree, checkCallback:WhitespacePolicyCheck) {
		var linePos:LinePos = checker.getLinePos(tok.pos.min);
		var tokLen:Int = tok.toString().length;
		if (tok.tok.match(IntInterval(_))) {
			linePos = checker.getLinePos(tok.pos.max - 3);
			tokLen = 3;
		}
		var line:String = checker.lines[linePos.line];
		var before:String = line.substr(0, linePos.ofs);
		var after:String = line.substr(linePos.ofs + tokLen);

		if (ignore.contains(SPACE)) {
			before = before.replace(" ", "");
			after = after.replace(" ", "");
		}
		if (ignore.contains(TAB)) {
			before = before.replace("\t", "");
			after = after.replace("\t", "");
		}

		var whitespaceBefore:Bool = ~/^(.*\s|)$/.match(before);
		var whitespaceAfter:Bool = ~/^(\s.*|)$/.match(after);

		if (ignore.contains(NEWLINE)) {
			if (before == "") whitespaceBefore = false;
			if (after == "") whitespaceAfter = false;
		}

		checkCallback(whitespaceBefore, whitespaceAfter);
	}

	function checkWhitespace(tok:TokenTree) {
		checkWhitespaceExt(tok, function(before:Bool, after:Bool) {
			var v = function (p:AdvancedWhitespacePolicy) violation(tok, Std.string(p));
			for (p in policies) {
				switch (p) {
					case AROUND:
						if (!before || !after) {
							v(p);
							return;
						}
					case BEFORE:
						if (!before) {
							v(p);
							return;
						}
					case AFTER:
						if (!after) {
							v(p);
							return;
						}
					case NONE:
						if (before || after) {
							v(p);
							return;
						}
					case NONE_BEFORE:
						if (before) {
							v(p);
							return;
						}
					case NONE_AFTER:
						if (after) {
							v(p);
							return;
						}
					default:
						return;
				}
			}
		});
	}

	function checkContext(token:TokenTree):Bool {
		if (token.filterOpSub()) return false;

		var contextQueue:List<TokenContext> = determineContext(token);
		return contextQueue != null && hasContext(contextQueue);
	}

	function hasContext(context:List<TokenContext>):Bool {
		for (c in convertedContexts) {
			if (c.matches(context)) return true;
		}
		return false;
	}

	function determineContext(token:TokenTree):List<TokenContext> {
		var stack = new List<TokenContext>();

		if (!token.isReachable(checker.ast.defines)) return null;
		walkFile(checker.ast, token, stack);

		//now apply some tweaks that are needed because of limited position information

		if (stack.isEmpty()) { //it's outside of a type declaration
			var tok = token;
			while (tok.tok != null) {
				switch (tok.tok) {
					case Kwd(KwdUsing):
						stack.add(USING);
						break;
					case Kwd(KwdPackage):
						stack.add(PACKAGE);
						break;
					default:
				}
				tok = tok.parent;
			}
		}
		else if (token.is(Binop(OpLt)) || token.is(Binop(OpGt))) {
			if (stack.first() != BINOP) stack.push(TYPE_PARAMETER);
		}
		else if (token.is(DblDot) || token.is(Question)) {
			var notTypeDecls = [
				TERNARY,
				OBJECT_DECL,
				SWITCH
			];
			if (!notTypeDecls.contains(stack.first())) stack.push(TYPE_DECL);
		}
		else if (token.is(Binop(OpAssign))) {
			if (stack.first() != BINOP) stack.push(BINOP);
		}

		// logPos(token.tok + " " + stack, token.pos, INFO);

		return stack;
	}
}

enum ContextSelectorEnum {
	CONTEXT(context:TokenContext);
	PLACEHOLDER;
	DIRECT_CHILD(parent:ContextSelectorEnum, child:ContextSelectorEnum);
	CHILD(parent:ContextSelectorEnum, child:ContextSelectorEnum);
	//maye add :empty and :not()
}

abstract ContextSelector(ContextSelectorEnum) to ContextSelectorEnum {
	inline function new(query:ContextSelectorEnum) {
		this = query;
	}

	@:from
	public static function fromString(s:String):ContextSelector {
		return new ContextSelector(parseQuery(s));
	}

	public function matches(context : List<TokenContext>):Bool {
		var context = context.map(function (t) return t); //copy context

		switch (this) {
			case CHILD(p, c):
				var childCorrect = new ContextSelector(c).matchesSingle(context.pop()); //child can only be Context(_)
				if (!childCorrect) return false; //first child must match directly
				return matchesParentSomewhere(context, p);
			default: return matchesSomewhere(context);
		}
		return false;
	}

	function matchesSomewhere(context:List<TokenContext>):Bool {
		switch (this) {
			case CONTEXT(c): return matchesSingle(context.pop());
			case DIRECT_CHILD(p, c): return new ContextSelector(c).matchesSingle(context.pop()) && new ContextSelector(p).matchesSomewhere(context);
			case CHILD(p, c):
				while (!context.isEmpty()) { //remove elements until we have a match
					var childCorrect = new ContextSelector(c).matchesSingle(context.pop()); //child can only be Context(_)
					if (childCorrect) break;
				}
				return matchesParentSomewhere(context, p);
			default: return matchesSingle(context.pop());
		}
		return false;
	}

	function matchesParentSomewhere(context:List<TokenContext>, p:ContextSelectorEnum):Bool {
		while (!context.isEmpty()) {
			if (new ContextSelector(p).matchesSomewhere(context)) return true;
		}
		return false;
	}

	function matchesSingle(check:TokenContext):Bool {
		switch (this) {
			case CONTEXT(c): return check == c;
			case PLACEHOLDER: return true;
			case null: return true;
			default: return false;
		}
	}

	static inline function parseQuery(s:String):ContextSelectorEnum {
		var tokens = checkstyle.utils.StringUtils.splitAll(s, [" ", ">"], true);
		if (tokens.length == 0) {
			var e = "Error: Invalid context query";
			#if debug
			Sys.println(e);
			#end
			#if unittest
			throw e;
			#end
		}
		return parseToken(null, tokens.length, tokens);
	}

	static function parseToken(parsed:ContextSelectorEnum, current:Int, tokens:Array<String>):ContextSelectorEnum {
		if (current < 0) return parsed;

		var token = tokens[current];
		switch (token) {
			case " ":
				return CHILD(parseToken(parsed, current - 1, tokens), parsed);
			case ">":
				return DIRECT_CHILD(parseToken(parsed, current - 1, tokens), parsed);
			case "*":
				return parseToken(PLACEHOLDER, current - 1, tokens);
			default:
				return parseToken(CONTEXT(cast token), current - 1, tokens);
		}
	}
}

@:enum
abstract AdvancedWhitespacePolicy(String) {
	var BEFORE = "before";
	var AFTER = "after";
	var AROUND = "around"; // = BEFORE + AFTER
	var NONE = "none"; // = NONE_BEFORE + NONE_AFTER
	var NONE_BEFORE = "noneBefore";
	var NONE_AFTER = "noneAfter";
	var IGNORE = "ignore";
}

@:enum
abstract TokenContext(String) to String {
	var OBJECT_DECL = "Object";
	var CLASS = "Class";
	var INTERFACE = "Interface";
	var TYPEDEF = "Typedef";
	var ABSTRACT = "Abstract";
	var ENUM = "Enum";
	var FUNCTION = "Function";
	//var SHORT_LAMBDA = "ShortLambda"; //not supported by haxeparser yet
	//var FUNCTION_PARAM = "Parameters";
	var LITERAL = "Literal";
	var FUNCTION_CALL = "Call";
	var CONSTRUCTOR_CALL = "ConstructorCall";
	var VAR = "Var";
	var PROPERTY = "Property";
	var BLOCK = "Block";
	var IF_ELSE = "IfElse";
	var WHILE = "While";
	var FOR = "For";
	//var COND = "Condition";
	var SWITCH = "Switch";
	var CASE = "Case";
	var TRY_CATCH = "TryCatch";
	var ARRAY = "Array";
	var MAP = "Map";
	var ARRAY_ACCESS = "ArrayAccess";
	//var REIFICATION = "Reification";
	var TYPE_PARAMETER = "TypeParameter";
	var META = "Meta";
	//var SINGLELINE = "Singleline";
	var PACKAGE = "Package";
	var IMPORT = "Import";
	var USING = "Using";
	var PARENTHESES = "Parentheses"; //generic parentheses (e.g. for grouping boolean expressions)
	var TERNARY = "Ternary";
	var UNOP = "UnaryOperator";
	var BINOP = "BinaryOperator";
	var FIELD_ACCESS = "FieldAccess";
	var TYPE_DECL = "TypeDeclaration";
	var ANON_STRUCTURE = "AnonymousStructure";
}

@:enum
abstract WhitespaceToken(String) {
	var ASSIGN = "Assign";
	var UNARY = "Unary";
	var COMPARE = "Compare";
	var ARITHMETIC = "Arithmetic";
	var BITWISE = "Bitwise";
	var BOOL = "Bool";
	var MAP_ARROW = "=>";
	var COMMA = ",";
	var SEMICOLON = ";";
	var POPEN = "(";
	var PCLOSE = ")";
	var BROPEN = "{";
	var BRCLOSE = "}";
	var BKOPEN = "[";
	var BKCLOSE = "]";
	var DBLDOT = ":";
	var QUESTION = "?";
	var DOT = ".";
	var INTERVAL = "...";
	var FUNCTION_ARROW = "->";
	var LT = "<";
	var GT = ">";
	//should all possible tokens be added seperately? (e.g. += or <=)
}

@:enum
abstract WhitespaceType(String) {
	var NEWLINE = "nl";
	var SPACE = "space";
	var TAB = "tab";
}