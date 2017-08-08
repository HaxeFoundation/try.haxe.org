import api.Program;
import sys.FileSystem;

using StringTools;

class Utils {

  public static inline function fixDirName(name:String) {
    return name.replace("haxe-", "").replace("haxe_", "");
  }

	public static function getHaxeVersions(dir:String):{stable:Array<HaxeCompiler>, dev:Array<HaxeCompiler>} {	
		var stableVersions:Array<HaxeCompiler> = [];
		var devVersions:Array<HaxeCompiler> = [];
		if(FileSystem.exists(dir)) {
			for(name in FileSystem.readDirectory(dir)) {
				var path = dir + name;
				if(!FileSystem.isDirectory(path) || !FileSystem.exists('$path/haxe')) continue;

				var version = fixDirName(name);

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

    inline function d(v:String) {
      var y = Std.parseInt(v.substr(0, 4));
      var M = Std.parseInt(v.substr(4, 2)) - 1;
      var d = Std.parseInt(v.substr(6, 2));
      var h = Std.parseInt(v.substr(8, 2));
      var m = Std.parseInt(v.substr(10, 2));
      var s = Std.parseInt(v.substr(12, 2));
      return new Date(y, M, d, h, m, s).getTime();
    }

    devVersions.sort(function(a, b) {
      return d(a.version) > d(b.version) ? -1 : 1;
    });

		return {stable: stableVersions, dev: devVersions};
	}

}