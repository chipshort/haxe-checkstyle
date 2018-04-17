package checks.whitespace;

import checkstyle.checks.whitespace.WhitespaceCheck;
import haxe.PosInfos;
import massive.munit.Assert;

class WhitespaceCheckTest extends CheckTestCase<WhitespaceCheckTests> {

	static inline var MSG_EQUALS:String = 'Whitespace policy "around" violated by "="';
	static inline var MSG_POPEN:String = 'Whitespace policy "around" violated by "("';
	static inline var MSG_COLON:String = 'Whitespace policy "around" violated by ":"';
	static inline var MSG_BROPEN:String = 'Whitespace policy "around" violated by "{"';
	static inline var MSG_LT:String = 'Whitespace policy "around" violated by "<"';
	static inline var MSG_GT:String = 'Whitespace policy "around" violated by ">"';

	public function testCorrectWhitespace() {
		var check = new WhitespaceCheck();
		assertNoMsg(check, CORRECT_WHITESPACE_AROUND);
		assertNoMsg(check, ISSUE_70);
		assertNoMsg(check, ISSUE_71);
		assertNoMsg(check, ISSUE_72);
		assertNoMsg(check, ISSUE_77);
		assertNoMsg(check, ISSUE_80);
		assertNoMsg(check, ISSUE_81);
		assertNoMsg(check, ISSUE_98);
		assertNoMsg(check, MINUS_CONSTANT);
		assertNoMsg(check, CONDITIONAL_STAR_IMPORT_ISSUE_160);
		assertNoMsg(check, CONDITIONAL_ELSE_STAR_IMPORT);
		assertNoMsg(check, CONDITIONAL_ELSEIF_STAR_IMPORT);
		assertNoMsg(check, NEGATIVE_VARS);
		assertNoMsg(check, NEGATIVE_NUMS);
		assertNoMsg(check, OPGT);
	}

	public function testIncorrectWhitespace() {
		var check = new WhitespaceCheck();
		assertMsg(check, NO_WHITESPACE_OBJECT_DECL, MSG_EQUALS);
		assertMsg(check, NO_WHITESPACE_TYPEDEF, MSG_EQUALS);
		assertMsg(check, ISSUE_59, MSG_EQUALS);
		assertMsg(check, ISSUE_63, MSG_EQUALS);
	}

	public function testIncorrectWhitespaceToken() {
		var check = new WhitespaceCheck();
		check.tokens = [ASSIGN];
		assertNoMsg(check, CORRECT_WHITESPACE_AROUND);
		assertMsg(check, NO_WHITESPACE_GT, MSG_EQUALS);
		assertMsg(check, NO_WHITESPACE_OBJECT_DECL, MSG_EQUALS);
		assertMsg(check, NO_WHITESPACE_TYPEDEF, MSG_EQUALS);
		assertMsg(check, NO_WHITESPACE_VAR_INIT, MSG_EQUALS);

		check.tokens = [COMPARE];
		assertNoMsg(check, CORRECT_WHITESPACE_AROUND);
		assertNoMsg(check, NO_WHITESPACE_VAR_INIT);
		assertNoMsg(check, NO_WHITESPACE_GT);
	}

	public function testCorrectContext() {
		var check = new WhitespaceCheck();
		check.contexts = [FUNCTION];

		check.tokens = [ASSIGN];
		assertNoMsg(check, NO_WHITESPACE_GT);
		assertNoMsg(check, NO_WHITESPACE_OBJECT_DECL);
		assertNoMsg(check, NO_WHITESPACE_TYPEDEF);
		assertNoMsg(check, NO_WHITESPACE_VAR_INIT);

		check.contexts = [FUNCTION, "Function>TypeDeclaration"];
		check.tokens = [POPEN, DBLDOT];
		assertNoMsg(check, WHITESPACE_FUNCTION);
		assertMsg(check, NO_WHITESPACE_AROUND_FUNCTION_POPEN, MSG_POPEN);
		assertMsg(check, NO_WHITESPACE_AROUND_FUNCTION_COLON, MSG_COLON);

		check.contexts = [META];
		assertMsg(check, META_RECOGNITION, MSG_POPEN);

		check.contexts = [CLASS];
		check.tokens = [BROPEN, BRCLOSE];
		assertNoMsg(check, CORRECT_WHITESPACE_AROUND);

		check.tokens = [BROPEN];
		check.contexts = ["Object>Object"];
		assertMsg(check, NESTED_OBJECT, MSG_BROPEN);

		check.tokens = [ARITHMETIC];
		check.contexts = [BLOCK];
		assertNoMsg(check, MATHS_IN_BLOCK);

		check.tokens = [DBLDOT];
		check.contexts = [TYPE_DECL];
		assertMsg(check, DIFFERENT_COLONS_AND_TYPEPARAMS, MSG_COLON);
		check.contexts = [OBJECT_DECL];
		assertMsg(check, DIFFERENT_COLONS_AND_TYPEPARAMS, MSG_COLON);

		check.tokens = [LT, GT];
		check.contexts = ["Function>TypeParameter"];
		assertMsg(check, DIFFERENT_COLONS_AND_TYPEPARAMS, MSG_LT);

		check.contexts = ["Array>BinaryOperator"];
		assertMsg(check, ARRAY_MAP_RECOGNITION, MSG_LT);
		check.contexts = ["Map>BinaryOperator"];
		assertNoMsg(check, ARRAY_MAP_RECOGNITION);
	}

