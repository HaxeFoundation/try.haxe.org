package api;

typedef Program = {
	uid:String,
	mainClass:String,
	modules:Array<Module>,
	target:Target,
	haxeVersion:HaxeVersion,
	libs:Array<String>,
	dce:String,
	analyzer:String,
}

typedef ProgramV2 = {
	uid:String,
	editKey:Null<String>,
	mainClass:String,
	modules:Array<Module>,
	target:TargetV2,
	haxeVersion:HaxeVersion,
	libs:Array<String>,
	dce:String,
	analyzer:String,
}

typedef Module = {
	name:String,
	source:String
}

enum Target {
	JS(name:String);
	NEKO(name:String);
	EVAL(name:String);
	HL(name:String);
	SWF(name:String, ?version:Float);
}

enum TargetV2 {
	JS(name:String, version:ECMAScriptVersion);
	NEKO(name:String);
	EVAL(name:String);
	HL(name:String);
}

enum ECMAScriptVersion {
	ES5;
	ES6;
}

@:transitive
enum abstract HaxeVersion(String) to String from String {
	// var Haxe_3_3_0_rc_1 = "3.3.0-rc.1";
	// var Haxe_3_2_1 = "3.2.1";
	var Haxe_4_1_5 = "4.1.5";
	var Haxe_4_3_0 = "4.3.0";
	var Haxe_4_3_6 = "4.3.6";
}

typedef Output = {
	uid:String,
	editKey:Null<String>,
	stderr:String,
	stdout:String,
	args:Array<String>,
	errors:Array<String>,
	haxeout:String,
	times:String,
	success:Bool,
	message:String,
	href:String,
	source:String,
	embed:String
}

typedef HaxeCompiler = {
	dir:String,
	version:HaxeVersion,
	?gitHash:String
}

enum abstract UiTheme(String) from String to String {
	var Dark = "dark";
	var Light = "light";
}
