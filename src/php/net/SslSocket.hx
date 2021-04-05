/*
 * Copyright (C)2005-2019 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package php.net;

import php.Const;
import php.Global;
import php.Lib;
import sys.net.Host;

class SslSocket extends php.net.Socket {
	public function new():Void {
		super();
		protocol = "ssl";
	}

	override public function connect(host:Host, port:Int):Void {
		var errs = null;
		var errn = null;
		var ctx = untyped stream_context_create(Lib.associativeArrayOfHash([
			"ssl" => Lib.associativeArrayOfHash(["verify_peer" => false, "verify_peer_name" => false])
		]));
		var r = Global.stream_socket_client(protocol + '://' + host.host + ':' + port, errn, errs, Std.parseFloat(Global.ini_get("default_socket_timeout")),
			Const.STREAM_CLIENT_CONNECT, ctx);
		Socket.checkError(r, errn, errs);
		__s = r;
		assignHandler();
	}
}