	public function testMultiplePolicies() {
		var check = new WhitespaceCheck();
		check.policies = [NONE_AFTER];
		check.tokens = [POPEN];
		check.contexts = ["Parameters"];
		assertNoMsg(check, NO_WHITESPACE_AROUND_FUNCTION_COLON);
	}

	public function testStarImport() {
		var check = new WhitespaceCheck();
		check.tokens = [ARITHMETIC];
		assertNoMsg(check, ISSUE_70);
		assertNoMsg(check, CONDITIONAL_STAR_IMPORT_ISSUE_160);
		assertNoMsg(check, CONDITIONAL_ELSE_STAR_IMPORT);
		assertNoMsg(check, CONDITIONAL_ELSEIF_STAR_IMPORT);
	}

	public function testContextSelector() {
		var test = [CLASS, BLOCK, FUNCTION, BLOCK, SWITCH, BLOCK, CASE, TRY_CATCH, BLOCK, TYPE_PARAMETER];

		function createContext():List<TokenContext> {
			var context = new List<TokenContext>();
			for (t in test) context.push(t); //token list is inverse

			return context;
		}
		var context = createContext();

		function assertSelector(query:String, expected:Bool, ?pos:PosInfos) {
			Assert.areEqual(expected, ContextSelector.fromString(query).matches(context), pos);
			context = createContext();
		}
		assertSelector("Function>Block *>TypeParameter", true);
		assertSelector("Class>Function TypeParameter", false);
		assertSelector("Block>Case>TryCatch>Block>TypeParameter", true);
		assertSelector("*", true);
		assertSelector("Switch Case>TryCatch TypeParameter", true);
		assertSelector("Block Block", false);
	}
}

