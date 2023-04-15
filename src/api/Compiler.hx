package api;

import haxe.Exception;
import haxe.io.Path;
import api.Completion.CompletionItem;
import api.Completion.CompletionResult;
import api.Completion.CompletionType;
import api.Program.ProgramV2;
import api.Program.Target;
import api.Program.TargetV2;
import api.Program.UiTheme;
#if php
import haxe.remoting.HttpConnection;
import php.SuperGlobal._COOKIE;
import sys.FileSystem;
import sys.io.File;
import api.HTMLConf.RemoteCompilerProxy;
#end

class Compiler {
	var programFolder:String;
	var mainFile:String;

	public static var haxePath = "haxe";
	public static var dockerContainer = "try-haxe_compiler";

	public function new() {}

	static function checkMacros(s:String) {
		return;
		var forbidden = [
			~/@([^:]*):([\/*a-zA-Z\s]*)(macro|build|autoBuild|file|audio|bitmap|font)/,
			~/macro/
		];
		for (f in forbidden)
			if (f.match(s))
				throw "Unauthorized macro : " + f.matched(0) + "";
	}

	function correctHaxeVersion(version:String) {
		var versions = getHaxeVersions();
		for (v in versions.stable) {
			if (v.version == version) {
				return v.version;
			}
		}
		for (v in versions.dev) {
			if (v.gitHash == version) {
				return v.gitHash;
			}
		}
		return Haxe_4_1_5;
	}

	public function prepareProgram(program:ProgramV2) {
		while (program.uid == null) {
			var id = haxe.crypto.Md5.encode(Std.string(Math.random()) + Std.string(Date.now().getTime()));
			id = id.substr(0, 8);
			var uid = "";
			for (i in 0...id.length)
				uid += if (Math.random() > 0.5) id.charAt(i).toUpperCase() else id.charAt(i);

			var tmpDir = Path.join([Api.programsRootFolder, uid.substr(0, 2), uid]);
			if (!(FileSystem.exists(tmpDir))) {
				program.uid = uid;
			}
		}

		Api.checkSanity(program.uid);
		Api.checkSanity(program.mainClass);
		Api.checkDCE(program.dce);

		programFolder = Path.join([Api.programsRootFolder, program.uid.substr(0, 2), program.uid]);

		if (!FileSystem.isDirectory(programFolder)) {
			FileSystem.createDirectory(programFolder);
		}

		for (name in FileSystem.readDirectory(programFolder)) {
			var path = Path.join([programFolder, name]);
			if (!FileSystem.exists(path)) {
				throw 'Path does not exist ${path}';
			}
			if (FileSystem.isDirectory(path)) {
				FileSystem.deleteDirectory(path);
			} else {
				FileSystem.deleteFile(path);
			}
		}

		for (module in program.modules) {
			Api.checkSanity(module.name);
			var file = Path.join([programFolder, module.name + ".hx"]);
			var src = module.source;
			checkMacros(src);
			File.saveContent(file, src);
		}

		var s = program.modules.copy();
		for (module in program.modules)
			module.source = null;
		File.saveContent(Path.join([programFolder, "program"]), haxe.Serializer.run(program));
		program.modules = s;
	}

	// public function getProgram(uid:String):{p:Program, o:Program.Output}
	public function getProgram(uid:String):ProgramV2 {
		Api.checkSanity(uid);

		var folder = Path.join([Api.programsRootFolder, uid.substr(0, 2), uid]);
		if (FileSystem.isDirectory(folder)) {
			programFolder = folder;

			// if we don't find a program to unserialize return null
			var s = null;
			try {
				s = File.getContent(Path.join([programFolder, "program"]));
			} catch (e:Exception) {
				return null;
			}

			s = File.getContent(Path.join([programFolder, "program"]));

			var p:ProgramV2 = haxe.Unserializer.run(s);
			if ((p.target is Target)) {
				var target:Target = cast p.target;
				switch (target) {
					case JS(name):
						p.target = JS(name, ES6);
					case SWF(name, _):
						p.target = JS(name, ES6);
					case _:
				}
			}

			if (p.mainClass == null) {
				// old format!
				var old:Dynamic = haxe.Unserializer.run(s);
				p = {
					uid: old.uid,
					mainClass: old.main.name,
					target: old.target,
					libs: old.libs,
					haxeVersion: null,
					dce: old.dce,
					analyzer: old.analyzer,
					modules: [
						{
							name: old.main.name,
							source: null
						},
						{name: "Macro", source: null},
					]
				}
			}
			if ((p.haxeVersion == null) || (p.haxeVersion == "null")) {
				p.haxeVersion = Haxe_4_1_5;
			}

			for (module in p.modules) {
				var file = Path.join([programFolder, module.name + ".hx"]);
				try {
					module.source = File.getContent(file);
				} catch (e:Exception) {
					module.source = "// empty";
				}
			}

			return p;
		}

		return downloadOldSnippet(uid);
	}

	function downloadOldSnippet(uid:String) {
		try {
			var cnx:HttpConnection = HttpConnection.urlConnect("https://try.haxe.org/compiler");
			var cnxCompiler:RemoteCompilerProxy;
			cnxCompiler = new RemoteCompilerProxy(cnx.resolve("Compiler"));
			var oldProgram:Dynamic = cnxCompiler.getProgram(uid);
			var oldTarget:Target = cast oldProgram.target;
			var target:TargetV2 = switch (oldTarget) {
				case JS(name):
					JS(name, ES6);
				case SWF(name, _):
					JS(name, ES6);
				case NEKO(name):
					NEKO(name);
				case EVAL(name):
					EVAL(name);
				case HL(name):
					HL(name);
				case _:
					JS("test", ES6);
			}
			var program:ProgramV2 = {
				uid: uid,
				mainClass: oldProgram.main.name,
				modules: [
					oldProgram.main,
					{
						name: "Macro",
						source: ""
					}
				],
				target: target,
				haxeVersion: "3.4.7",
				libs: oldProgram.libs,
				dce: oldProgram.dce,
				analyzer: oldProgram.analyzer
			};
			programFolder = Path.join([Api.programsRootFolder, uid.substr(0, 2), uid]);
			FileSystem.createDirectory(programFolder);
			File.saveContent(Path.join([programFolder, "program"]), haxe.Serializer.run(program));
			for (module in program.modules) {
				var file = Path.join([programFolder, module.name + ".hx"]);
				try {
					File.saveContent(file, module.source);
				} catch (e:Exception) {}
			}

			return program;
		} catch (e:Exception) {}
		return null;
	}

	// TODO: topLevel competion
	public function autocomplete(program:ProgramV2, module:Program.Module, idx:Int, completionType:CompletionType):CompletionResult {
		try {
			prepareProgram(program);
		} catch (err:String) {
			return {};
		}

		var source = module.source;
		// var display = tmpDir + module.name + ".hx@" + idx;
		var display = Path.join(["/home/haxer/programs", program.uid, module.name + ".hx@" + idx]);
		// var display = module.name + ".hx@" + idx;

		if (completionType == CompletionType.TOP_LEVEL) {
			display += "@toplevel";
		}

		var args = ["-main", program.mainClass, "-cp", ".", "-v", "--display", display];

		switch (program.target) {
			case JS(_):
				args.push("-js");
				args.push("dummy.js");

			case NEKO(_):
				args.push("-neko");
				args.push("dummy.n");

			case HL(_):
				args.push("-hl");
				args.push("dummy.hl");

			case EVAL(_):
		}

		addLibs(args, program);

		var out = runHaxeDocker(program, args);

		try {
			var xml = new haxe.xml.Access(Xml.parse(out.err).firstChild());

			if (xml.name == "type") {
				var res = xml.innerData.trim().htmlUnescape();
				res = res.replace(" ->", ",");
				if (res == "Dynamic")
					res = ""; // empty enum ctor completion
				var pos = res.lastIndexOf(","); // result type
				res = if (pos != -1) res.substr(0, pos) else "";
				if (res == "Void")
					res = ""; // no args methods

				return {type: res};
			}

			var words:Array<CompletionItem> = [];

			if (xml.hasNode.i && !xml.nodes.i[0].has.n)
				completionType = CompletionType.TOP_LEVEL;

			if (completionType == CompletionType.DEFAULT) {
				for (e in xml.nodes.i) {
					var w:CompletionItem = {n: e.att.n, d: ""};

					if (e.hasNode.t) {
						w.t = e.node.t.innerData;
						// w.d = w.t + "<br/>";
					}

					if (e.hasNode.d) {
						w.d += e.node.d.innerData;
					}

					if (!words.contains(w))
						words.push(w);
				}
			} else if (completionType == CompletionType.TOP_LEVEL) {
				for (e in xml.nodes.i) {
					var w:CompletionItem = {n: e.innerData};

					var elements = [];

					if (e.has.k) {
						w.k = e.att.k;
						elements.push(w.k);
					}

					if (e.has.p) {
						elements.push(e.att.p);
					} else if (e.has.t) {
						w.t = e.att.t;
						elements.push(w.t);
					}

					w.d = elements.join(" ");

					if (!words.contains(w)) {
						words.push(w);
					}
				}
			}

			return {list: words};
		} catch (e:Exception) {}

		return {errors: SourceTools.splitLines(out.err.replace(programFolder, ""))};
	}

	function addLibs(args:Array<String>, program:ProgramV2, ?html:HTMLConf) {
		var availableLibs = Libs.getLibsConfig(program.target);
		for (l in availableLibs) {
			if (program.libs.contains(l.name)) {
				if (html != null) {
					if (l.head != null)
						html.head = html.head.concat(l.head);
					if (l.body != null)
						html.body = html.body.concat(l.body);
				}
				args.push("-lib");
				args.push(l.name);
				if (l.args != null)
					for (a in l.args) {
						args.push(a);
					}
			}
		}
	}

	public function compile(program:ProgramV2, uiTheme:UiTheme):Null<Dynamic> {
		// TODO investigate return type and proxy callback
		try {
			prepareProgram(program);
		} catch (err:String) {
			return {
				uid: program.uid,
				args: [],
				stderr: err,
				stdout: "",
				errors: [err],
				success: false,
				message: "Build failure",
				href: "",
				source: "",
				embed: ""
			}
		}
		if (programFolder.length <= 0) {
			throw '$program';
		}

		var args = ["-main", program.mainClass, "-cp", ".", "--times", "-D", "macro-times",];

		if (program.haxeVersion == Haxe_4_3_0)
			args = args.concat(["-D", "message-reporting=pretty", "-D", "no-color"]);
		else
			args = args.concat(["-D", "message.reporting=pretty", "-D", "message.no-color"]);

		if (!program.haxeVersion.startsWith("2")) {
			args.push("-dce");
			args.push(program.dce);
		}

		if (program.analyzer == "yes")
			args = args.concat(["-D", "analyzer-optimize", "-D", "analyzer"]);

		final isDark = (uiTheme == Dark);
		var outputPath:String;
		var htmlPath:String = Path.join([programFolder, "index.html"]);
		var runUrl = '${Api.base}/program/${program.uid}/run';
		var darkParam = isDark ? "?theme=dark" : "";
		var embedSrc = '<iframe src="${Api.protocol}//${Api.host}${Api.base}/embed/${program.uid}$darkParam" width="100%" height="300" frameborder="no" allow="fullscreen">
	<a href="${Api.protocol}//${Api.host}/#${program.uid}">Try Haxe !</a>
</iframe>';

		var html:HTMLConf = {head: [], body: []};

		addLibs(args, program, html);
		html.head.push("<link rel='stylesheet' href='" + Api.root + "/console.css?v2' type='text/css'>");

		switch (program.target) {
			case JS(name, version):
				Api.checkSanity(name);
				outputPath = Path.join([programFolder, "run.js"]);
				args.push("-js");
				args.push('run.js');
				switch (version) {
					case ES5:
						args.push("-D");
						args.push("js-es=5");
					case ES6:
						args.push("-D");
						args.push("js-es=6");
				}

				html.body.push("<script src='https://markknol.github.io/console-log-viewer/console-log-viewer.js'></script>");

			case NEKO(name):
				Api.checkSanity(name);
				outputPath = 'run.n';
				args.push("-neko");
				args.push(outputPath);

			case HL(name):
				Api.checkSanity(name);
				outputPath = 'run.hl';
				args.push("-hl");
				args.push(outputPath);

			case EVAL(name):
				Api.checkSanity(name);
				outputPath = "";
				args.push("--run");
				args.push(program.mainClass);
		}

		var out = runHaxeDocker(program, args);
		var err = cleanOutput(out.err);
		var errors = SourceTools.splitLines(err);

		var output:Program.Output = if (out.exitCode == 0) {
			{
				uid: program.uid,
				stderr: err,
				stdout: out.out,
				args: args,
				errors: [],
				haxeout: cleanOutput(out.haxe_out),
				times: out.haxe_times,
				success: true,
				message: "Build success!",
				href: runUrl,
				embed: embedSrc,
				source: ""
			}
		} else {
			{
				uid: program.uid,
				stderr: err,
				stdout: out.out,
				args: args,
				errors: errors,
				haxeout: cleanOutput(out.haxe_out),
				times: out.haxe_times,
				success: false,
				message: "Build failure",
				href: "",
				embed: "",
				source: ""
			}
		}

		if (out.exitCode == 0) {
			switch (program.target) {
				case JS(_):
					output.source = File.getContent(outputPath);
					html.body.push("<script>" + output.source.replace("</script", "&lt;/script") + "</script>");
				case NEKO(_) | HL(_) | EVAL(_):
					html.body.push("<div style='overflow:auto; height:100%; width: 100%;'><pre>" + out.out.htmlEscape(true) + "</pre></div>");
				default:
			}
			var h = new StringBuf();
			h.add('<html>\n\t<head>\n\t\t<title>Haxe Run</title>');
			for (i in html.head) {
				h.add("\n\t\t");
				h.add(i);
			}
			h.add("\n\t</head>\n\t<body>");
			for (i in html.body) {
				h.add("\n\t\t");
				h.add(i);
			}
			h.add('<script>\nif (location.search.includes("theme=dark")){\n');
			h.add('\tdocument.body.classList.add("dark-theme");\n}\n');
			h.add("else {\n");
			h.add('\tdocument.body.classList.remove("dark-theme");\n');
			h.add('}\n</script>');
			h.add('\n\t</body>\n</html>');

			File.saveContent(htmlPath, h.toString());
		} else {
			if (FileSystem.exists(htmlPath))
				FileSystem.deleteFile(htmlPath);
		}

		return output;
	}

	function cleanOutput(text:String) {
		return text.replace(programFolder, "")
			.replace(Api.programsRootFolder, "")
			.replace(Api.lixSetupRootFolder, "")
			.replace(Api.programsTempRootFolder, "")
			.replace("/home/haxer/haxe/haxe_libraries", "")
			.replace("/home/haxer/haxe", "")
			.replace("/home/haxer/programs", "");
	}

	function runHaxeDocker(program:ProgramV2, args:Array<String>) {
		var outDir = Path.join([Api.programsTempRootFolder, program.uid]);

		prepareSnippetSources(programFolder, outDir);

		File.saveContent(Path.join([outDir, ".haxerc"]), '{"version": "${correctHaxeVersion(program.haxeVersion)}", "resolveLibs": "scoped"}');
		var docker = 'docker exec -u haxer $dockerContainer sh -c "cd /home/haxer/programs/${program.uid}; ';
		docker += " HAXE_LIBRARY_PATH=~/haxe/versions/"
			+ program.haxeVersion
			+ "/std timeout 2s haxe "
			+ args.join(" ")
			+ ' > haxe_out 2> haxe_err';

		switch (program.target) {
			case JS(_) | EVAL(_):
			case NEKO(_):
				docker += ' && timeout 1s neko run.n > raw_out 2> raw_err';
			case HL(_):
				docker += ' && LD_LIBRARY_PATH="/opt/hashlink:$$LD_LIBRARY_PATH" timeout 1s /opt/hashlink/hl run.hl > raw_out 2> raw_err';
		}
		docker += "\"";

		var proc = new sys.io.Process(docker, null);

		return processOutput(program, programFolder, outDir, proc.exitCode());
	}

	function processOutput(program:ProgramV2, programDir:String, outDir:String, exitCode:Int) {
		var out = "";
		var err = "";

		function saveOutputArtifacts(name:String) {
			var source:String = Path.join([outDir, name]);
			var dest:String = Path.join([programDir, name]);
			if (!FileSystem.exists(source)) {
				return;
			}
			try {
				File.saveBytes(dest, File.getBytes(source));
			} catch (e:Any) {}
		}
		saveOutputArtifacts("run.js");

		function readCompileOutput(name:String) {
			var source:String = Path.join([outDir, name]);
			if (FileSystem.exists(source)) {
				return sys.io.File.getContent(source);
			}
			return "";
		}

		// contains haxe macro traces
		var haxe_out = readCompileOutput('haxe_out');
		// contains compilation errors, $type() and times
		var haxe_err = readCompileOutput('haxe_err');
		// contains program output
		var raw_out = readCompileOutput('raw_out');
		// contains program errors
		var raw_err = readCompileOutput('raw_err');

		cleanupOutput(outDir);

		var skipHaxeOut = false;
		if (exitCode != 0) {
			if (exitCode == 124) {
				err += haxe_err.length > 0 ? "Program execution timeout." : "Haxe compilation failed.";
				err += '\n';
				skipHaxeOut = true;
			}
		}

		err += raw_err;

		var times_pos = haxe_err.indexOf("Total time");
		var haxe_times = "";

		if (times_pos == -1) {
			times_pos = haxe_err.indexOf("time(s)");
			if (times_pos > -1) {
				while (true) {
					times_pos--;
					if (haxe_err.charAt(times_pos) == '\n' || haxe_err.charAt(times_pos) == "" || times_pos <= 0) {
						break;
					}
				}
			}
		}

		// if we have times let's dump them into another variable
		if (times_pos > -1) {
			haxe_times = haxe_err.substring(times_pos);
			haxe_out = haxe_err.substring(0, times_pos) + "\n" + haxe_out;
		} else {
			err += haxe_err;
		}

		// if the compilation timeout it's probably because some infinite loop, clear the compier output
		if (skipHaxeOut)
			haxe_out = "";

		switch (program.target) {
			case JS(_):
			case NEKO(_) | HL(_):
				out += raw_out;
			case EVAL(_):
				out += haxe_out;
				haxe_out = "";
		}

		var o = {
			exitCode: exitCode,
			haxe_out: haxe_out,
			haxe_times: haxe_times,
			out: out,
			err: err
		};
		return o;
	}

	function prepareSnippetSources(snippetFolder:String, compileFolder:String) {
		function copySnippetToOutput(name:String) {
			var source:String = Path.join([snippetFolder, name]);
			var dest:String = Path.join([compileFolder, name]);
			if (!FileSystem.exists(source)) {
				return;
			}
			try {
				File.saveBytes(dest, File.getBytes(source));
			} catch (e:Any) {}
		}
		FileSystem.createDirectory(compileFolder);
		new sys.io.Process('chmod 777 $compileFolder', null);

		for (file in FileSystem.readDirectory(snippetFolder)) {
			if (Path.extension(file) == "hx") {
				copySnippetToOutput(file);
			}
		}
		var destHaxeLibraries:String = Path.join([compileFolder, "haxe_libraries"]);
		FileSystem.createDirectory(destHaxeLibraries);
		for (file in FileSystem.readDirectory(Path.join([Api.lixSetupRootFolder, "haxe_libraries"]))) {
			var source:String = Path.join([Api.lixSetupRootFolder, "haxe_libraries", file]);
			var dest:String = Path.join([destHaxeLibraries, file]);
			File.saveBytes(dest, File.getBytes(source));
		}
	}

	function cleanupOutput(outputFolder:String) {
		for (file in FileSystem.readDirectory(outputFolder)) {
			var path:String = Path.join([outputFolder, file]);
			if (FileSystem.isDirectory(path)) {
				cleanupOutput(path);
				continue;
			}
			try {
				FileSystem.deleteFile(path);
			} catch (e:Exception) {}
		}
		try {
			FileSystem.deleteDirectory(outputFolder);
		} catch (e:Exception) {}
	}

	public function getHaxeVersions():{stable:Array<Program.HaxeCompiler>, dev:Array<Program.HaxeCompiler>} {
		return Utils.getHaxeVersions(Path.join([Api.lixSetupRootFolder, "haxe", "versions"]));
	}
}
