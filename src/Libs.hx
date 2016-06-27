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

	static var thx:Array<LibConf> = [
		{name:"thx.core"},
		{name:"thx.color"},
		{name:"thx.promise"},
		{name:"thx.stream"},
		{name:"thx.culture"},
		{name:"thx.stream.dom"},
		{name:"thx.benchmark"},
		{name:"thx.csv"},
		{name:"thx.text"},
	];

	static var tink:Array<LibConf> = [
		{name:"tink_core"},
		{name:"tink_macro"},
		{name:"tink_priority"},
		{name:"tink_lang"},
		{name:"tink_xml"},
		{name:"tink_template"},
		{name:"tink_concurrent"},
		{name:"tink_streams"},
		{name:"tink_io"},
		{name:"tink_runloop"},
		{name:"tink_tcp"},
		{name:"tink_http"},
		{name:"tink_url"},
		{name:"tink_parse"},
		{name:"tink_json"},
		{name:"tink_clone"},
		{name:"tink_await"},
		{name:"tink_web"},
		{name:"futurize"},
	];

	static var available : Map<String, Array<LibConf>> = [
		"JS" => [
			{name:"actuate"},
			{name:"format" },
			{name:"hscript" },
			{name:"nape" },
			{name:"minject" },
			{name:"msignal" },
			{name:"polygonal-ds" },
			{name:"hxparse" },
			{name:"hxtemplo" },
			{name:"promhx" },
			{name:"dots" },
			{name:"slambda" },
		].concat(thx).concat(tink),
		"SWF" => [
			{name:"actuate"},
			{name:"format" },
			{name:"hscript" },
			{name:"nape" },
			{name:"minject" },
			{name:"msignal" },
			{name:"polygonal-ds" },
			{name:"hxparse" },
			{name:"hxtemplo" },
			{name:"promhx" },
			{name:"slambda" },
		].concat(thx).concat(tink),
		"NEKO" => [
			{name:"format" },
			{name:"hscript" },
			{name:"minject" },
			{name:"msignal" },
			{name:"polygonal-ds" },
			{name:"hxparse" },
			{name:"hxtemplo" },
			{name:"promhx" },
			{name:"slambda" },
		].concat(thx).concat(tink),
	];

	static var defaultChecked : Map < String, Array<String> > = ["JS" => [], "SWF" => []]; // array of lib names


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
