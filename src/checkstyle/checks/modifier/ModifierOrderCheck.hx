package checkstyle.checks.modifier;

import haxe.macro.PositionTools;

@name("ModifierOrder", "AccessOrder")
@desc("Checks that the order of modifiers conforms to the standards.")
class ModifierOrderCheck extends Check {

	public var modifiers:Array<ModifierOrderCheckModifier>;

	public function new() {
		super(AST);
		modifiers = [
			MACRO,
			OVERRIDE,
			PUBLIC_PRIVATE,
			STATIC,
			INLINE,
			DYNAMIC
		];
		categories = [Category.STYLE, Category.CLARITY];
	}

	override function actualRun() {
		forEachField(checkField);
	}

	function checkField(f:Field, _) {
		var lastIndex:Int = -1;
		var index:Int;

		for (access in f.access) {
			var modifier:ModifierOrderCheckModifier = access;
			index = modifiers.indexOf(modifier);
			if (index < lastIndex) {
				var pos = calcPos(f);
				warnOrder(f.name, modifier, pos);
				return;
			}
			lastIndex = index;
		}
	}

	function calcPos(f:Field):Position {
		switch (f.kind) {
			case FVar(_, _), FProp(_, _, _, _):
				return f.pos;
			case FFun(fun):
				if (fun.expr == null) {
					return f.pos;
				}
				return PositionTools.make({min: f.pos.min, max: fun.expr.pos.min, file: f.pos.file});
		}
	}

	function warnOrder(name:String, modifier:ModifierOrderCheckModifier, pos:Position) {
		logPos('"${name}" modifier order is invalid (modifier: "${modifier}")', pos);
	}
}

@:enum
abstract ModifierOrderCheckModifier(String) {
	var PUBLIC_PRIVATE = "PUBLIC_PRIVATE";
	var INLINE = "INLINE";
	var STATIC = "STATIC";
	var OVERRIDE = "OVERRIDE";
	var MACRO = "MACRO";
	var DYNAMIC = "DYNAMIC";

	@:from
	public static function fromAccess(access:Access):ModifierOrderCheckModifier {
		return switch (access) {
			case APublic, APrivate:
				PUBLIC_PRIVATE;
			case AStatic:
				STATIC;
			case AInline:
				INLINE;
			case AOverride:
				OVERRIDE;
			case AMacro:
				MACRO;
			case ADynamic:
				DYNAMIC;
		}
	}
}