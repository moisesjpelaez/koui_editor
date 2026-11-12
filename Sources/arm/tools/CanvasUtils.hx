package arm.tools;

import arm.data.CanvasSettings;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.events.SceneEvents;
import arm.canvas.CanvasElements;
import arm.canvas.CanvasLoader;
import arm.types.Types;

import haxe.Json;

import koui.Koui;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.GridLayout;
import koui.utils.RadioGroup;
import koui.utils.SceneManager;

// Loading, saving and pasting canvases, and loading the project's theme, fonts and images
class CanvasUtils {
	public static var canvasName: String = "UntitledCanvas";
	public static var projectDir: String = "";

	static var sceneData: SceneData = SceneData.data;

	/**
	 * Each ImagePanel's image name, saved instead of looking the image up:
	 * reloading replaces the image objects, and a missing image has none.
	 */
	static var imageNames: Map<ImagePanel, String> = new Map();

	// Reads the canvas name and project folder from the arguments blender.py passes
	public static function init(): Void {
		// [0] Krom, [1] assets, [2] shaders, [3] canvas name, [4] [5] resolution, [6] project folder
		var argCount: Int = Krom.getArgCount();

		if (argCount > 3) {
			var name: String = Krom.getArg(3);
			if (name != null && name != "" && !StringTools.startsWith(name, "--")) {
				canvasName = name;
			}
		}

		if (argCount > 6) {
			var dir: String = Krom.getArg(6);
			if (dir != null && dir != "" && !StringTools.startsWith(dir, "--")) {
				projectDir = StringTools.replace(dir, "/", "\\");
			}
		} else { // Started without arguments
			projectDir = StringTools.replace(Krom.getFilesLocation(), "/", "\\") + "/../../..";
		}
	}

	// The editor's own data folder (tools/<backend>/data), for its settings and scratch files
	public static function editorDataDir(): String {
		return Krom.getFilesLocation() + "/data";
	}

	public static function getCanvasPath(): String {
		return projectDir + "/Bundled/koui_canvas/" + canvasName + ".json";
	}

	// The name of the image `panel` shows, or would show if the project had it; "" for none
	public static function getImageName(panel: ImagePanel): String {
		var name: Null<String> = imageNames.get(panel);
		return name != null ? name : CanvasElements.getImageName(panel.image);
	}

	public static function setImageName(panel: ImagePanel, name: String): Void {
		imageNames.set(panel, name);
	}

	// Whether `panel` names an image the project doesn't have
	public static function isImageMissing(panel: ImagePanel): Bool {
		var name: String = getImageName(panel);
		return name != "" && Koui.getImage(name) == null;
	}

	public static function getCanvasDir(): String {
		return projectDir + "/Bundled/koui_canvas";
	}

	public static function ensureCanvasDir(): Void {
		var dir: String = getCanvasDir();
		var cmd: String = kha.System.systemId == "Windows"
			? 'cmd /c if not exist "' + StringTools.replace(dir, "/", "\\") + '" mkdir "' + StringTools.replace(dir, "/", "\\") + '"'
			: 'mkdir -p "' + dir + '"';
		Krom.sysCommand(cmd);
	}

	// Reloads the project's fonts, images and theme (Assets/koui_canvas/ui_override.ksn)
	public static function refreshTheme(): Void {
		var assetsPath: String = projectDir + "/Assets/koui_canvas/ui_override.ksn";
		var blob: js.lib.ArrayBuffer = Krom.loadBlob(assetsPath);

		if (blob != null) {
			var themeContent: String = haxe.io.Bytes.ofData(blob).toString();

			// The theme can use the fonts and images, so they load first
			loadAllFonts(function() {
				loadAllImages(function() {
					var error: String = koui.theme.RuntimeThemeLoader.parseAndApply(themeContent);

					// Panels show the reloaded images, including ones that were missing before
					for (panel => name in imageNames) {
						var image: kha.Image = name != "" ? Koui.getImage(name) : null;
						if (image != null) panel.image = image;
					}

					if (error != null) {
						trace('Theme reload ERROR: ${error}');
					}
				});
			});
		} else {
			trace('Theme file not found: ${assetsPath}');
		}
	}

