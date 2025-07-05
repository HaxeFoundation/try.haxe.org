import haxe.Exception;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import api.Program;
import thx.semver.Version;

class Utils {
	static function readVersionJson(path:String) {
		if (!FileSystem.exists(path))
			return null;

		try {
			var data = File.getContent(path);
			var versionObj = Json.parse(data);
			return versionObj.published;
		} catch (e:Exception) {}
		return null;
	}

	public static function getHaxeVersions(dir:String):{stable:Array<HaxeCompiler>, dev:Array<HaxeCompiler>} {
		var stableVersions:Array<HaxeCompiler> = [];
		var devVersions:Array<HaxeCompiler> = [];
		if (FileSystem.exists(dir)) {
			for (name in FileSystem.readDirectory(dir)) {
				var path = Path.join([dir, name]);
				if (!FileSystem.isDirectory(path) || !FileSystem.exists('$path/haxe'))
					continue;

				var versionDate = readVersionJson('$path/version.json');

				var version = name;
				var data = {
					dir: name,
					version: version,
					gitHash: null
				};
				if (versionDate != null) {
					data.version = '$versionDate ($version)';
				}

				// if semver can be parsed it's a stable release
				try {
					(version : thx.semver.Version);
					stableVersions.push(data);
				} catch (e:Dynamic) {
					data.gitHash = version;
					devVersions.push(data);
				}
			}
		}

		stableVersions.sort(function(a, b) {
			return versionGreaterThan(a.version, b.version) ? -1 : 1;
		});

		devVersions.sort(function(a, b) {
			return ('${a.version}' > '${b.version}') ? -1 : 1;
		});

		return {stable: stableVersions, dev: devVersions};
	}

	@:access(thx.semver.Version)
	static function versionGreaterThan(a:Version, b:Version) {
		if (a.major != b.major)
			return a.major > b.major;
		if (a.minor != b.minor)
			return a.minor > b.minor;
		if (a.patch != b.patch)
			return a.patch > b.patch;

		if (a.hasPre && b.hasPre) {
			return Version.greaterThanIdentifiers((a : SemVer).pre, (b : SemVer).pre);
		}
		if (b.hasPre) {
			return true;
		}
		return false;
	}
}
