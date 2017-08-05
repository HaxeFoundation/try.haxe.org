package ;
import js.codemirror.*;

typedef Info = {
	var from:CodeMirror.Pos;
	var to:CodeMirror.Pos;
	var message:String;
	var severity:String;
}

/**
 * ...
 * @author AS3Boyan
 */

//Ported from HIDE, adjusted for try-haxe
class HaxeLint
{
	public static var data2:Array<Info> = [];
	public var data:Array<Info> = [];

	public function new() {

	}

	public static function load():Void
	{
		return;
		CodeMirror.registerHelper("lint", "haxe", function (cm:CodeMirror) 
		{
			trace(cm);
			return data2;
		}
		);
	}

	public function getLintData(cm:CodeMirror, update:haxe.Constraints.Function, options:Dynamic) {
		if(data.length > 0) update(data);
	}
    
	public function updateLinting(cm:CodeMirror):Void
	{
		cm.setOption("lint", {
			getAnnotations: getLintData,
			async: true,	
		});
	}
	
}