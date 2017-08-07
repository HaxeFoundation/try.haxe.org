import api.Program;

typedef SWFInfo = {
	src:String,
}

typedef LibConf = {
	name : String,
	?args : Array<String>,
	?head:Array<String>,
	?body:Array<String>,
	?swf:SWFInfo,
	?help:String
}


class Libs
{

	static var available : Map<String, Array<LibConf>> = [
		"JS" => [
			{name:"actuate" , help:"https://github.com/openfl/actuate",args : []},
			{name:"format", help:"https://github.com/HaxeFoundation/format"},
			{name:"tink_core", help:"https://github.com/haxetink/tink_core"},
			{name:"tink_lang", help:"https://github.com/haxetink/tink_lang"},
			{name:"tink_macro", help:"https://github.com/haxetink/tink_macro"},
			{name:"thx.core", help:"https://github.com/fponticelli/thx.core"},
			{name:"thx.culture", help:"https://github.com/fponticelli/thx.culture"},
			{name:"hxColorToolkit", help:"https://github.com/andyli/hxColorToolkit"},
			{name:"threejs", head: ["<script src='../../../lib/js/three.min.js'></script>"]},
			{name:"pixijs", head: ["<script src='../../../lib/js/pixi.min.js'></script>"]},
		],
		"SWF" => [
			{name:"actuate" , help:"https://github.com/openfl/actuate",args : []},
			{name:"format", help:"https://github.com/HaxeFoundation/format"},
			{name:"tink_core", help:"https://github.com/haxetink/tink_core"},
			{name:"tink_lang", help:"https://github.com/haxetink/tink_lang"},
			{name:"tink_macro", help:"https://github.com/haxetink/tink_macro"},
			{name:"thx.core", help:"https://github.com/fponticelli/thx.core"},
			{name:"thx.culture", help:"https://github.com/fponticelli/thx.culture"},
			{name:"hxColorToolkit", help:"https://github.com/andyli/hxColorToolkit"},
			{name:"away3d", swf:{src:"away3d4.swf"}, help:"http://away3d.com/livedocs/away3d/4.0/"},
		],
		"NEKO" => [
			{name:"actuate" , help:"https://github.com/openfl/actuate",args : []},
			{name:"format", help:"https://github.com/HaxeFoundation/format"},
			{name:"tink_core", help:"https://github.com/haxetink/tink_core"},
			{name:"tink_lang", help:"https://github.com/haxetink/tink_lang"},
			{name:"tink_macro", help:"https://github.com/haxetink/tink_macro"},
			{name:"thx.core", help:"https://github.com/fponticelli/thx.core"},
			{name:"thx.culture", help:"https://github.com/fponticelli/thx.culture"},
			{name:"hxColorToolkit", help:"https://github.com/andyli/hxColorToolkit"},
		],
	];

	static var defaultChecked : Map < String, Array<String> > = ["JS" => [], "SWF" => [], "NEKO" => []]; // array of lib names


	static public function getLibsConfig(?target:Target, ?targetName:String):Array<LibConf>
	{
		var name = targetName != null ? targetName : Type.enumConstructor(target);
		return if (available.exists(name)) return available.get(name) else [];
	}

	static public function getDefaultLibs(?target:Target, ?targetName:String):Array<String>
	{
		var name = targetName != null ? targetName : Type.enumConstructor(target);
		return if (defaultChecked.exists(name)) return defaultChecked.get(name) else [];
	}
}
