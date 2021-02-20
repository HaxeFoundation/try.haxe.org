import api.Program;

typedef LibConf = {
	name:String,
	?args:Array<String>,
	?head:Array<String>,
	?body:Array<String>,
	?help:String
}

class Libs {
	static var available:Map<String, Array<LibConf>> = [
		"JS" => [
			{name: "actuate", help: "https://github.com/openfl/actuate", args: []},
			{name: "box2d", help: "https://github.com/openfl/box2d"},
			{name: "format", help: "https://github.com/HaxeFoundation/format"},
			{name: "hx3compat", help: "https://github.com/HaxeFoundation/hx3compat"},
			{
				name: "hxColorToolkit",
				help: "https://github.com/andyli/hxColorToolkit"
			},
			{name: "nape", help: "https://github.com/deltaluca/nape"},
			{name: "pecan", help: "https://github.com/Aurel300/pecan"},
			{name: "pixijs", head: ["<script src='../../../lib/js/pixi.min.js'></script>"]},
			{name: "thx.core", help: "https://github.com/fponticelli/thx.core"},
			{name: "thx.culture", help: "https://github.com/fponticelli/thx.culture"},
			{name: "tink_core", help: "https://github.com/haxetink/tink_core"},
			{name: "tink_lang", help: "https://github.com/haxetink/tink_lang"},
			{name: "tink_state", help: "https://github.com/haxetink/tink_state"},
			{name: "threejs", head: ["<script src='../../../lib/js/three.min.js'></script>"]},
			{name: "safety", help: "https://github.com/RealyUniqueName/Safety"},
			{name: "utest", help: "https://github.com/haxe-utest/utest"},
		],
		"NEKO" => [
			{name: "actuate", help: "https://github.com/openfl/actuate", args: []},
			{name: "format", help: "https://github.com/HaxeFoundation/format"},
			{name: "hx3compat", help: "https://github.com/HaxeFoundation/hx3compat"},
			{
				name: "hxColorToolkit",
				help: "https://github.com/andyli/hxColorToolkit"
			},
			{name: "pecan", help: "https://github.com/Aurel300/pecan"},
			{name: "thx.core", help: "https://github.com/fponticelli/thx.core"},
			{name: "thx.culture", help: "https://github.com/fponticelli/thx.culture"},
			{name: "tink_core", help: "https://github.com/haxetink/tink_core"},
			{name: "tink_lang", help: "https://github.com/haxetink/tink_lang"},
			{name: "tink_macro", help: "https://github.com/haxetink/tink_macro"},
			{name: "safety", help: "https://github.com/RealyUniqueName/Safety"},
			{name: "utest", help: "https://github.com/haxe-utest/utest"},
		],
		"EVAL" => [
			{name: "actuate", help: "https://github.com/openfl/actuate", args: []},
			{name: "format", help: "https://github.com/HaxeFoundation/format"},
			{name: "hx3compat", help: "https://github.com/HaxeFoundation/hx3compat"},
			{
				name: "hxColorToolkit",
				help: "https://github.com/andyli/hxColorToolkit"
			},
			{name: "pecan", help: "https://github.com/Aurel300/pecan"},
			{name: "thx.core", help: "https://github.com/fponticelli/thx.core"},
			{name: "thx.culture", help: "https://github.com/fponticelli/thx.culture"},
			{name: "tink_core", help: "https://github.com/haxetink/tink_core"},
			{name: "tink_lang", help: "https://github.com/haxetink/tink_lang"},
			{name: "tink_macro", help: "https://github.com/haxetink/tink_macro"},
			{name: "safety", help: "https://github.com/RealyUniqueName/Safety"},
			{name: "utest", help: "https://github.com/haxe-utest/utest"},
		],
		"HL" => [
			{name: "actuate", help: "https://github.com/openfl/actuate", args: []},
			{name: "format", help: "https://github.com/HaxeFoundation/format"},
			{name: "hx3compat", help: "https://github.com/HaxeFoundation/hx3compat"},
			{
				name: "hxColorToolkit",
				help: "https://github.com/andyli/hxColorToolkit"
			},
			{name: "pecan", help: "https://github.com/Aurel300/pecan"},
			{name: "safety", help: "https://github.com/RealyUniqueName/Safety"},
			{name: "thx.core", help: "https://github.com/fponticelli/thx.core"},
			{name: "thx.culture", help: "https://github.com/fponticelli/thx.culture"},
			{name: "tink_core", help: "https://github.com/haxetink/tink_core"},
			{name: "tink_lang", help: "https://github.com/haxetink/tink_lang"},
			{name: "tink_macro", help: "https://github.com/haxetink/tink_macro"},
			{name: "utest", help: "https://github.com/haxe-utest/utest"},
		],
	];

	static var defaultChecked:Map<String, Array<String>> = ["JS" => [], "NEKO" => [], "EVAL" => [], "HL" => []]; // array of lib names

	static public function getLibsConfig(?target:TargetV2, ?targetName:String):Array<LibConf> {
		var name = targetName != null ? targetName : Type.enumConstructor(target);
		return if (available.exists(name)) return available.get(name) else [];
	}

	static public function getDefaultLibs(?target:TargetV2, ?targetName:String):Array<String> {
		var name = targetName != null ? targetName : Type.enumConstructor(target);
		return if (defaultChecked.exists(name)) return defaultChecked.get(name) else [];
	}
}
