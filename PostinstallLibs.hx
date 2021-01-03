import haxe.io.Bytes;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

class PostinstallLibs {
    static function main() {
        copyFolder("node_modules/codemirror", "www/lib/codemirror");
        copyFolder("node_modules/bootstrap/dist", "www/lib/bootstrap");
        copyFile("node_modules/three/build/three.min.js", "www/lib/js/three.min.js");
        copyFile("node_modules/pixi.js/dist/pixi.min.js", "www/lib/js/pixi.min.js");
        copyFile("node_modules/stats.js/build/stats.min.js", "www/lib/js/stats.min.js");
    }

    static function copyFile(source:String, dest:String) {
#if debug
        trace ('copy $source to $dest');
#end
        var content:Bytes = File.getBytes(source);
        File.saveBytes(dest, content);
    }

    static function copyFolder(source:String, dest:String) {
#if debug
        trace ('copy folder $source to $dest');
#end
        if (!FileSystem.isDirectory(dest)){
            FileSystem.createDirectory(dest);
        }
        for (file in FileSystem.readDirectory(source)) {
            var srcPath:String = Path.join([source, file]);
            var destPath:String = Path.join([dest, file]);
            if (FileSystem.isDirectory(srcPath)) {
                copyFolder(srcPath, destPath);
            }
            else{
                copyFile (srcPath, destPath);
            }
        }
    }
}