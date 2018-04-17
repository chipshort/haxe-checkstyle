package checkstyle.utils;

import haxeparser.HaxeParser.SmallType;
import haxeparser.HaxeParser.HaxeCondParser;
import hxparse.Position;
import hxparse.LexerTokenSource;

class ConditionalUtils {

	public static function isReachable(token:TokenTree, defines:Map<String, Dynamic>):Bool {
		var parent:TokenTree = token.parent;
		while (parent != null) {
			if (parent.tok == null) return true;
			switch (parent.tok) {
				case Sharp(s):
					if (s != "end" && !evaluateConditional(parent, defines)) return false;

					if (s == "else" || s == "elseif") {
						parent = parent.parent; //ignore corresponding if
					}
				default:
			}
			parent = parent.parent;
		}
		return true;
	}

	static function evaluateConditional(token:TokenTree, defines:Map<String, Dynamic>):Bool {
		switch (token.tok) {
			case Sharp(s):
				if (s == "else") {
					return !evaluateConditional(token.parent, defines);
				}
				else if (s == "elseif") {
					return !evaluateConditional(token.parent, defines) && evaluateConditional(token.getFirstChild(), defines);
				}
				else if (s == "if") {
					return evaluateConditional(token.getFirstChild(), defines);
				}
			default:
				var interp = new ConditionalInterpreter(token, defines);
				return interp.evaluate();
		}

		return false;
	}
}

class CheckstyleTokenSource extends LexerTokenSource<Token> {
	var tokens:Array<Token>;
	var current:Int;

	public function new(tokenTree:TokenTree) {
		super(null, null);
		tokens = [];
		current = 0;

		addTokenTree(tokenTree);
	}

	function addTokenTree(tree:TokenTree) {
		tokens.push(tree);
		if (!tree.hasChildren()) return;
		for (child in tree.children) addTokenTree(child);
	}

	override public function token():Token {
		if (current >= tokens.length) return new Token(Eof, null);
		return tokens[current++];
	}

	override public function curPos():Position {
		return null;
	}
}

class ConditionalInterpreter {
	var defines:Map<String, Dynamic>;
	var parsed:Expr;

	public function new(tokens:TokenTree, defines:Map<String, Dynamic>) {
		this.defines = defines;
		var source = new CheckstyleTokenSource(tokens);
		var parser = new HaxeCondParser(source);
		parsed = parser.parseMacroCond(false).expr;
	}

	public function evaluate():Bool {
		return isTrue(eval(parsed));
	}

	public static function isTrue(a:SmallType):Bool {
		return switch a {
			case SBool(false), SNull, SFloat(0.0), SString(""): false;
			case _: true;
		}
	}

	static function compare(a:SmallType, b:SmallType):Int {
		return switch [a, b] {
			case [SNull, SNull]: 0;
			case [SFloat(a), SFloat(b)]: Reflect.compare(a, b);
			case [SString(a), SString(b)]: Reflect.compare(a, b);
			case [SBool(a), SBool(b)]: Reflect.compare(a, b);
			case [SString(a), SFloat(b)]: Reflect.compare(Std.parseFloat(a), b);
			case [SFloat(a), SString(b)]: Reflect.compare(a, Std.parseFloat(b));
			case _: 0;
		}
	}

	function eval(e:Expr):SmallType {
		return switch (e.expr) {
			case EConst(CIdent(s)): defines.exists(s) ? SString(s) : SNull;
			case EConst(CString(s)): SString(s);
			case EConst(CInt(f)), EConst(CFloat(f)): SFloat(Std.parseFloat(f));
			case EBinop(OpBoolAnd, e1, e2): SBool(isTrue(eval(e1)) && isTrue(eval(e2)));
			case EBinop(OpBoolOr, e1, e2): SBool(isTrue(eval(e1)) || isTrue(eval(e2)));
			case EUnop(OpNot, _, e): SBool(!isTrue(eval(e)));
			case EParenthesis(e): eval(e);
			case EBinop(op, e1, e2):
				var v1 = eval(e1);
				var v2 = eval(e2);
				var cmp = compare(v1, v2);
				var val = switch (op) {
					case OpEq: cmp == 0;
					case OpNotEq: cmp != 0;
					case OpGt: cmp > 0;
					case OpGte: cmp >= 0;
					case OpLt: cmp < 0;
					case OpLte: cmp <= 0;
					case _: throw "Unsupported operation";
				}
				SBool(val);
			case _: throw "Invalid condition expression";
		}
	}
}