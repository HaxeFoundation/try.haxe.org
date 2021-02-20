package api;

import haxe.remoting.Proxy;

typedef HTMLConf = {
	head:Array<String>,
	body:Array<String>
}

class RemoteCompilerProxy extends Proxy<api.Compiler> {}
