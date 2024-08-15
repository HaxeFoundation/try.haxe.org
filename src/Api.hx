import haxe.io.Path;
import haxe.remoting.Context;
import haxe.web.Dispatch;
import php.Lib;
import sys.FileSystem;
import sys.io.File;
import api.Compiler;
import api.Program.ProgramV2;
import template.Templates;

class Api {
	var program:api.Program.ProgramV2;
	var dir:String;

	public static var base:String;
	public static var root:String;
	public static var host:String;
	public static var protocol:String;

	public static final tryHaxeRootFolder = "/srv/try-haxe";
	public static final programsRootFolder = Path.join([tryHaxeRootFolder, "programs"]);
	public static final programsTempRootFolder = Path.join([tryHaxeRootFolder, "outTemp"]);
	public static final lixSetupRootFolder = Path.join([tryHaxeRootFolder, "lixSetup"]);

	public function new() {}

	public static function checkSanity(s:String) {
		var alphaNum = ~/[^a-zA-Z0-9]/;
		if (alphaNum.match(s))
			throw 'Unauthorized identifier : $s';
	}

	public static function checkLength(s:Null<String>, n:Int) {
		if (s == null)
			return;
		if (s.length > n)
			throw 'Unauthorized identifier : $s';
	}

	public static function checkDCE(s:String) {
		if (s != "full" && s != "no" && s != "std")
			throw 'Invalid dce : $s';
	}

	public function doCompiler() {
		var ctx = new Context();
		ctx.addObject("Compiler", new api.Compiler());
		if (haxe.remoting.HttpConnection.handleRequest(ctx))
			return;
	}

	public function doEmbed(uid:String) {
		var program = new api.Compiler().getProgram(uid);
		if (program != null) {
			var serverUrl = '$protocol//$host$base';
			var frameUrl = '$serverUrl/program/$uid/run?r=';
			var name = program.modules[0].name + ".hx";
			var name2 = program.modules[1].name + ".hx";
			var source = program.modules[0].source.htmlEscape();
			var source2 = program.modules[1].source.htmlEscape();
			var hideSource2Tab = (program.modules[1].source.length <= 0) ? "none" : "inline-block";
			var template = Templates.getCopy(Templates.MAIN_TEMPLATE);
			Lib.println(template);
		} else {
			var template = Templates.getCopy(Templates.ERROR_TEMPLATE);
			Lib.println(template);
		}
	}

	function notFound() {
		// Web.setReturnCode(404);
		php.Global.header("HTTP/1.1 " + "404 Not Found", true, 404);
	}

	public function doProgram(id:String, d:Dispatch) {
		checkSanity(id);
		dir = '$programsRootFolder/${id.substr(0, 2)}/$id';
		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
			ensureIndex(Path.join([dir, "index.html"]), id);
			d.dispatch({
				doRun: runProgram,
				doGet: getProgram
			});
		} else {
			notFound();
		}
	}

	public function runProgram() {
		var parts:Array<String> = dir.split("/");
		var id:String = parts.pop();
		var index = Path.join([dir, "index.html"]);
		ensureIndex(index, id);
		php.Lib.print(File.getContent(index));
	}

	function ensureIndex(index:String, id:String) {
		if (!FileSystem.exists(index)) {
			try {
				var program = new api.Compiler().getProgram(id);
				program.haxeVersion = "3.4.7";
				new api.Compiler().compile(program, Light);
			} catch (e:Any) {}
		}
	}

	public function getProgram() {
		php.Lib.print(File.getContent('$dir/program'));
	}

	public function doLoad(d:Dispatch) {
		var url = d.params.get('url');
		if (url == null) {
			throw "Url required";
		}
		var main = d.params.get('main');
		if (main == null) {
			main = "Test";
		} else {
			checkSanity(main);
		}
		var dce = d.params.get('dce');
		if (dce == null) {
			dce = "full";
		} else {
			checkDCE(dce);
		}

		var analyzer = d.params.get('analyzer');
		if (analyzer == null)
			analyzer = "yes";

		var uid = 'u' + haxe.crypto.Md5.encode(url);
		var compiler = new api.Compiler();

		var program:ProgramV2 = compiler.getProgram(uid);

		if (program == null) {
			var req = new haxe.Http(url);
			req.addHeader("User-Agent", "try.haxe.org (Haxe/PHP)");
			req.addHeader("Accept", "*/*");
			req.onError = function(m) {
				throw m;
			}
			req.onData = function(src) {
				var program:ProgramV2 = {
					uid: uid,
					editKey: null,
					mainClass: main,
					modules: [
						{
							name: main,
							source: src
						},
					],
					haxeVersion: Haxe_4_3_6,
					dce: dce,
					analyzer: analyzer,
					target: JS("test", ES6),
					libs: []
				}
				compiler.prepareProgram(program);
				redirectToProgram(program.uid);
			}
			req.request(false);
		} else {
			redirectToProgram(program.uid);
		}
	}

	function redirectToProgram(uid:String) {
		var tpl = '../redirect.html';
		var redirect = File.getContent(tpl);

		redirect = redirect.replace('__url__', '/#' + uid);
		php.Lib.print(redirect);
	}
}
