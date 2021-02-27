import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class HostConfig {
	static inline final HOST_CONFIG = "hostConfig.json";

	public macro static function configureProtocol():ExprOf<String> {
		if (!FileSystem.exists(HOST_CONFIG)) {
			return macro "";
		}
		var content = File.getContent(HOST_CONFIG);
		var data:{protocol:String, host:String} = Json.parse(content);

		if ((data == null) || (data.protocol == null)) {
			return macro "";
		}
		return macro $v{data.protocol};
	}

	public macro static function configureHost():ExprOf<String> {
		if (!FileSystem.exists(HOST_CONFIG)) {
			return macro "";
		}
		var content = File.getContent(HOST_CONFIG);
		var data:{protocol:String, host:String} = Json.parse(content);

		if ((data == null) || (data.host == null)) {
			return macro "";
		}
		return macro $v{data.host};
	}
}
