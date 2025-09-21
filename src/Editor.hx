import haxe.Exception;
import haxe.remoting.AsyncProxy;
import haxe.remoting.HttpAsyncConnection;
import js.Browser.document;
import js.Browser.window;
import js.Browser;
import js.Lib;
import js.codemirror.*;
import js.html.IFrameElement;
import js.jquery.*;
import api.Completion.CompletionItem;
import api.Completion.CompletionResult;
import api.Completion.CompletionType;
import api.Program;

using Lambda;
using haxe.EnumTools;

typedef EditorData = {
	nameElement:JQuery,
	codeMirror:CodeMirror,
	completionManager:Completion,
	colorPreview:ColorPreview,
	functionParametersHelper:FunctionParametersHelper,
	lint:HaxeLint,
}

class CompilerProxy extends AsyncProxy<api.Compiler> {}

class Editor {
	// min height to be bigger than the "options" tab, so it never has scrollbars
	// FIXME: measure
	static inline var MIN_HEIGHT = 525;

	static inline final THEME_STORAGE_KEY = "theme";
	static inline final DARK_THEME_CLASS = "dark-theme";

	var cnx:HttpAsyncConnection;

	var program:ProgramV2;
	var output:Output;
	var theme:UiTheme;

	var gateway:String;
	var apiRoot:String;

	var selectedJsVersion:ECMAScriptVersion;

	var form:JQuery;
	var haxeEditors:Array<EditorData> = [];
	var jsSource:CodeMirror;
	var runner:JQuery;
	var messages:JQuery;
	var formatBtn:JQuery;
	var compileBtn:JQuery;
	var libs:JQuery;
	var targets:JQuery;
	var jsVersion:JQuery;
	var mainName:JQuery;
	var dceName:JQuery;
	var analyzerName:JQuery;
	var haxeVersion:JQuery;
	var stage:JQuery;
	var outputTab:JQuery;
	var jsTab:JQuery;
	var embedTab:JQuery;
	var errorTab:JQuery;
	var errorDiv:JQuery;
	var compilerOutTab:JQuery;
	var compilerTimesTab:JQuery;
	var compilerOut:JQuery;
	var compilerTimes:JQuery;
	var embedSource:CodeMirror;
	var embedPreview:JQuery;

	var markers:Array<CodeMirror.MarkedText>;
	var lineHandles:Array<CodeMirror.LineHandle>;

	var completionIndex:Int;

	var functionParametersHelper:FunctionParametersHelper;
	var completionManager:Completion;

	var cnxCompiler:CompilerProxy;

