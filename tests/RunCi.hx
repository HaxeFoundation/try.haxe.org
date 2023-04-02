package;

import sys.FileSystem;
import sys.io.File;

using StringTools;

@:enum
abstract Target(String) from String to String {
	var Swf = "swf";
	var Js = "js";
	var Neko = "neko";
	var Cpp = "cpp";
	var Cs = "cs";
	var Java = "java";
	var Python = "python";
	var Hl = "hl";
	var Interp = "interp";
}

@:enum
abstract ExitCode(Int) from Int to Int {
	var Success = 0;
	var Failure = 1;

	@:from
	static function fromBool(b:Bool):ExitCode {
		return b ? ExitCode.Success : ExitCode.Failure;
	}

	@:to
	function toColor():Color {
		return (this == ExitCode.Success) ? Color.Green : Color.Red;
	}
}

@:enum
abstract Color(Int) {
	var None = 0;
	var Red = 31;
	var Green = 32;
}

class RunCi {
	static inline var EXAMPLES_DIR = "../www/examples/";
	static var examplesToSkip = [#if (haxe_ver < "4.2.0") "Example-23.hx" #end];
	static var exampleTargets = ["Example-20.hx" => Js];
	static var librariesForExamples = ["Example-22.hx" => ["utest"]];

	public static function main():Void {
		var target:Target = Sys.args()[0];
		if (target == null) {
			Sys.println("No TARGET defined. Defaulting to neko.");
			target = Target.Neko;
		}

		Sys.exit(getResult([buildExamples(target, Sys.args().slice(1))]));
	}

	static function shouldSkipExample(example:String, target:Target) {
		var supportedTarget = exampleTargets[example];
		if (!(supportedTarget == null || supportedTarget == target)) {
			return true;
		}
		return examplesToSkip.indexOf(example) >= 0;
	}

	static function buildExamples(target:Target, ?included:Array<String>):ExitCode {
		Sys.println("\nBuilding examples...\n");

		var examples = FileSystem.readDirectory(EXAMPLES_DIR).filter(function(f) {
			return f.endsWith(".hx") && !shouldSkipExample(f, target);
		});

		FileSystem.createDirectory("bin");

		var results = [for (example in examples) compile(example, target)];
		var successCount = results.filter(function(e) return e == ExitCode.Success).length;
		var totalCount = examples.length;
		var exitCode:ExitCode = !(successCount < totalCount);
		Sys.println("");
		printWithColor([for (i in 0...50) "-"].join(""), exitCode);
		printWithColor('$successCount/$totalCount examples built successfully.', exitCode);

		return exitCode;
	}

	static function compile(example:String, target:Target):ExitCode {
		var dir = "bin/" + getFileName(example);
		FileSystem.createDirectory(dir);

		// workaround for "Module [name] does not define type [name]"
		File.copy(EXAMPLES_DIR + example, '$dir/Test.hx');

		return runInDir(dir, function() {
			return hasExpectedResult(example, target, librariesForExamples[example]);
		});
	}

	inline static function getFlag(name:String) {
		#if haxe4
		return '--$name'; // -interp is not allowed
		#else
		return '-$name';
		#end
	}

	static function hasExpectedResult(file:String, target:Target, libraries:Null<Array<String>>):ExitCode {
		var args = [getFlag("main"), "Test", getFlag(target)];

		if (target != Interp) {
			args.push(target);
		}

		if (libraries != null) {
			for (lib in libraries) {
				args.push("-lib");
				args.push(lib);
			}
		}

		var result:ExitCode = Sys.command("haxe", args);

		if (result == ExitCode.Failure)
			printWithColor('Failed when building $file', Color.Red);
		return result;
	}

	static function getResult(results:Array<ExitCode>):ExitCode {
		for (result in results)
			if (result != ExitCode.Success)
				return ExitCode.Failure;
		return ExitCode.Success;
	}

	static function printWithColor(message:String, color:Color):Void {
		setColor(color);
		Sys.println(message);
		setColor(Color.None);
	}

	static function setColor(color:Color):Void {
		if (Sys.systemName() == "Linux") {
			var id = (color == Color.None) ? "" : ';$color';
			Sys.stderr().writeString("\033[0" + id + "m");
		}
	}

	static function runInDir(dir:String, func:Void->ExitCode):ExitCode {
		var oldCwd = Sys.getCwd();
		Sys.setCwd(dir);
		var result = func();
		Sys.setCwd(oldCwd);
		return result;
	}

	static function getFileName(file:String):String {
		var dotIndex = file.lastIndexOf(".");
		return file.substring(0, dotIndex);
	}
}