@:enum
abstract WhitespaceCheckTests(String) to String {
	var CORRECT_WHITESPACE_AROUND = "
	import haxe.macro.*;

	class Test {
		function test(param1:String, param2:String) {
			var x = { x: 100, y: 100,
				z: 20 * 10
			};
			var y:Array<String> = [];
		}
	}

	typedef Test = {
		x:Int,
		y:Int, z:Int
	}

	enum Test {
		Monday;
		Tuesday;
		Wednesday;
		Thursday;
		Friday; Weekend(day:String);
	}";

	var NO_WHITESPACE_OBJECT_DECL = "
	class Test {
		function test(param1:String, param2:String) {
			var x={ x: 100, y: 100,z: 20 };
		}
	}";

	var NO_WHITESPACE_TYPEDEF = "
	typedef Test ={
		x:Int,
		y:Int,z:Int
	}";

	var NO_WHITESPACE_VAR_INIT = "
	class Test {
		function test(param1:String, param2:String) {
			var test:Array<String>=[];
		}
	}";

	var NO_WHITESPACE_GT = "
	class Test {
		function test(param1:String, param2:String) {
			var test:Array<String>= [];
		}
	}";

	var ISSUE_58 = "
	class Test {
		public function new() {
			var x:Int, y:Int;
		}
	}";

	var ISSUE_59 = "
	typedef Test=Int
	";

	var ISSUE_63 = "
	typedef Test =#if true Int #else String #end
	";

	var ISSUE_70 = "
		import haxe.macro.*;
	";

	var ISSUE_71 = "
		class Test {
		function foo<T, X>() {
			trace((null : Array<Int, String>));
		}
	}";

	var ISSUE_72 = "
	abstract Test<T>(Array<T>) {}
	";

	var ISSUE_77 = "
	// comment
	class Test // comment
	{ // comment
		function foo() // comment
		{ // comment
			switch ('Test') // comment
			{ // comment
			} // comment
		} // comment
	} // comment
	";

	var ISSUE_80 = "
	interface Test implements Dynamic {}
	";

	var ISSUE_81 = "
	class Test {
		function foo() {
			do a++ while (true);
			do ++a while (true);
		}
	}";

	var ISSUE_98 = "
	class Test {
		// °öäüßÖÄÜ@łĸŋđđðſðæµ”“„¢«»Ø→↓←Ŧ¶€Ł}][{¬½¼³²
		var test:Int = 0;
	}";

	var MINUS_CONSTANT = "
	class Test {
		function test() {
			if (re.match(line) && line.indexOf('//') == -1) {
				log('Tab after non-space character, Use space for aligning', i + 1, line.length, null, Reflect.field(SeverityLevel, severity));
				return -1;
			}
			a = 1 - -2;
			b = 1.2 - -2.1;
			return -1;
		}
	}";

	var CONDITIONAL_STAR_IMPORT_ISSUE_160 = "
	#if macro
		import haxe.macro.*;
	#end";

	var CONDITIONAL_ELSEIF_STAR_IMPORT = "
	#if macro
		import haxe.macro.Type;
	#elseif neko
		import haxe.macro.*;
	#elseif neko
		import haxe.macro.*;
	#else
		#if linux
			import haxe.macro.Type;
		#else
			import haxe.macro.*;
		#end
	#end
	import haxe.macro.Type;";

	var CONDITIONAL_ELSE_STAR_IMPORT = "
	#if macro
		import haxe.macro.Type;
	#else
		import haxe.macro.*;
	#end
	import haxe.macro.Type;";

	var NEGATIVE_VARS = "
	class Test {
		function test() {
			var rest = if (neg) { -noFractions; }
			else { -noFractions; }
			var rest = if (neg) -noFractions;
			else -noFractions;
			var x = neg ? -frag : -frag;
			calc ([-width, -node.right, root], -node.left, {x : -x, y: -y});
			(-a);
			(1 * -a);
			do -a * 2 while(true);
			for (a in [-1, -2]) -a + 2;
			return -a;
		}
	}";

	var NEGATIVE_NUMS = "
	class Test {
		function test() {
			var rest = if (neg) { -8; }
			else { -9; }
			var rest = if (neg) -10;
			else -11;
			var x = neg ? -12 : -13;
			calc ([-14, -node.right, root], -node.left, {x : -xi15x, y: -16});
			(-16);
			(1 * -17);
			do -18 * 2 while(true);
			for (a in [-1, -2]) -18 + 2;
		}
	}";

	var OPGT = "
	class Test {
		function test() {
			if (a > b) return a >= b;
			if (a >> b > c) return a >>= b;
			if (a >>> b > c) return a >>>= b;
		}
	}";

	var WHITESPACE_FUNCTION = "
	class Test {
		function test ( a : String ) {
			if ( a == null )
				return null;
		}
	}";

	var WHITESPACE_IN_FUNCTION_DECLARATION = "
	class Test {
		function test ( a : String ) {
			var a : String = null;
		}
	}";

	var NO_WHITESPACE_AROUND_FUNCTION_POPEN = "
	class Test {
		function test(a : String ) {
		}
	}";

	var NO_WHITESPACE_AROUND_FUNCTION_COLON = "
	class Test {
		function test (a:String) {
		}
	}";

	var NESTED_OBJECT = "
	class Test {
		public static function getExample():ExampleDef {
			return {
				a: 'test',
				b:{
					c: 2
				}
			};
		}
	}";

	var MATHS_IN_BLOCK = "
	class Test {
		function test(vars:Map<String, Dynamic>):Array<Dynamic> {
			return 0 - (2 + -3);
		}
	}";

	var DIFFERENT_COLONS_AND_TYPEPARAMS = "
	class Test {
		function test(vars : Map<String, Dynamic > ) :Array < Dynamic > {
			return {
				name: varName,
                type : {
                    0 - (2 + -3);
                }
			};
		}
	}";

	var ARRAY_MAP_RECOGNITION = "
	class Test {
		var arrayTest:Array<Bool> = [true, false, 0<6];
		var mapTest:Map<String, Bool> = ['a' => true, 'test' => 3 < 2];
	}";

	var META_RECOGNITION = "
	class Test {
		@test( 'test' ) var t : String = null;
	}";
}