	public function new() {
		markers = [];
		lineHandles = [];

		selectedJsVersion = ES6;

		// CodeMirror.commands.autocomplete = autocomplete;
		CodeMirror.commands.compile = function(_) compile();
		CodeMirror.commands.togglefullscreen = toggleFullscreenSource;

		functionParametersHelper = new FunctionParametersHelper();
		completionManager = new Completion();
		completionManager.registerHelper(functionParametersHelper);

		// HaxeLint.load();

		theme = Browser.getLocalStorage().getItem(THEME_STORAGE_KEY);

		addHaxeSource(new JQuery("input[name=module-a]"), cast new JQuery("textarea[name='hx-source']")[0]);
		addHaxeSource(new JQuery("input[name=module-b]"), cast new JQuery("textarea[name='hx-source2']")[0]);

		jsSource = CodeMirror.fromTextArea(cast new JQuery("textarea[name='js-source']")[0], {
			mode: "javascript",
			theme: getCodeTheme(),
			lineWrapping: true,
			lineNumbers: true,
			readOnly: true
		});

		embedSource = CodeMirror.fromTextArea(cast new JQuery("textarea[name='embed-source']")[0], {
			theme: getCodeTheme(),
			mode: "xml",
			htmlMode: true,
			lineWrapping: true,
			readOnly: true
		});

		switch (theme) {
			case Dark:
				toggleTheme();
			case Light:
			case _:
				theme = Light;
		}

		document.querySelector("#theme-toggle").addEventListener("click", event -> {
			toggleTheme();
			event.preventDefault();
			return false;
		});

		runner = new JQuery("iframe[name='js-run']");
		runner.on("load", function() {
			updateIframeThemes();
		});
		messages = new JQuery(".messages");
		formatBtn = new JQuery(".format-btn");
		compileBtn = new JQuery(".compile-btn");
		libs = new JQuery("#hx-options-form .hx-libs");
		targets = new JQuery("#hx-options-form .hx-targets");
		jsVersion = new JQuery("#hx-options-form .hx-js-es-version");
		stage = new JQuery(".js-output .js-canvas");
		outputTab = new JQuery("#output");
		jsTab = new JQuery("a[href='#js-source']");
		embedTab = new JQuery("a[href='#embed-source']");
		errorTab = new JQuery("a[href='#tab-errors']");
		errorDiv = new JQuery("#tab-errors");
		compilerOutTab = new JQuery("a[href='#compiler-output']");
		compilerTimesTab = new JQuery("a[href='#compiler-times']");
		compilerOut = new JQuery("#compiler-output");
		compilerTimes = new JQuery("#compiler-times");
		embedPreview = new JQuery("#embed-preview");
		mainName = new JQuery("#hx-options-form input[name='main']");
		dceName = new JQuery("#hx-options-form .hx-dce-name");
		analyzerName = new JQuery("#hx-options-form .hx-analyzer-name");
		haxeVersion = new JQuery("#hx-options-form .hx-haxe-ver");

		jsTab.hide();
		embedTab.hide();
		errorTab.hide();
		compilerOutTab.hide();
		compilerTimesTab.hide();

		new JQuery(".link-btn").click(function(e) {
			var _this = new JQuery(e.target);
			if (_this.attr('href') == "#") {
				e.preventDefault();
			}
		});

		new JQuery(".fullscreen-btn").click(toggleFullscreenRunner);
		new JQuery("a.hx-example").click(toggleExampleClick);

		new JQuery("body").keyup(onKey);

		new JQuery("a[data-toggle='tab']").on("shown.bs.tab", function(e) {
			jsSource.refresh();
			for (src in haxeEditors) {
				src.codeMirror.refresh();
			}
			embedSource.refresh();
		});

		dceName.on("change", "input[name='dce']", onDce);
		analyzerName.on("change", "input[name='analyzer']", onAnalyzer);
		targets.on("change", "input[name='target']", onTarget);
		jsVersion.on("change", "input[name='js-es']", onJsVersion);
		haxeVersion.on("change", "select", onHaxeVersion);

		formatBtn.click(formatCode);
		compileBtn.click(compile);

		apiRoot = new JQuery("body").data("api");
		cnx = HttpAsyncConnection.urlConnect(apiRoot + "/compiler");
		cnx.setErrorHandler(d -> trace(d));
		cnxCompiler = new CompilerProxy(cnx.resolve("Compiler"));

		program = {
			uid: null,
			editKey: null,
			mainClass: "Test",
			modules: [
				for (src in haxeEditors)
					{name: src.nameElement.val(), source: src.codeMirror.getValue()}
			],
			dce: "full",
			analyzer: "yes",
			haxeVersion: Haxe_4_3_6,
			target: JS("test", ES6),
			libs: new Array()
		};

		cnxCompiler.getHaxeVersions(function(versions:{stable:Array<api.Program.HaxeCompiler>, dev:Array<api.Program.HaxeCompiler>}) {
			var select = haxeVersion.find("select");
			select.empty();
			if (versions.stable.length > 0) {
				program.haxeVersion = versions.stable[0].dir;
			} else {
				program.haxeVersion = versions.dev[0].dir;
			}

			if (versions.stable.length > 0) {
				var stableElem = new JQuery('<optgroup>');
				stableElem.attr('label', "Stable releases");
				for (version in versions.stable) {
					stableElem.append('<option value="${version.dir}">${version.version}</option>');
				}
				select.append(stableElem);
			}

			if (versions.dev.length > 0) {
				var devElem = new JQuery('<optgroup>');
				devElem.attr('label', "Development releases");
				for (version in versions.dev) {
					devElem.append('<option value="${version.dir}">${version.version}</option>');
				}
				select.append(devElem);
			}
		});

		initLibs();

		setTarget(api.Program.TargetV2.JS("test", selectedJsVersion));

		var uid = window.location.hash;
		if (uid.length > 0) {
			uid = uid.substr(1);
			cnxCompiler.getProgram(uid, onProgram);
		}

		window.addEventListener('resize', resize);
		resize();
	}

