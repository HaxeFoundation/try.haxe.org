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
	public var data:Array<Info> = [];

	public function new() {

	}

	public function getLintData(cm:CodeMirror, update:haxe.Constraints.Function, options:Dynamic) {
		update(data);
	}
    
	public function updateLinting(cm:CodeMirror):Void
	{
		untyped cm.performLint();
	}
	
}