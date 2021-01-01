import sys.FileSystem;

class HaxeDownloader {

  static var MAX_DEV = 10;
  static var DIR = 'www/haxe/versions';
  static var LATEST_URL = "http://hxbuilds.s3-website-us-east-1.amazonaws.com/builds/haxe/linux64/haxe_latest.tar.gz";

  public static function main() {

    try {
      run();
    } catch(e:Dynamic) {
      trace('RIP ${e}');
    }

  }

  static var currentVersions = null;

  static function run() {
    trace('Getting current installed versions');
    currentVersions = Utils.getHaxeVersions('${DIR}/');

    trace('Starting download');
    var downloader = new haxe.Http(LATEST_URL);

    var out = new haxe.io.BytesOutput();
    var progress = new ProgressOut(out, 0);

    downloader.cnxTimeout = 10;
    downloader.onError = function(error) {
      throw 'ERROR ${error}';
    }

    downloader.customRequest(false, progress);

    unpack(new haxe.io.BytesInput(out.getBytes()));

    /*
    return;

    downloader.onData = function(data) {
      if(data == null) return;
      trace('Download complete');
      var bytes = haxe.io.Bytes.ofString(data);
      unpack(new haxe.io.BytesInput(bytes));
    }
    downloader.request();
    */
  }

  static function unpack(input:haxe.io.Input) {
    var tar = new format.tgz.Reader(input);
    var content = tar.read();
    var folder = content.first().fileName;
    trace('Downloaded version ${folder}');

    if(FileSystem.exists('${DIR}/${folder}')) {
      trace('Already downloaded');
      return;
    }

    trace('Unpacking to ${DIR}/${folder}');

    try {
      for(entry in content.iterator()) {
        if(entry.data == null || entry.fileSize  == 0) {
          FileSystem.createDirectory('${DIR}/${entry.fileName}');
          continue;
        }
        sys.io.File.saveBytes('${DIR}/${entry.fileName}', entry.data);
      }

      var chmod = new sys.io.Process('chmod', ['+x', '${DIR}/${folder}/haxe', '${DIR}/${folder}/haxelib']);
      var exitCode = chmod.exitCode(true);
      if(exitCode == 0) {
        trace('Set executable permissions to haxe and haxelib');
      } else {
        throw ('Couldn\'t change permissions: ${exitCode}');
      }

    } catch(e:Dynamic) {
      trace('Something went wrong! ${e}');
      deleteDirRecursively('${DIR}/${folder}');
      return;
    }

    if(currentVersions.dev.length >= MAX_DEV) {
      trace('Removing the oldest dev version');
      deleteDirRecursively('${DIR}/${currentVersions.dev[currentVersions.dev.length - 1].dir}');
    }
  }

  static function deleteDirRecursively(path:String):Void {
    if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
      var entries = FileSystem.readDirectory(path);
      for (entry in entries) {
        var file = '${path}/${entry}';
        if (FileSystem.isDirectory(file)) {
          deleteDirRecursively(file);
          FileSystem.deleteDirectory(file);
        } else {
          FileSystem.deleteFile(file);
        }
      }
    }
  }

}

// Stole from haxelib https://github.com/HaxeFoundation/haxelib/blob/development/src/haxelib/client/Main.hx
class ProgressOut extends haxe.io.Output {

	var o : haxe.io.Output;
	var cur : Int;
	var startSize : Int;
	var max : Null<Int>;
	var start : Float;

	public function new(o, currentSize) {
		this.o = o;
		startSize = currentSize;
		cur = currentSize;
		start = haxe.Timer.stamp();
	}

	function report(n) {
		cur += n;
		if( max == null )
			Sys.print(cur+" bytes\r");
		else
			Sys.print(cur+"/"+max+" ("+Std.int((cur*100.0)/max)+"%)\r");
	}

	public override function writeByte(c) {
		o.writeByte(c);
		report(1);
	}

	public override function writeBytes(s,p,l) {
		var r = o.writeBytes(s,p,l);
		report(r);
		return r;
	}

	public override function close() {
		super.close();
		o.close();
		var time = haxe.Timer.stamp() - start;
		var downloadedBytes = cur - startSize;
		var speed = (downloadedBytes / time) / 1024;
		time = Std.int(time * 10) / 10;
		speed = Std.int(speed * 10) / 10;
		Sys.print("Download complete : "+downloadedBytes+" bytes in "+time+"s ("+speed+"KB/s)\n");
	}

	public override function prepare(m) {
		max = m + startSize;
	}

}