	function isDarkTheme():Bool {
		return document.querySelector("html").classList.contains(DARK_THEME_CLASS);
	}

	function getCodeTheme():String {
		return isDarkTheme() ? "material-darker" : "default";
	}

	function toggleTheme() {
		final htmlTag = document.querySelector("html");
		var isDark = isDarkTheme();
		if (isDark) {
			htmlTag.classList.remove(DARK_THEME_CLASS);
		} else {
			htmlTag.classList.add(DARK_THEME_CLASS);
		}
		isDark = isDarkTheme();
		theme = isDark ? Dark : Light;
		Browser.getLocalStorage().setItem(THEME_STORAGE_KEY, theme);
		final text = isDark ? "Lighter" : "Darker";
		document.querySelector("#theme-toggle .theme-label").innerText = text;

		for (editor in haxeEditors) {
			editor.codeMirror.setOption("theme", getCodeTheme());
		}
		jsSource.setOption("theme", getCodeTheme());
		embedSource.setOption("theme", getCodeTheme());
		updateIframeThemes();
	}

	function updateIframeThemes():Void {
		updateIframeTheme(".js-run");
		updateIframeTheme(".embed-preview iframe");
	}

	function updateIframeTheme(selector:String):Void {
		final isDark = isDarkTheme();
		final iframe:IFrameElement = cast document.querySelector(selector);
		if (iframe == null || iframe.contentDocument == null) {
			return;
		}
		final iframeBody = iframe.contentDocument.querySelector("body");
		if (iframeBody == null) {
			return;
		}
		if (isDark) {
			iframeBody.classList.add(DARK_THEME_CLASS);
		} else {
			iframeBody.classList.remove(DARK_THEME_CLASS);
		}
		if (iframe.getAttribute("src") != "about:blank") {
			return;
		}
		final color = isDark ? "#111" : "#fff";
		iframeBody.style.backgroundColor = color;
	}

	function addHaxeSource(name:JQuery, elem) {
		var lint = new HaxeLint();

		var haxeSource = CodeMirror.fromTextArea(elem, {
			mode: "haxe",
			theme: getCodeTheme(),
			lineWrapping: true,
			lineNumbers: true,

			lint: {
				getAnnotations: lint.getLintData,
				async: true,
			},

			matchBrackets: true,
			autoCloseBrackets: true,
			gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter", "CodeMirror-lint-markers"],
			indentUnit: 2,
			tabSize: 2,
			keyMap: "sublime"
		});

		var colorPreview = new ColorPreview(haxeSource);

		var editorData = {
			nameElement: name,
			codeMirror: haxeSource,
			colorPreview: colorPreview,
			completionManager: completionManager,
			functionParametersHelper: functionParametersHelper,
			lint: lint,
		};

		haxeEditors.push(editorData);

		haxeSource.setOption("extraKeys", {
			"Ctrl-Space": function(cm:CodeMirror) autocomplete(editorData),
			"Ctrl-Enter": "compile",
			"F8": "compile",
			"F5": "compile",
			"F11": "togglefullscreen"
		});

		CodeMirror.commands.save = function(instance:CodeMirror) {
			formatCode();
			compile();
		};

		haxeSource.on("cursorActivity", function() {
			colorPreview.update(completionManager, haxeSource);
			functionParametersHelper.update(this, editorData);
		});

		haxeSource.on("scroll", function() {
			colorPreview.scroll(haxeSource);
		});

		haxeSource.on("change", onChange.bind(_, _, editorData));
	}

	function resize(?_) {
		// reset
		setHeight(10);

		var body = new JQuery(document.body);
		var main = new JQuery('.main');

		// window height - 160 - footer height
		var h = window.innerHeight - 160;
		h -= new JQuery('.foot').height();

		h = Math.max(h, MIN_HEIGHT);

		setHeight(Std.int(h));
	}

	function setHeight(h:Int) {
		for (src in haxeEditors) {
			src.codeMirror.getScrollerElement().style.height = h + 'px';
			src.codeMirror.getWrapperElement().style.height = h + 'px';
			src.codeMirror.refresh();
		}
		runner.height(h - 12);
	}

