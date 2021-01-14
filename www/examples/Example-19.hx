class Test {
	static function main() {
		var http = new haxe.Http("https://api.ipify.org?format=json");
		http.onData = function(data) {
			var result:IpAddress = haxe.Json.parse(data);
			trace('Your IP-address: ${result.ip}');
		}
		http.onError = function(e) {
			trace(e);
		}
		http.request();
	}
}

typedef IpAddress = {ip:String}
