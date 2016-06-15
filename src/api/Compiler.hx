package api;

#if php
import api.Completion.CompletionResult;
import api.Completion.CompletionType;
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
	public static var dockerContainer = "nitrobin/haxe-minimal";

	public function new(){}

	static function checkMacros( s : String ){
		return;
		var forbidden = [
			~/@([^:]*):([\/*a-zA-Z\s]*)(macro|build|autoBuild|file|audio|bitmap|font)/,
			~/macro/
		];
		for( f in forbidden ) if( f.match( s ) ) throw "Unauthorized macro : "+f.matched(0)+"";
	}

	public function prepareProgram( program : Program ){

		while( program.uid == null ){

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
		Api.checkSanity( program.main.name );
		Api.checkDCE( program.dce );

		tmpDir = Api.tmp + "/" + program.uid + "/";

		if( !FileSystem.isDirectory( tmpDir )){
			FileSystem.createDirectory( tmpDir );
		}

		mainFile = tmpDir + program.main.name + ".hx";

		var source = program.main.source;
		checkMacros( source );

		File.saveContent( mainFile , source );

		var s = program.main.source;
		program.main.source = null;
		File.saveContent( tmpDir + "program", haxe.Serializer.run(program));
		program.main.source = s;

	}

	//public function getProgram(uid:String):{p:Program, o:Program.Output}
	public function getProgram(uid:String):Program
	{
		Api.checkSanity(uid);

		if (FileSystem.isDirectory( Api.tmp + "/" + uid ))
		{
			tmpDir = Api.tmp + "/" + uid + "/";

			var s = File.getContent(tmpDir + "program");
			var p:Program = haxe.Unserializer.run(s);

			mainFile = tmpDir + p.main.name + ".hx";

			p.main.source = File.getContent(mainFile);

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
	public function autocomplete( program : Program , idx : Int ) : CompletionResult{

		try{
			prepareProgram( program );
		}catch(err:String){
			return {};
		}

		var source = program.main.source;
		var display = program.main.name + ".hx@" + idx;

		var args = [
			"-main" , program.main.name,
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

		var out = runHaxeDocker( args );

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

			var words = [];
			for( e in xml.nodes.i ){
				var w = e.att.n;
				if( !words.has( w ) )
					words.push( w );

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
			"-main" , program.main.name,
			"--times",
			"-dce", program.dce
			//"--dead-code-elimination"
		];

		if (program.analyzer == "yes") args=args.concat(["-D", "analyzer"]);

		var outputPath : String;
		var htmlPath : String = tmpDir + "index.html";
		var runUrl = '${Api.base}/program/${program.uid}/run';
		var embedSrc = '<iframe src="http://${Api.host}${Api.base}/embed/${program.uid}" width="100%" height="300" frameborder="no" allowfullscreen>
	<a href="http://${Api.host}/#${program.uid}">Try Haxe !</a>
</iframe>';

		var html:HTMLConf = {head:[], body:[]};

		var isNeko:Bool = false;
		switch( program.target ){
			case JS( name ):
				Api.checkSanity( name );
				outputPath = tmpDir + name + ".js";
				args.push( "-js" );
				args.push( name + ".js" );
				html.body.push("<script src='//ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js'></script>");
				html.body.push("<script src='//markknol.github.io/console-log-viewer/console-log-viewer.js'></script>");
				html.body.push("<style type='text/css'>
					#debug_console {
						background:#fff;
						font-size:14px;
					}
					#debug_console font.log-normal {
						color:#000;
					}
					#debug_console a.log-button  {
						display:none;
					}
					</style>");

			case NEKO ( name ):
				Api.checkSanity( name );
				outputPath = tmpDir + name + ".n";
				args.push( "-neko" );
				args.push( name + ".n" );
				isNeko = true;

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

		var out = runHaxeDocker( args, isNeko );
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

	function runHaxeDocker ( args : Array<String>, isNeko:Bool = false ) {

		var abs = FileSystem.absolutePath(tmpDir);

		var docker = 'docker run --rm --read-only --tmpfs /run --tmpfs /tmp -v ${abs}:/root/program -w /root/program ${Compiler.dockerContainer} sh -c "';

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
			if(FileSystem.exists('$abs/$f')) {
				return sys.io.File.getContent('$abs/$f');
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

}