	function onDce(e:Event) {
		var cb = new JQuery(e.target);
		var name = cb.val();
		switch (name) {
			case "no", "full", "std":
				setDCE(name);
			default:
		}
	}

	function setDCE(dce:String) {
		program.dce = dce;
		var radio = new JQuery('input[name=\'dce\'][value=\'$dce\']');
		radio.attr("checked", "checked");
	}

	function onAnalyzer(e:Event) {
		var cb = new JQuery(e.target);
		var name = cb.val();
		switch (name) {
			case "no", "yes":
				setAnalyzer(name);
			default:
		}
	}

	function setAnalyzer(analyzer:String) {
		program.analyzer = analyzer;
		var radio = new JQuery('input[name=\'analyzer\'][value=\'$analyzer\']');
		radio.attr("checked", "checked");
	}

	function toggleExampleClick(e:Event) {
		var _this = new JQuery(e.target);
		var ajax = js.Syntax.code("$.ajax");
		ajax({
			url: 'examples/Example-${_this.data("value")}.hx',
			dataType: "text"
		}).done(function(data:String) {
			haxeEditors[0].nameElement.val("Test");
			haxeEditors[0].codeMirror.setValue(data);
			new JQuery("input[name='main']").val("Test");

			var requiredLibs:String = _this.data("libs");
			if ((requiredLibs == null) || (requiredLibs == "")) {
				return;
			}
			var sel:String = Type.enumConstructor(program.target);
			for (lib in requiredLibs.split(",")) {
				new JQuery('#hx-options .hx-libs .$sel-libs input[value="$lib"]').prop("checked", true);
			}
		});
		e.preventDefault();
	}

