package api;

typedef Program = {
	uid : String,
	mainClass : String,
	modules : Array<Module>,
	target : Target,
	libs:Array<String>,
	dce : String,
	analyzer : String,
}

typedef Module = {
	name : String,
	source : String
}

enum Target {
	JS( name : String );
	NEKO( name : String );
	SWF( name : String , ?version : Float );
}

typedef Output = {
	uid : String,
	stderr : String,
	stdout : String,
	args : Array<String>,
	errors : Array<String>,
	haxeout: String,
	times: String,
	success : Bool,
	message : String,
	href : String,
	source : String,
	embed : String
}