	// The asset name Kha gives a file: no extension, and characters other than letters, digits and "_" become "_"
	static function normalizeAssetName(filename: String): String {
		var name: String = filename;
		var dotIdx: Int = name.lastIndexOf(".");
		if (dotIdx >= 0) {
			name = name.substring(0, dotIdx);
		}
		var result: StringBuf = new StringBuf();
		for (i in 0...name.length) {
			var c: String = name.charAt(i);
			if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
				result.add(c);
			} else {
				result.add('_');
			}
		}
		return result.toString();
	}

	// Loads the fonts in Assets/fonts into Koui.fontMap, by asset name, then calls `done`
	static function loadAllFonts(done: Void->Void): Void {
		var fontsDir: String = projectDir + "/Assets/fonts";
		if (kha.System.systemId == "Windows") {
			fontsDir = StringTools.replace(fontsDir, "/", "\\");
		}

		// Krom can't list a folder: a shell command writes the list to a file
		var listFile: String = editorDataDir() + "/_fontlist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			cmd = 'cmd /c dir /b "' + fontsDir + '\\*.ttf" "' + fontsDir + '\\*.otf" > "' + listFile + '" 2>nul';
		} else {
			cmd = 'ls -1 "' + fontsDir + '"/*.ttf "' + fontsDir + '"/*.otf > "' + listFile + '" 2>/dev/null || true';
		}

		Krom.sysCommand(cmd);

		var listBlob: js.lib.ArrayBuffer = Krom.loadBlob(listFile);
		if (listBlob == null) {
			done();
			return;
		}

		var listContent: String = haxe.io.Bytes.ofData(listBlob).toString();
		var fontFiles: Array<String> = [];

		for (line in listContent.split("\n")) {
			var trimmed: String = StringTools.trim(line);
			var lower: String = trimmed.toLowerCase();
			if (trimmed.length > 0 && (StringTools.endsWith(lower, ".ttf") || StringTools.endsWith(lower, ".otf"))) {
				// dir /b lists file names, ls full paths
				var filename: String = trimmed;
				var slashIdx: Int = Std.int(Math.max(filename.lastIndexOf("/"), filename.lastIndexOf("\\")));
				if (slashIdx >= 0) {
					filename = filename.substring(slashIdx + 1);
				}
				fontFiles.push(filename);
			}
		}

		if (fontFiles.length == 0) {
			done();
			return;
		}

		var remaining: Int = fontFiles.length;

		for (filename in fontFiles) {
			var assetName: String = normalizeAssetName(filename);
			var fontPath: String = fontsDir + (kha.System.systemId == "Windows" ? "\\" : "/") + filename;

			var name: String = assetName;
			kha.Assets.loadFontFromPath(fontPath, function(font: kha.Font) {
				if (font != null) {
					Koui.fontMap.set(name, font);
				} else {
					trace('Failed to load font: ${name}');
				}

				remaining--;
				if (remaining == 0) {
					done();
				}
			});
		}
	}

	// Loads the images in Assets and its subfolders into Koui.imageMap, by asset name, then calls `done`
	static function loadAllImages(done: Void->Void): Void {
		var assetsDir: String = projectDir + "/Assets";
		if (kha.System.systemId == "Windows") {
			assetsDir = StringTools.replace(assetsDir, "/", "\\");
		}

		var listFile: String = editorDataDir() + "/_imagelist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			cmd = 'cmd /c dir /b /s "' + assetsDir + '\\*.png" "' + assetsDir + '\\*.jpg" "' + assetsDir + '\\*.k" > "' + listFile + '" 2>nul';
		} else {
			cmd = 'find "' + assetsDir + '" -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.k" \\) > "' + listFile + '" 2>/dev/null || true';
		}

		Krom.sysCommand(cmd);

		var listBlob: js.lib.ArrayBuffer = Krom.loadBlob(listFile);
		if (listBlob == null) {
			done();
			return;
		}

		var listContent: String = haxe.io.Bytes.ofData(listBlob).toString();
		var imageFiles: Array<String> = []; // Relative to assetsDir

		var basePath: String = assetsDir + (kha.System.systemId == "Windows" ? "\\" : "/");
		var baseLen: Int = basePath.length;

		for (line in listContent.split("\n")) {
			var trimmed: String = StringTools.trim(line);
			if (trimmed.length > 0) {
				var lower: String = trimmed.toLowerCase();
				if (StringTools.endsWith(lower, ".png") || StringTools.endsWith(lower, ".jpg") || StringTools.endsWith(lower, ".k")) {
					var relativePath: String = trimmed;
					if (StringTools.startsWith(trimmed, basePath) || StringTools.startsWith(trimmed, assetsDir)) {
						relativePath = trimmed.substring(baseLen);
					}
					imageFiles.push(relativePath);
				}
			}
		}

		if (imageFiles.length == 0) {
			done();
			return;
		}

		var remaining: Int = imageFiles.length;

		for (filename in imageFiles) {
			// Kha names images by file name, without the folder
			var slashIdx: Int = Std.int(Math.max(filename.lastIndexOf("/"), filename.lastIndexOf("\\")));
			var justFilename: String = slashIdx >= 0 ? filename.substring(slashIdx + 1) : filename;
			var assetName: String = normalizeAssetName(justFilename);
			var imagePath: String = assetsDir + (kha.System.systemId == "Windows" ? "\\" : "/") + filename;

			var name: String = assetName;
			kha.Assets.loadImageFromPath(imagePath, false, function(image: kha.Image) {
				if (image != null) {
					Koui.imageMap.set(name, image);
				} else {
					trace('Failed to load image: ${name}');
				}

				remaining--;
				if (remaining == 0) {
					done();
				}
			});
		}
	}

	public static function saveCanvas(): Void {
		ensureCanvasDir();

		var path: String = getCanvasPath();
		var canvasData: TCanvasData = serializeCanvas();
		var jsonString: String = Json.stringify(canvasData, null, "\t");

		try {
			var bytes: haxe.io.Bytes = haxe.io.Bytes.ofString(jsonString);
			Krom.fileSaveBytes(path, bytes.getData());
			History.markSaved();
		} catch (e: Dynamic) {
			trace('Failed to save canvas: ${e}');
		}
	}

	// Loads the canvas file; if it can't be loaded, the current canvas stays
	public static function loadCanvas(): Void {
		var blob: js.lib.ArrayBuffer = Krom.loadBlob(getCanvasPath());
		if (blob == null) {
			trace('Canvas file not found: ${canvasName}');
			return;
		}

		try {
			var canvasData: TCanvasData = Json.parse(haxe.io.Bytes.ofData(blob).toString());
			deserializeCanvas(canvasData);
		} catch (e: Dynamic) {
			trace('Failed to load canvas "${canvasName}": ${e}');
			return;
		}
		History.reset();
		SceneEvents.canvasLoaded.emit();
	}

	public static function serializeCanvas(): TCanvasData {
		var scenesData: Array<TSceneData> = [];
		for (scene in sceneData.scenes) {
			scenesData.push(serializeScene(scene));
		}

		var currentRoot: AnchorPane = sceneData.currentScene != null ? sceneData.currentScene.root : null;
		var canvasWidth: Int = currentRoot != null ? currentRoot.width : 800;
		var canvasHeight: Int = currentRoot != null ? currentRoot.height : 600;

		return {
			name: canvasName,
			version: CanvasLoader.VERSION,
			canvas: {
				width: canvasWidth,
				height: canvasHeight,
				settings: {
					expandOnResize: CanvasSettings.expandOnResize,
					scaleOnResize: CanvasSettings.scaleOnResize,
					autoScale: CanvasSettings.autoScale,
					scaleHorizontal: CanvasSettings.scaleHorizontal,
					scaleVertical: CanvasSettings.scaleVertical
				}
			},
			radioGroups: serializeRadioGroups(),
			scenes: scenesData
		};
	}

	static function serializeScene(scene: TSceneEntry): TSceneData {
		var elementsData: Array<TElementData> = [];
		serializeChildren(scene.root, "", scene, true, elementsData);

		return {
			key: scene.key,
			active: scene == sceneData.currentScene,
			elements: elementsData
		};
	}

	static function serializeRadioGroups(): Array<TRadioGroupData> {
		return [for (group in sceneData.radioGroups) {
			id: group.id,
			activeButton: findElementRef(group.activeButton)
		}];
	}

	// Where `element` is in the canvas, or null if it is not in any scene
	static function findElementRef(element: Null<Element>): Null<TElementRef> {
		if (element == null) return null;
		for (scene in sceneData.scenes) {
			if (scene.keys.exists(element)) {
				return { scene: scene.key, path: CanvasLoader.getPath(element, scene.root, scene.keys) };
			}
		}
		return null;
	}

	// Serializes everything inside `parent`, parents before their children. `parentPath` is saved as the children's parent
	static function serializeChildren(parent: Element, parentPath: String, scene: TSceneEntry, withFocus: Bool, output: Array<TElementData>): Void {
		for (child in sceneData.getChildren(parent, scene)) {
			var elementData: Null<TElementData> = serializeElement(child, scene.keys.get(child), parentPath, scene, withFocus);
			if (elementData == null) continue;

			output.push(elementData);
			serializeChildren(child, CanvasLoader.joinPath(parentPath, elementData.key), scene, withFocus, output);
		}
	}

	// Null for a type a canvas can't contain; its children are skipped too
	static function serializeElement(element: Element, key: String, parentPath: String, scene: TSceneEntry, withFocus: Bool): Null<TElementData> {
		var type: Null<String> = CanvasElements.getType(element);
		if (type == null) {
			trace('Skipping element "${key}": canvases can not contain its type');
			return null;
		}

		var focusPath = function(target: Null<Element>): Null<String> {
			if (!withFocus || target == null || !scene.keys.exists(target)) return null;
			return CanvasLoader.getPath(target, scene.root, scene.keys);
		};

		var properties: Dynamic = CanvasElements.serializeProperties(element);
		if (type == "ImagePanel") properties.imageName = getImageName(cast element);

		return {
			key: key,
			type: type,
			tID: element.getTID(),
			posX: element.posX,
			posY: element.posY,
			width: element.width,
			height: element.height,
			anchor: cast element.anchor,
			visible: element.visible,
			disabled: element.disabled,
			parent: parentPath,
			focusUp: focusPath(element.focusUp),
			focusDown: focusPath(element.focusDown),
			focusLeft: focusPath(element.focusLeft),
			focusRight: focusPath(element.focusRight),
			properties: properties
		};
	}

	// Throws before changing anything if `canvasData` can't be loaded
	static function deserializeCanvas(canvasData: TCanvasData): Void {
		checkBuildable(canvasData);
		rebuildCanvas(canvasData, null);

		var reported: Array<String> = [];
		for (panel => name in imageNames) {
			if (!isImageMissing(panel) || reported.indexOf(name) >= 0) continue;
			reported.push(name);
			trace('Image "${name}" is not in the project; its name is kept when saving');
		}
	}

	// If `data` is an ImagePanel, remembers its image's name for saving
	static function rememberImageName(element: Null<Element>, data: TElementData): Void {
		if (element == null || data.type != "ImagePanel") return;
		imageNames.set(cast element, data.properties.imageName);
	}

	/**
	 * Replaces the canvas with `canvasData`, which must be valid, and shows the
	 * scene `sceneKey`, or the one saved as active if null. Used by loading and undo.
	 */
	public static function rebuildCanvas(canvasData: TCanvasData, sceneKey: Null<String>): Void {
		clearCanvas();

		CanvasSettings.expandOnResize = canvasData.canvas.settings.expandOnResize;
		CanvasSettings.scaleOnResize = canvasData.canvas.settings.scaleOnResize;
		CanvasSettings.autoScale = canvasData.canvas.settings.autoScale;
		CanvasSettings.scaleHorizontal = canvasData.canvas.settings.scaleHorizontal;
		CanvasSettings.scaleVertical = canvasData.canvas.settings.scaleVertical;

		// KouiEditor.onSceneAdded makes each scene's root
		var built: TBuiltCanvas = CanvasLoader.buildCanvas(canvasData, key -> {
			SceneEvents.sceneAdded.emit(key);
			return sceneData.currentScene.root;
		});
		for (builtScene in built.scenes) {
			var scene: TSceneEntry = sceneData.getScene(builtScene.key);
			for (element => key in builtScene.keys) sceneData.registerElement(element, key, scene);
		}
		for (sceneDataEntry in canvasData.scenes) {
			var scene: TSceneEntry = sceneData.getScene(sceneDataEntry.key);
			for (elemData in sceneDataEntry.elements) {
				var path: String = CanvasLoader.joinPath(elemData.parent, elemData.key);
				rememberImageName(CanvasLoader.findByPath(scene.root, scene.keys, path), elemData);
			}
		}

		// The editor always has a radio group and a scene
		if (built.radioGroups.length == 0) built.radioGroups.push(new RadioGroup("RadioGroup"));
		sceneData.radioGroups = built.radioGroups;

		if (sceneData.scenes.length == 0) {
			SceneEvents.sceneAdded.emit(SceneData.FIRST_SCENE);
		}
		if (sceneKey == null) sceneKey = built.activeScene;
		if (sceneKey == null || sceneData.getScene(sceneKey) == null) sceneKey = sceneData.currentScene.key;
		SceneEvents.sceneChanged.emit(sceneKey);

		Selection.clear();
	}

	// Builds `canvasData` into throwaway panes, so invalid data throws before the editor is changed
	static function checkBuildable(canvasData: TCanvasData): Void {
		var roots: Array<AnchorPane> = [];
		var makeRoot = key -> {
			var root: AnchorPane = new AnchorPane(0, 0, canvasData.canvas.width, canvasData.canvas.height);
			roots.push(root);
			return root;
		};
		try {
			CanvasLoader.buildCanvas(canvasData, makeRoot);
		} catch (e: Dynamic) {
			for (root in roots) root.destroy();
			throw e;
		}
		for (root in roots) root.destroy();
	}

	/**
	 * An element and everything inside it, for the clipboard: the element's
	 * parent is "", the others' paths start at it. Focus links are left out.
	 */
	public static function serializeElementTree(element: Element): Array<TElementData> {
		var result: Array<TElementData> = [];
		var scene = sceneData.currentScene;
		if (scene == null || !scene.keys.exists(element)) return result;

		var rootData: Null<TElementData> = serializeElement(element, scene.keys.get(element), "", scene, false);
		if (rootData == null) return result;
		result.push(rootData);

		serializeChildren(element, rootData.key, scene, false, result);

		return result;
	}

	/**
	 * Pastes clipboard data into `targetParent` if it's a container, otherwise
	 * into the scene, and returns the root of each pasted tree.
	 */
	public static function pasteElements(clipboardData: Array<TElementData>, ?targetParent: Element): Array<Element> {
		var scene = sceneData.currentScene;
		if (scene == null || clipboardData.length == 0) return [];

		var pasteParent: Element = HierarchyUtils.canAcceptChild(targetParent) ? targetParent : scene.root;

		// Pasted radio buttons join the canvas' groups
		var radioGroupMap: Map<String, RadioGroup> = [for (group in sceneData.radioGroups) group.id => group];
		var pastedRoots: Array<Element> = [];

		// The clipboard holds one or more copied trees, each starting with its root (parent "")
		var trees: Array<Array<TElementData>> = [];
		for (elemData in clipboardData) {
			if (elemData.parent == "") trees.push([]);
			if (trees.length > 0) trees[trees.length - 1].push(elemData);
		}

		for (tree in trees) {
			// Offset from the original, except in a Row/Col cell; the clipboard isn't changed
			var rootData: TElementData = Reflect.copy(tree[0]);
			if (!Std.isOfType(pasteParent, GridLayout)) {
				rootData.posX += 10;
				rootData.posY += 10;
			}
			tree[0] = rootData;

			// The root gets a free name among its new siblings; the elements inside it keep theirs
			var rootKey: String = NameUtils.nextUniqueName(rootData.key, NameUtils.getSiblingNames(null, pasteParent));
			var built: TBuiltTree = CanvasLoader.buildTree(tree, pasteParent, radioGroupMap, "pasted elements");
			var pastedRoot: Element = built.byPath.get(rootData.key);
			for (element => key in built.keys) sceneData.registerElement(element, element == pastedRoot ? rootKey : key, scene);
			for (elemData in tree) rememberImageName(built.byPath.get(CanvasLoader.joinPath(elemData.parent, elemData.key)), elemData);
			pastedRoots.push(pastedRoot);
		}

		// A pasted radio button whose group was deleted since the copy brings the group back
		for (group in radioGroupMap) {
			if (sceneData.radioGroups.indexOf(group) < 0) sceneData.radioGroups.push(group);
		}

		return pastedRoots;
	}

	// Removes and frees every scene, leaving none; callers add or load scenes right after
	public static function clearCanvas(): Void {
		for (scene in sceneData.scenes) {
			SceneManager.removeScene(scene.key);
			scene.root.destroy();
		}

		sceneData.scenes.resize(0);
		sceneData.currentScene = null;
		imageNames.clear();

		Selection.clear();
	}

	// Clear Canvas: leaves one empty scene, as one undo step
	public static function clearToEmptyScene(): Void {
		clearCanvas();
		SceneEvents.sceneAdded.emit(SceneData.FIRST_SCENE);
		History.edited("Clear canvas");
	}
}
