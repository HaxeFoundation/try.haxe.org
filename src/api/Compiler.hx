package api;

#if php
import api.Completion.CompletionResult;
import api.Completion.CompletionType;
import api.Completion.CompletionItem;
import php.Web;
import Sys;
import php.Lib;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;
using Lambda;

typedef HTMLConf =
{
	head:Array<String>,
	body:Array<String>
}

class Compiler {

	var tmpDir : String;
	var mainFile : String;
	public static var haxePath = "haxe";
	public static var dockerContainer = "thecodec/haxe-3.3.0.slim";

	public function new(){}

	static function checkMacros( s : String ){
		return;
		var forbidden = [
			~/@([^:]*):([\/*a-zA-Z\s]*)(macro|build|autoBuild|file|audio|bitmap|font)/,
			~/macro/
		];
		for( f in forbidden ) if( f.match( s ) ) throw "Unauthorized macro : "+f.matched(0)+"";
	}

	public function prepareProgram( program : Program ) {

		while( program.uid == null ) {

			var id = haxe.crypto.Md5.encode( Std.string( Math.random() ) +Std.string( Date.now().getTime() ) );
			id = id.substr(0, 5);
			var uid = "";
			for (i in 0...id.length) uid += if (Math.random() > 0.5) id.charAt(i).toUpperCase() else id.charAt(i);

			var tmpDir = Api.tmp + '/$uid/';
			if( !(FileSystem.exists( tmpDir )) ){
				program.uid = uid;
			}
		}

		Api.checkSanity( program.uid );
		Api.checkSanity( program.mainClass );
		Api.checkDCE( program.dce );

		tmpDir = Api.tmp + "/" + program.uid + "/";

		if( !FileSystem.isDirectory( tmpDir )){
			FileSystem.createDirectory( tmpDir );
		}

		for(name in FileSystem.readDirectory(tmpDir)) {
			var path = tmpDir + name;
			if(!FileSystem.exists(path)) {
				throw 'Path does not exist ${path}';
			}
			if(FileSystem.isDirectory(path)) {
				FileSystem.deleteDirectory(path);
			} else {
				FileSystem.deleteFile(path);
			}
		}

		for(module in program.modules) {
			Api.checkSanity(module.name);
			var file = tmpDir + module.name + ".hx";
			var src  = module.source;
			checkMacros(src);
			File.saveContent( file , src );
		}

		var s = program.modules.copy();
		for(module in program.modules) module.source = null;
		File.saveContent( tmpDir + "program", haxe.Serializer.run(program));
		program.modules = s;

	}

	//public function getProgram(uid:String):{p:Program, o:Program.Output}
	public function getProgram(uid:String):Program
	{
		Api.checkSanity(uid);

		if (FileSystem.isDirectory( Api.tmp + "/" + uid ))
		{
			tmpDir = Api.tmp + "/" + uid + "/";


			// if we don't find a program to unserialize return null
			var s = null;
			try {
				s = File.getContent(tmpDir + "program");
			} catch(e:Dynamic) {
				return null;
			}

			s = File.getContent(tmpDir + "program");

			var p:Program = haxe.Unserializer.run(s);


			if(p.mainClass == null) {
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
					 {name: old.main.name, source: null},
					 {name: "Macro", source: null},
					]
				}

			}

			for(module in p.modules) {
				var file = tmpDir + module.name + ".hx";
				try {
					module.source = File.getContent(file);
				} catch(e:Dynamic) {
					module.source = "// empty";
				}


			}

			/*
			var o:Program.Output = null;

			var htmlPath : String = tmpDir + "/" + "index.html";

			if (FileSystem.exists(htmlPath))
			{
				var runUrl = Api.base + "/program/"+p.uid+"/run";
				o = {
					uid : p.uid,
					stderr : null,
					stdout : "",
					args : [],
					errors : [],
					success : true,
					message : "Build success!",
					href : runUrl,
					source : ""
				}

				switch (p.target) {
					case JS(name):
					var outputPath = tmpDir + "/" + name + ".js";
					o.source = File.getContent(outputPath);
					default:
				}
			}
			*/
			//return {p:p, o:o};
			return p;
		}

		return null;
	}

	// TODO: topLevel competion
	public function autocomplete( program : Program , module:Program.Module, idx : Int, completionType:CompletionType ) : CompletionResult{

		try{
			prepareProgram( program );
		}catch(err:String){
			return {};
		}

		var source = module.source;
		var display = module.name + ".hx@" + idx;
		
		if (completionType == CompletionType.TOP_LEVEL)
		{
			display += "@toplevel";
		}
		
		var args = [
			"-main" , program.mainClass,
			"-v",
			"--display" , display
		];

		switch (program.target) {
			case JS(_):
				args.push("-js");
				args.push("dummy.js");

			case SWF(_, version):
				args.push("-swf");
				args.push("dummy.swf");
				args.push("-swf-version");
				args.push(Std.string(version));

			case NEKO(_):
				args.push("-neko");
				args.push("dummy.n");
		}

		addLibs(args, program);

		var out = runHaxeDocker( program, args );

		try{
			var xml = new haxe.xml.Fast( Xml.parse( out.err ).firstChild() );

			if (xml.name == "type") {
				var res = xml.innerData.trim().htmlUnescape();
				res = res.replace(" ->", ",");
				if (res == "Dynamic") res = ""; // empty enum ctor completion
				var pos = res.lastIndexOf(","); // result type
				res = if (pos != -1) res.substr(0, pos) else "";
				if (res == "Void") res = ""; // no args methods

				return {type:res};
			}

			var words:Array<CompletionItem> = [];
			
			if (completionType == CompletionType.DEFAULT)
			{
				for( e in xml.nodes.i ){
					var w:CompletionItem = {n: e.att.n, d: ""};
					
					if (e.hasNode.t)
					{
						w.t = e.node.t.innerData;
						//w.d = w.t + "<br/>";
					}
					
					if (e.hasNode.d)
					{
						w.d += e.node.d.innerData;
					}
					
					if( !words.has( w ) )
						words.push( w );

				}
			}
			else if (completionType == CompletionType.TOP_LEVEL)
			{
				for (e in xml.nodes.i) {
					var w:CompletionItem = {n: e.innerData};
					
					var elements = [];
					
					if (e.has.k)
					{
						w.k = e.att.k;
						elements.push(w.k);
					}
					
					if (e.has.p)
					{
						elements.push(e.att.p);
					}
					else if (e.has.t)
					{
						w.t = e.att.t;
						elements.push(w.t);
					}
					
					w.d = elements.join(" ");
					
					if (!words.has(w))
					{
						words.push(w);
					}
				}
			}
			
			return {list:words};

		}catch(e:Dynamic){

		}

		return {errors:SourceTools.splitLines(out.err.replace(tmpDir, ""))};

	}

	function addLibs(args:Array<String>, program:Program, ?html:HTMLConf)
	{
		var availableLibs = Libs.getLibsConfig(program.target);
		for( l in availableLibs ){
			if( program.libs.has( l.name ) ){
				if (html != null)
				{
					if (l.head != null) html.head = html.head.concat(l.head);
					if (l.body != null) html.body = html.body.concat(l.body);
				}
				if (l.swf != null)
				{
					args.push("-swf-lib");
					args.push("../../lib/swf/" + l.swf.src);
				}
				else
				{
					args.push("-lib");
					args.push(l.name);
				}
				if( l.args != null )
					for( a in l.args ){
						args.push(a);
					}
			}
		}

	}

	public function compile( program : Program ){
		try{
			prepareProgram( program );
		}catch(err:String){
			return {
				uid : program.uid,
				args : [],
				stderr : err,
				stdout : "",
				errors : [err],
				success : false,
				message : "Build failure",
				href : "",
				source : "",
				embed : ""
			}
		}

		var args = [
			"-main" , program.mainClass,
			"--times",
			"-D", "macro-times",
			"-dce", program.dce
		];

		if (program.analyzer == "yes") args=args.concat(["-D", "analyzer-optimize", "-D", "analyzer"]);

		var outputPath : String;
		var htmlPath : String = tmpDir + "index.html";
		var runUrl = '${Api.base}/program/${program.uid}/run';
		var embedSrc = '<iframe src="//${Api.host}${Api.base}/embed/${program.uid}" width="100%" height="300" frameborder="no" allowfullscreen>
	<a href="//${Api.host}/#${program.uid}">Try Haxe !</a>
</iframe>';

		var html:HTMLConf = {head:[], body:[]};

		switch( program.target ){
			case JS( name ):
				Api.checkSanity( name );
				outputPath = tmpDir + name + ".js";
				args.push( "-js" );
				args.push( name + ".js" );
				html.body.push("<script src='//ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js'></script>");
				html.body.push("<script src='//markknol.github.io/console-log-viewer/console-log-viewer.js'></script>");
				html.head.push("<link rel='stylesheet' href='"+Api.root+"/console.css' type='text/css'>");

			case NEKO ( name ):
				Api.checkSanity( name );
				outputPath = tmpDir + name + ".n";
				args.push( "-neko" );
				args.push( name + ".n" );

			case SWF( name , version ):
				Api.checkSanity( name );
				outputPath = tmpDir + name + ".swf";

				args.push( "-swf" );
				args.push( name + ".swf" );
				args.push( "-swf-version" );
				args.push( Std.string( version ) );
				args.push("-debug");
				args.push("-D");
				args.push("advanced-telemetry"); // for Scout
				html.head.push("<link rel='stylesheet' href='"+Api.root+"/swf.css' type='text/css'/>");
				html.head.push("<script src='"+Api.root+"/lib/swfobject.js'></script>");
				html.head.push('<script type="text/javascript">swfobject.embedSWF("'+Api.base+"/"+outputPath+'?r='+Math.random()+'", "flashContent", "100%", "100%", "'+version+'.0.0" , null , {} , {wmode:"direct", scale:"noscale"})</script>');
				html.body.push('<div id="flashContent"><p><a href="http://www.adobe.com/go/getflashplayer"><img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash player" /></a></p></div>');
		}

		addLibs(args, program, html);
		//trace(args);

		var out = runHaxeDocker( program, args );
		var err = out.err.replace(tmpDir, "");
		var errors = SourceTools.splitLines(err);

		var output : Program.Output = if( out.exitCode == 0 ){
			{
				uid : program.uid,
				stderr : err,
				stdout : out.out,
				args : args,
				errors : [],
				haxeout: out.haxe_out,
				times: out.haxe_times,
				success : true,
				message : "Build success!",
				href : runUrl,
				embed : embedSrc,
				source : ""
			}
		}else{
			{
				uid : program.uid,
				stderr : err,
				stdout : out.out,
				args : args,
				errors : errors,
				haxeout: out.haxe_out,
				times: out.haxe_times,
				success : false,
				message : "Build failure",
				href : "",
				embed : "",
				source : ""
			}
		}

		if (out.exitCode == 0)
		{
			switch (program.target) {
				case JS(_):
					output.source = File.getContent(outputPath);
					html.body.push("<script>" + output.source + "</script>");
				case NEKO(_):
					html.body.push("<pre>"+out.out+"</pre>");
				default:
			}
			var h = new StringBuf();
			h.add("<html>\n\t<head>\n\t\t<title>Haxe Run</title>");
			for (i in html.head) { h.add("\n\t\t"); h.add(i); }
			h.add("\n\t</head>\n\t<body>");
			for (i in html.body) { h.add("\n\t\t"); h.add(i); }
			h.add('\n\t</body>\n</html>');

			File.saveContent(htmlPath, h.toString());
		}
		else
		{
			if (FileSystem.exists(htmlPath)) FileSystem.deleteFile(htmlPath);
		}

		return output;
	}

	function runHaxeDocker ( program:Program, args : Array<String> ) {

		var isNeko = program.target.match(NEKO(_));
		var programDir = FileSystem.absolutePath(tmpDir);
		var haxeDir = FileSystem.absolutePath(tmpDir+'../../haxe/versions/${program.haxeVersion}/');
		var haxelibDir =FileSystem.absolutePath(tmpDir+"../../haxe/haxelib");

		var mountDirs = '-v ${programDir}:/root/program -v ${haxelibDir}:/opt/haxelib:ro';

		if(FileSystem.exists(haxeDir)) {
			mountDirs += ' -v ${haxeDir}:/opt/haxe:ro ';
		}

		var docker = 'docker run --rm --read-only --net none --tmpfs /run --tmpfs /tmp ${mountDirs} -w /root/program ${Compiler.dockerContainer} sh -c "';

		docker += "timeout -k 1s 1s haxe " + args.join(" ") + " > haxe_out 2> haxe_err";

		if(isNeko) {
			docker += ' && timeout -k 1s 1s neko test.n > raw_out 2> raw_err';
		}

		docker += "\"";

		var proc = new sys.io.Process( docker , null );

		var exit = proc.exitCode();

		var out = "";
		var err = "";

		inline function r(f:String) {
			if(FileSystem.exists('$programDir/$f')) {
				var s = sys.io.File.getContent('$programDir/$f');

				try {
					FileSystem.deleteFile('$programDir/$f');
				} catch(e:Dynamic) {

				}
				
				return s;
			}
			return "";
		}

		// contains haxe macro traces
		var haxe_out = r('haxe_out');
		// contains compilation errors, $type() and times
		var haxe_err = r('haxe_err');
		// contains program output
		var raw_out = r('raw_out');
		// contains program errors
		var raw_err = r('raw_err');

		var skipHaxeOut = false;
		if(exit != 0) {
			if(exit == 124) {
				err += haxe_err.length > 0 ? "Program execution timeout." : "Haxe compilation failed.";
				err += '\n';
				skipHaxeOut = true;
			}
		}

		err += raw_err;

		var times_pos = haxe_err.indexOf("Total time");
		var haxe_times = "";

		if(times_pos == -1) {
			times_pos = haxe_err.indexOf("time(s)");
			if(times_pos > -1) {
				while(true) {
					times_pos--;
					if(haxe_err.charAt(times_pos) == '\n' || haxe_err.charAt(times_pos) == "" || times_pos <= 0) {
						break;
					}
				}
			}
		}

		// if we have times let's dump them into another variable
		if(times_pos > -1) {
			haxe_times = haxe_err.substring(times_pos);
			haxe_out = haxe_err.substring(0, times_pos) + "\n" + haxe_out;
		} else {
			err += haxe_err;
		}

		// if the compilation timeout it's probably because some infinite loop, clear the compier output
		if(skipHaxeOut) haxe_out = "";

		if(isNeko) {
			out += raw_out;
			try {
				FileSystem.deleteFile('$programDir/test.n');
			} catch(e:Dynamic) {

			}
		}

		var o = {
			proc : proc,
			exitCode : exit,
			haxe_out: haxe_out,
			haxe_times: haxe_times,
			out : out,
			err : err
		};

		return o;

	}

	function runHaxe( args : Array<String> ){

		var proc = new sys.io.Process( haxePath , args );

		var exit = proc.exitCode();
		var out = proc.stdout.readAll().toString();
		var err = proc.stderr.readAll().toString();

		var o = {
			proc : proc,
			exitCode : exit,
			out : out,
			err : err
		};

		return o;

	}

	public function getHaxeVersions():{stable:Array<Program.HaxeCompiler>, dev:Array<Program.HaxeCompiler>} {
		var dir = '../haxe/versions/';
		var stableVersions:Array<Program.HaxeCompiler> = [];
		var devVersions:Array<Program.HaxeCompiler> = [];
		if(FileSystem.exists(dir)) {
			for(name in FileSystem.readDirectory(dir)) {
				var path = dir + name;
				if(!FileSystem.isDirectory(path) || !FileSystem.exists('$path/haxe')) continue;

				var version = name.replace("haxe-", "").replace("haxe_", "");

				var data = {
					dir: name,
					version: version,
				};

				//if semver can be parsed it's a stable release
				try {
					(version:thx.semver.Version);
					stableVersions.push(data);
				} catch(e:Dynamic) {
					devVersions.push(data);
				}
			}
		}

		stableVersions.sort(function(a, b) {
			return (a.version:thx.semver.Version) > (b.version:thx.semver.Version) ? -1 : 1;
		});

		return {stable: stableVersions, dev: devVersions};
	}

}