	function fullscreen() {
		js.Syntax.code("var el = window.document.documentElement;
            var rfs = el.requestFullScreen
                || el.webkitRequestFullScreen
                || el.mozRequestFullScreen;
			rfs.call(el); ");
	}

	function toggleFullscreenRunner(e:Event) {
		var _this = new JQuery(e.target);
		e.preventDefault();
		if (_this.attr('href') != "#") {
			new JQuery("body").addClass("fullscreen-runner");
			fullscreen();
		}
	}

	function toggleFullscreenSource(_) {
		new JQuery("body").toggleClass("fullscreen-source");
		for (src in haxeEditors) {
			src.codeMirror.refresh();
		}
		fullscreen();
	}

	function onTarget(e:Event) {
		var cb = new JQuery(e.target);
		var name = cb.val();
		var target = switch (name) {
			case "NEKO":
				api.Program.TargetV2.NEKO('test');
			case "HL":
				api.Program.TargetV2.HL('test');
			case "EVAL":
				api.Program.TargetV2.EVAL('test');
			case "CPPIA":
				api.Program.TargetV2.CPPIA('test');
			case _:
				api.Program.TargetV2.JS('test', selectedJsVersion);
		}

		setTarget(target);
	}

	function onJsVersion(e:Event) {
		var cb = new JQuery(e.target);
		var name = cb.val();

		selectedJsVersion = switch (name) {
			case "ES5":
				ES5;
			case _:
				ES6;
		}
		setTarget(JS("test", selectedJsVersion));
	}

	function setTarget(target:api.Program.TargetV2) {
		program.target = target;
		libs.find(".controls").hide();

		var sel:String = Type.enumConstructor(target);

		switch (target) {
			case JS(_, _):
				jsVersion.fadeIn();
			// jsTab.fadeIn();

			case NEKO(_) | HL(_) | EVAL(_) | CPPIA(_):
				jsVersion.hide();
				jsTab.hide();
		}

		var radio = new JQuery('input[name=\'target\'][value=\'$sel\']');
		radio.attr("checked", "checked");

		libs.find("." + sel + "-libs").fadeIn();

		for (lib in program.libs) {
			new JQuery('#hx-options .hx-libs .$sel-libs input[value="$lib"]').prop("checked", true);
		}
	}

	function onHaxeVersion(e:Event) {
		var opt = new JQuery(e.target);
		program.haxeVersion = opt.val();
	}

	function initLibs() {
		for (t in Type.getEnumConstructs(api.Program.Target)) {
			var el = libs.find("." + t + "-libs");
			var libs:Array<Libs.LibConf> = Libs.getLibsConfig(t);
			var def:Array<String> = Libs.getDefaultLibs(t);
			if (def == null)
				def = [];
			for (l in libs) {
				el.append('<div class="checkbox"><label><input class="lib" type="checkbox" value="${l.name}"'
					+ (Lambda.has(def, l.name) ? "checked='checked'" : "")
					+ ' /> ${l.name} '
					+ "<a href='"
					+ (l.help == null ? "http://lib.haxe.org/p/" + l.name : l.help)
					+ "' target='_blank'><i class='fa fa-question-circle'></i></a>"
					+ "</label></div>");
			}
		}
	}

	// function onProgram(p:{p:Program, o:Output})
	function onProgram(p:ProgramV2) {
		// trace(p);
		if (p != null) {
			// sharing
			// program = p.p;
			program = p;

			// auto-fork
			program.uid = null;

			for (i in 0...haxeEditors.length) {
				haxeEditors[i].nameElement.val(program.modules[i].name);
				haxeEditors[i].codeMirror.setValue(program.modules[i].source);
			}

			setTarget(program.target);
			setDCE(program.dce);
			setAnalyzer(program.analyzer);

			var versionElem = haxeVersion.find('select option[value="${program.haxeVersion}"]');
			if (versionElem.length == 0) {
				// The version has been removed, move the program to the latest stable version
				versionElem = haxeVersion.find('select option').first();
				program.haxeVersion = versionElem.val();
			}

			versionElem.prop('selected', true);

			if (program.libs != null) {
				for (lib in libs.find("input.lib")) {
					if (program.libs.has(new JQuery(lib).val())) {
						lib.setAttribute("checked", "checked");
					} else {
						lib.removeAttribute("checked");
					}
				}
			}

			mainName.val(program.mainClass);

			// if (p.o != null) onCompile(p.o);
		}
	}

	function saveCompletion(editorData:EditorData, comps:CompletionResult, onComplete:CodeMirror->CompletionResult->Void) {
		completionManager.completions = [];

		if (comps.list != null) {
			completionManager.completions = comps.list;
		}

		onComplete(editorData.codeMirror, comps);
	}

	public function getCompletion(editorData:EditorData, onComplete:CodeMirror->CompletionResult->Void, ?pos:CodeMirror.Pos,
			?targetCompletionType:CompletionType) {
		updateProgram();
		var cm = editorData.codeMirror;
		var src = cm.getValue();

		var completionType = CompletionType.DEFAULT;

		var cursorPos = pos;

		if (cursorPos == null) {
			cursorPos = cm.getCursor();
		}

		var idx = SourceTools.getAutocompleteIndex(src, cursorPos);

		if (idx == null) {
			// TODO: topLevel completion?
			idx = SourceTools.posToIndex(src, cm.getCursor());
			completionType = CompletionType.TOP_LEVEL;
		}

		// sometimes show incorrect result (time.getDate| change to value.length| -> completionIndex are equals)
		// if( idx == completionIndex && completions != null ){
		//   displayCompletions( cm , {list:completions} );
		//   return;
		// }
		completionIndex = idx;
		/*
			if( src.length > 1000 ){
			  program.main.source = src.substring( 0 , completionIndex+1 );
			}
		 */
		var module = program.modules.find(function(m) return m.name == editorData.nameElement.val());
		if (targetCompletionType == null) {
			cnxCompiler.autocomplete(program, module, idx, completionType, function(comps:CompletionResult) saveCompletion(editorData, comps, onComplete));
		} else if (targetCompletionType == completionType) {
			cnxCompiler.autocomplete(program, module, idx, completionType, function(comps:CompletionResult) saveCompletion(editorData, comps, onComplete));
		}
	}

	public function autocomplete(editorData:EditorData) {
		clearErrors(editorData);
		messages.fadeOut(0);
		getCompletion(editorData, displayCompletions);
	}

	//   function showHint( cm : CodeMirror ){
	//     var src = cm.getValue();
	//     var cursor = cm.getCursor();
	//     var from = SourceTools.indexToPos( src , SourceTools.getAutocompleteIndex( src, cursor ) );
	//     var to = cm.getCursor();
	//     var token = src.substring( SourceTools.posToIndex( src, from ) , SourceTools.posToIndex( src, to ) );
	//     var list = [];
	//     for( c in completions ){
	//       if( c.toLowerCase().startsWith( token.toLowerCase() ) ){
	//         list.push( c );
	//       }
	//     }
	//     return {
	//         list : list,
	//         from : from,
	//         to : to
	//     };
	//   }

	public function displayCompletions(cm:CodeMirror, comps:CompletionResult) {
		cm.execCommand("autocomplete");

		// if (comps.type != null) {
		//   trace(comps.type);
		//    var pos = cm.getCursor();
		//    var end = {line:pos.line, ch:pos.ch+comps.type.length};
		//    cm.replaceRange(comps.type, pos, pos);
		//    cm.setSelection(pos, end);
		// }
		if (comps.errors != null) {
			messages.html("<div class='alert alert-error'><h4 class='alert-heading'>Completion error</h4><div class='message'></div></div>");
			for (m in comps.errors) {
				messages.find(".message").append(new JQuery("<div>").text(m));
			}
			messages.fadeIn();
			markErrors(comps.errors);
		}
	}

	public function onKey(e:Event) {
		/*if( e.keyCode == 27 ){ // Escape
			new JQuery("body").removeClass("fullscreen-source fullscreen-runner");
		}*/
		if (e.keyCode == 122) {
			var b = new JQuery("body");
			if (b.hasClass("fullscreen-runner")) {
				b.removeClass("fullscreen-runner");
			}
		}
		if ((e.ctrlKey && e.keyCode == 13) || e.keyCode == 119) { // Ctrl+Enter and F8
			e.preventDefault();
			compile(e);
		}
	}

	public function onChange(cm:CodeMirror, e:js.codemirror.CodeMirror.ChangeEvent, editorData:EditorData) {
		var txt:String = e.text[0];

		if (txt.trim().endsWith(".") || txt.trim().endsWith("()")) {
			autocomplete(editorData);
		}
	}

	public function formatCode(?e) {
		if (e != null)
			e.preventDefault();
		for (i in 0...haxeEditors.length) {
			var cursorPos = haxeEditors[i].codeMirror.getCursor();
			haxeEditors[i].codeMirror.setValue(runFormatter(haxeEditors[i].codeMirror.getValue()));
			haxeEditors[i].codeMirror.setCursor(cursorPos);
		}
	}

	public function runFormatter(code:String) {
		try {
			switch formatter.Formatter.format(Code(code, Snippet), new formatter.config.Config(), null, TypeLevel) {
				case Success(formattedCode):
					return formattedCode;
				case Failure(_):
				case Disabled:
			}
		} catch (e:Exception) {}
		return code;
	}

	public function compile(?e) {
		if (e != null)
			e.preventDefault();
		messages.fadeOut(0);
		for (data in haxeEditors)
			clearErrors(data);
		untyped compileBtn.button('loading');
		updateProgram();
		cnxCompiler.compile(program, theme, onCompile);
	}

	function updateProgram() {
		for (i in 0...haxeEditors.length) {
			program.modules[i].name = haxeEditors[i].nameElement.val();
			program.modules[i].source = haxeEditors[i].codeMirror.getValue();
		}
		program.mainClass = mainName.val();
		program.dce = new JQuery('input[name=\'dce\']:checked').val();
		program.analyzer = new JQuery('input[name=\'analyzer\']:checked').val();

		var libs = new Array();
		var sel = Type.enumConstructor(program.target);
		var inputs = new JQuery("#hx-options .hx-libs ." + sel + "-libs input.lib:checked");
		// TODO: change libs array only then need
		for (i in inputs) // refill libs array, only checked libs
		{
			// var l:api.Program.Library = { name:i.attr("value"), checked:true };
			// var d = Std.string(i.data("args"));
			// if (d.length > 0) l.args = d.split("~");
			libs.push(new JQuery(i).val());
		}

		program.libs = libs;
	}

	public function run() {
		if (output.success) {
			var run = output.href;
			run = run.replace("/try-haxe/", "/");
			runner.attr("src", apiRoot + run + "?r=" + Std.string(Math.random()));
			final standalone = new JQuery(".link-btn, .fullscreen-btn");
			standalone.removeClass("disabled");
			var url = apiRoot + run + "?r=" + Std.string(Math.random());
			if (isDarkTheme())
				url += "&theme=dark";
			standalone.attr("href", url);
		} else {
			runner.attr("src", "about:blank");
			new JQuery(".link-btn, .fullscreen-btn").addClass("disabled").attr("href", "#");
		}
	}

	public function onCompile(o:Output) {
		// if(output == null) return;

		output = o;
		program.uid = output.uid;
		program.editKey = o.editKey;
		window.location.hash = "#" + output.uid;
		document.title = 'Try Haxe #${output.uid}';

		jsSource.setValue(output.source);
		embedSource.setValue(output.embed);
		embedPreview.html(output.embed);

		if (output.embed != "" && output.embed != null) {
			embedTab.show();
		} else {
			embedTab.hide();
		}

		var jsSourceElem = new JQuery(jsSource.getWrapperElement());
		var msgType:String = "";

		if (output.success) {
			msgType = "success";
			jsSourceElem.show();
			jsSource.refresh();
			stage.show();

			outputTab.show();
			untyped outputTab.tab("show");
			errorTab.hide();
			errorDiv.html("<pre></pre>");

			// var ifr=$('.js-run').get(0); console.log(ifr);var rfs = ifr.requestFullScreen || ifr.webkitRequestFullScreen || ifr.mozRequestFullScreen; rfs.call(ifr)
			switch (program.target) {
				case JS(_):
					jsTab.show();
				default:
					jsTab.hide();
			}
		} else {
			msgType = "error";
			jsTab.hide();
			jsSourceElem.hide();
			markErrors(output.errors);

			outputTab.hide();
			untyped errorTab.tab("show");
			errorTab.show();
			errorDiv.html("<pre>" + output.stderr.htmlEscape(true) + "</pre>");
		}

		messages.html("<div class='alert alert-" + msgType + "'><h4 class='alert-heading'>" + output.message.htmlEscape(true) + "</h4></div>");

		if (output.haxeout != null && output.haxeout.trim().length > 0) {
			compilerOutTab.show();
			compilerOut.html("<pre>" + output.haxeout.htmlEscape(true) + "</pre>");
		} else {
			compilerOutTab.hide();
			compilerOut.html("<pre></pre>");
		}
		if (output.times != null && output.times.trim().length > 0) {
			compilerTimesTab.show();
			compilerTimes.html("<pre>" + output.times.htmlEscape(true) + "</pre>");
		} else {
			compilerTimesTab.hide();
			compilerTimes.html("<pre></pre>");
		}

		messages.fadeIn();
		untyped compileBtn.button("reset");

		run();
	}

	public function clearErrors(editorData:EditorData) {
		editorData.lint.data = [];
		editorData.lint.updateLinting(editorData.codeMirror);
	}

	public function markErrors(errors:Array<String>) {
		var errLine = ~/([^:]*):([0-9]+): characters ([0-9]+)-([0-9]+) :(.*)/g;

		var errorMap:Map<String, Array<HaxeLint.Info>> = new Map();

		for (e in errors) {
			if (errLine.match(e)) {
				var err = {
					file: errLine.matched(1),
					line: Std.parseInt(errLine.matched(2)) - 1,
					from: Std.parseInt(errLine.matched(3)),
					to: Std.parseInt(errLine.matched(4)),
					msg: errLine.matched(5)
				};

				var file = err.file.trim();
				file = file.substring(0, file.lastIndexOf("."));
				var data = errorMap.exists(file) ? errorMap.get(file) : {var a = []; errorMap.set(file, a); a;};

				data.push({
					from: {line: err.line, ch: err.from},
					to: {line: err.line, ch: err.to},
					message: err.msg,
					severity: "error"
				});
			}
		}

		for (key in errorMap.keys()) {
			var editorData = haxeEditors.find(function(data) return data.nameElement.val() == key);
			if (editorData != null) {
				editorData.lint.data = errorMap.get(key);
				editorData.lint.updateLinting(editorData.codeMirror);
			}
		}
	}
}
