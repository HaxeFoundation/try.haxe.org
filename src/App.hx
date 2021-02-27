import haxe.Exception;
#if php
import php.SuperGlobal;
import php.Web;
#end

class App {
	#if js
	public static function main() {
		new Editor();
	}
	#else
	public static function main() {
		try {
			var params = Web.getParams();
			var url = params.get('_url');
			params.remove('_url');

			if (params.exists('_root')) {
				Api.root = params.get('_root');
				Api.base = '${Api.root}';
			} else {
				var base:String = SuperGlobal._SERVER["SCRIPT_NAME"];
				var spl = base.split("/");
				spl.pop();

				Api.base = spl.join("/");
				spl.pop();
				Api.root = spl.join("/");

				// / is rewritten to /app
				Api.base = Api.root;
			}

			Api.host = HostConfig.configureHost();
			Api.protocol = HostConfig.configureProtocol();

			if (Api.host.length <= 0) {
				var host:String = SuperGlobal._SERVER["SERVER_NAME"];
				var port:String = SuperGlobal._SERVER["SERVER_PORT"];
				Api.host = '$host:$port';
				Api.protocol = "";
			}

			var origin = Web.getClientHeader('Origin');

			if (StringTools.endsWith(origin, 'try.haxe.org') || StringTools.endsWith(origin, 'localhost:8080')) {
				Web.setHeader('Access-Control-Allow-Origin', origin);
				Web.setHeader('Access-Control-Allow-Headers', 'X-Haxe-Remoting');
			}
			var api = new Api();
			haxe.web.Dispatch.run(url, params, api);
		} catch (e:Exception) {}
	}
	#end
}
