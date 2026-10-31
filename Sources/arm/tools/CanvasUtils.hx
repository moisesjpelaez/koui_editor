package arm.tools;

import arm.data.CanvasSettings;
import arm.data.History;
import arm.data.SceneData;
import arm.data.Selection;
import arm.events.SceneEvents;
import arm.events.ElementEvents;
import arm.canvas.CanvasElements;
import arm.canvas.CanvasLoader;
import arm.editors.ElementRegistry;
import arm.types.Types;

import haxe.Json;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.elements.Label;
import koui.elements.RadioButton;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.GridLayout;
import koui.utils.RadioGroup;
import koui.utils.SceneManager;

class CanvasUtils {
	// Canvas name from command line args (e.g., "MyCanvas")
	public static var canvasName: String = "UntitledCanvas";

	// Project directory from command line args
	public static var projectDir: String = "";
	public static var buildPath: String = "";
	public static var projectExt: String = "";

	static var sceneData: SceneData = SceneData.data;

	/**
	 * The name of each ImagePanel's image. Saving uses it rather than looking
	 * the image object up: reloading the images replaces the objects, and an
	 * image the project doesn't have has no object.
	 */
	static var imageNames: Map<ImagePanel, String> = new Map();

	/**
	 * Initializes the canvas name from command line arguments.
	 * Canvas name (trait name from Blender) is at Arg[3]
	 */
	public static function init(): Void {
		// Args: [0]=krom_path, [1]=assets, [2]=shaders, [3]=canvas_name, [4]=uiscale, [5]=res_x, [6]=res_y, [7]=project_dir, [8]=project_ext
		var argCount: Int = Krom.getArgCount();

		if (argCount > 3) {
			var name: String = Krom.getArg(3);
			if (name != null && name != "" && !StringTools.startsWith(name, "--")) {
				canvasName = name;
			}
		}

		if (argCount > 7) {
			var dir: String = Krom.getArg(7);
			if (dir != null && dir != "" && !StringTools.startsWith(dir, "--")) {
				projectDir = StringTools.replace(dir, "/", "\\");
			}
			var ext: String = Krom.getArg(8);
			if (ext != null && ext != "" && !StringTools.startsWith(ext, "--")) {
				projectExt = ext;
			}
			buildPath = "/Libraries/koui_editor/tools/" + projectExt;
		} else { // Fallback for standalone testing
			projectDir = StringTools.replace(Krom.getFilesLocation(), "/", "\\") + "/../../..";
			#if kha_opengl
			projectExt = "opengl";
			#else
			projectExt = "d3d11";
			#end
			buildPath = "/tools/" + projectExt;
		}
	}

	/**
	 * The editor's own data folder (tools/<backend>/data), for files that
	 * belong to the editor rather than to the game: settings and scratch files.
	 */
	public static function editorDataDir(): String {
		return Krom.getFilesLocation() + "/data";
	}

	/**
	 * Gets the full path for the canvas JSON file.
	 * Path: Bundled/koui_canvas/[canvasName].json
	 */
	public static function getCanvasPath(): String {
		return projectDir + "/Bundled/koui_canvas/" + canvasName + ".json";
	}

	/** The name of the image `panel` shows (or would show, if the project has it), or "" for none. */
	public static function getImageName(panel: ImagePanel): String {
		var name: Null<String> = imageNames.get(panel);
		return name != null ? name : CanvasElements.getImageName(panel.image);
	}

	public static function setImageName(panel: ImagePanel, name: String): Void {
		imageNames.set(panel, name);
	}

	/** Whether `panel` names an image the project doesn't have. */
	public static function isImageMissing(panel: ImagePanel): Bool {
		var name: String = getImageName(panel);
		return name != "" && Koui.getImage(name) == null;
	}

	/**
	 * Gets the directory path for canvas files.
	 */
	public static function getCanvasDir(): String {
		return projectDir + "/Bundled/koui_canvas";
	}

	/**
	 * Ensures the koui_canvas directory exists by creating it if needed.
	 */
	public static function ensureCanvasDir(): Void {
		var dir: String = getCanvasDir();
		var cmd: String = kha.System.systemId == "Windows"
			? 'cmd /c if not exist "' + StringTools.replace(dir, "/", "\\") + '" mkdir "' + StringTools.replace(dir, "/", "\\") + '"'
			: 'mkdir -p "' + dir + '"';
		Krom.sysCommand(cmd);
	}

	/**
	 * Reloads the theme from the project's Assets/ui_override.ksn file.
	 * Also loads any custom fonts referenced in the theme from Assets/fonts/.
	 */
	public static function refreshTheme(): Void {
		var assetsPath: String = projectDir + "/Assets/koui_canvas/ui_override.ksn";
		var blob: js.lib.ArrayBuffer = Krom.loadBlob(assetsPath);

		if (blob != null) {
			var themeContent: String = haxe.io.Bytes.ofData(blob).toString();

			// Load all fonts and images from Assets/ directory first
			loadAllFonts(function() {
				loadAllImages(function() {
					// After assets are loaded, apply the theme
					var error: String = koui.theme.RuntimeThemeLoader.parseAndApply(themeContent);

					// The images were loaded again as new objects: panels show the new ones, and missing ones that now exist
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

	/**
	 * Normalizes a filename to an asset name (like Kha does).
	 * Replaces hyphens, dots, spaces and other special characters with underscores.
	 */
	static function normalizeAssetName(filename: String): String {
		// Remove extension
		var name: String = filename;
		var dotIdx: Int = name.lastIndexOf(".");
		if (dotIdx >= 0) {
			name = name.substring(0, dotIdx);
		}
		// Replace special characters with underscores (matching Kha's behavior)
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

	/**
	 * Loads all fonts from the project's Assets/fonts/ directory.
	 * Each font is registered in Koui.fontMap with its normalized name.
	 * @param done Callback when all fonts are loaded
	 */
	static function loadAllFonts(done: Void->Void): Void {
		var fontsDir: String = projectDir + "/Assets/fonts";
		if (kha.System.systemId == "Windows") {
			fontsDir = StringTools.replace(fontsDir, "/", "\\");
		}

		// Use system command to list font files
		var listFile: String = editorDataDir() + "/_fontlist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			// List .ttf and .otf files, output just filenames
			cmd = 'cmd /c dir /b "' + fontsDir + '\\*.ttf" "' + fontsDir + '\\*.otf" > "' + listFile + '" 2>nul';
		} else {
			cmd = 'ls -1 "' + fontsDir + '"/*.ttf "' + fontsDir + '"/*.otf > "' + listFile + '" 2>/dev/null || true';
		}

		Krom.sysCommand(cmd);

		// Read the list file
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
				// On Windows, dir /b gives just filename; on Linux ls -1 gives full path
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

			// Capture in closure
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

	/**
	 * Loads all images from the project's Assets/ directory and subdirectories.
	 * Each image is registered in Koui.imageMap with its normalized filename (matching Kha's behavior).
	 * @param done Callback when all images are loaded
	 */
	static function loadAllImages(done: Void->Void): Void {
		var assetsDir: String = projectDir + "/Assets";
		if (kha.System.systemId == "Windows") {
			assetsDir = StringTools.replace(assetsDir, "/", "\\");
		}

		// Use system command to list image files recursively
		var listFile: String = editorDataDir() + "/_imagelist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			// List image files recursively with relative paths using /s and /b flags
			cmd = 'cmd /c dir /b /s "' + assetsDir + '\\*.png" "' + assetsDir + '\\*.jpg" "' + assetsDir + '\\*.k" > "' + listFile + '" 2>nul';
		} else {
			// Use find to recursively list image files
			cmd = 'find "' + assetsDir + '" -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.k" \\) > "' + listFile + '" 2>/dev/null || true';
		}

		Krom.sysCommand(cmd);

		// Read the list file
		var listBlob: js.lib.ArrayBuffer = Krom.loadBlob(listFile);
		if (listBlob == null) {
			done();
			return;
		}

		var listContent: String = haxe.io.Bytes.ofData(listBlob).toString();
		var imageFiles: Array<String> = [];  // Stores relative paths from assetsDir

		// Get the base path length to calculate relative paths
		var basePath: String = assetsDir + (kha.System.systemId == "Windows" ? "\\" : "/");
		var baseLen: Int = basePath.length;

		for (line in listContent.split("\n")) {
			var trimmed: String = StringTools.trim(line);
			if (trimmed.length > 0) {
				var lower: String = trimmed.toLowerCase();
				if (StringTools.endsWith(lower, ".png") || StringTools.endsWith(lower, ".jpg") || StringTools.endsWith(lower, ".k")) {
					// Extract relative path from the full path
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
			// Extract just the filename (without directory) for normalization - matches Kha's behavior
			var slashIdx: Int = Std.int(Math.max(filename.lastIndexOf("/"), filename.lastIndexOf("\\")));
			var justFilename: String = slashIdx >= 0 ? filename.substring(slashIdx + 1) : filename;
			var assetName: String = normalizeAssetName(justFilename);
			var imagePath: String = assetsDir + (kha.System.systemId == "Windows" ? "\\" : "/") + filename;

			// Capture in closure
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

	/**
	 * Saves the current canvas to Bundled/koui_canvas/[canvasName].json
	 */
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

	/**
	 * Loads the canvas from Bundled/koui_canvas/[canvasName].json if it exists.
	 * If the file can't be loaded, the current canvas is kept.
	 */
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

	/**
	 * Serializes the current canvas state to a TCanvasData structure.
	 */
	public static function serializeCanvas(): TCanvasData {
		var scenesData: Array<TSceneData> = [];

		// Serialize each scene
		for (scene in sceneData.scenes) {
			scenesData.push(serializeScene(scene));
		}

		// Get canvas dimensions from current scene's root
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

	/**
	 * Serializes a single scene to TSceneData.
	 */
	static function serializeScene(scene: TSceneEntry): TSceneData {
		var elementsData: Array<TElementData> = [];

		// Serialize elements in hierarchy order (depth-first traversal), parents first
		serializeChildren(scene.root, "", scene, true, elementsData);

		return {
			key: scene.key,
			// The scene shown when loading is the one shown when saving
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

	/** Where `element` is in the canvas, or null if it is not in any scene. */
	static function findElementRef(element: Null<Element>): Null<TElementRef> {
		if (element == null) return null;
		for (scene in sceneData.scenes) {
			if (scene.keys.exists(element)) {
				return { scene: scene.key, path: CanvasLoader.getPath(element, scene.root, scene.keys) };
			}
		}
		return null;
	}

	/**
	 * Serializes the elements inside `parent`, and theirs, in hierarchy order.
	 * `parentPath` is the path saved as the children's parent.
	 */
	static function serializeChildren(parent: Element, parentPath: String, scene: TSceneEntry, withFocus: Bool, output: Array<TElementData>): Void {
		for (child in sceneData.getChildren(parent, scene)) {
			var elementData: Null<TElementData> = serializeElement(child, scene.keys.get(child), parentPath, scene, withFocus);
			if (elementData == null) continue;

			output.push(elementData);
			serializeChildren(child, CanvasLoader.joinPath(parentPath, elementData.key), scene, withFocus, output);
		}
	}

	/**
	 * Serializes a single element. Returns null (and skips its children) for a
	 * type a canvas can't contain.
	 */
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

	/**
	 * Returns the type string for an element.
	 */
	public static function getElementType(element: Element): String {
		return ElementRegistry.getElementType(element);
	}

	/**
	 * Rebuilds the editor from `canvasData`. Throws if the data can't be loaded,
	 * before anything is changed, so the current canvas is kept.
	 */
	static function deserializeCanvas(canvasData: TCanvasData): Void {
		checkBuildable(canvasData);

		var activeSceneKey: String = null;
		for (sceneDataEntry in canvasData.scenes) {
			if (sceneDataEntry.active) {
				activeSceneKey = sceneDataEntry.key;
				break;
			}
		}
		rebuildCanvas(canvasData, activeSceneKey);

		var reported: Array<String> = [];
		for (panel => name in imageNames) {
			if (!isImageMissing(panel) || reported.indexOf(name) >= 0) continue;
			reported.push(name);
			trace('Image "${name}" is not in the project; its name is kept when saving');
		}
	}

	/** If `data` is an ImagePanel, remembers its image's name for saving. */
	static function rememberImageName(element: Null<Element>, data: TElementData): Void {
		if (element == null || data.type != "ImagePanel") return;
		imageNames.set(cast element, data.properties.imageName);
	}

	/**
	 * Replaces the editor's canvas with `canvasData`, which must be valid, and
	 * shows the scene `sceneKey` (or the last scene if it is null). Used by
	 * loading and by undo/redo.
	 */
	public static function rebuildCanvas(canvasData: TCanvasData, sceneKey: Null<String>): Void {
		// Remove and free the existing scenes
		clearCanvas();

		// Load canvas settings
		CanvasSettings.expandOnResize = canvasData.canvas.settings.expandOnResize;
		CanvasSettings.scaleOnResize = canvasData.canvas.settings.scaleOnResize;
		CanvasSettings.autoScale = canvasData.canvas.settings.autoScale;
		CanvasSettings.scaleHorizontal = canvasData.canvas.settings.scaleHorizontal;
		CanvasSettings.scaleVertical = canvasData.canvas.settings.scaleVertical;

		// Radio groups are shared by all scenes; the editor always has at least one
		var radioGroups: Array<RadioGroup> = CanvasLoader.createRadioGroups(canvasData);
		if (radioGroups.length == 0) radioGroups.push(new RadioGroup("RadioGroup"));
		var radioGroupMap: Map<String, RadioGroup> = [for (group in radioGroups) group.id => group];

		var builtScenes: Map<String, TBuiltScene> = new Map();
		for (sceneDataEntry in canvasData.scenes) {
			// Emit sceneAdded - this triggers KouiEditor.onSceneAdded which properly sets up the scene
			SceneEvents.sceneAdded.emit(sceneDataEntry.key);
			var scene: TSceneEntry = sceneData.currentScene;

			var keys: Map<Element, String> = CanvasLoader.buildScene(sceneDataEntry, scene.root, radioGroupMap);
			for (element => key in keys) sceneData.registerElement(element, key, scene);
			builtScenes.set(scene.key, { root: scene.root, keys: keys });

			for (elemData in sceneDataEntry.elements) {
				var path: String = CanvasLoader.joinPath(elemData.parent, elemData.key);
				rememberImageName(CanvasLoader.findByPath(scene.root, keys, path), elemData);
			}
		}

		// Radio buttons may have created groups the canvas didn't list
		for (group in radioGroupMap) {
			if (radioGroups.indexOf(group) < 0) radioGroups.push(group);
		}
		sceneData.radioGroups = radioGroups;
		CanvasLoader.applyActiveButtons(canvasData, radioGroupMap, builtScenes);

		// If no scenes were loaded, create a default scene
		if (sceneData.scenes.length == 0) {
			SceneEvents.sceneAdded.emit("Scene_1");
		}
		if (sceneKey == null || sceneData.getScene(sceneKey) == null) sceneKey = sceneData.currentScene.key;
		SceneEvents.sceneChanged.emit(sceneKey);

		Selection.clear();
	}

	/** Builds `canvasData` into throwaway panes, so invalid data throws before the editor is changed. */
	static function checkBuildable(canvasData: TCanvasData): Void {
		var radioGroupMap: Map<String, RadioGroup> = [for (group in CanvasLoader.createRadioGroups(canvasData)) group.id => group];
		var builtScenes: Map<String, TBuiltScene> = new Map();
		var roots: Array<AnchorPane> = [];

		try {
			for (sceneDataEntry in canvasData.scenes) {
				if (builtScenes.exists(sceneDataEntry.key)) throw 'two scenes are named "${sceneDataEntry.key}"';
				var root: AnchorPane = new AnchorPane(0, 0, canvasData.canvas.width, canvasData.canvas.height);
				roots.push(root);
				builtScenes.set(sceneDataEntry.key, { root: root, keys: CanvasLoader.buildScene(sceneDataEntry, root, radioGroupMap) });
			}
			CanvasLoader.applyActiveButtons(canvasData, radioGroupMap, builtScenes);
		} catch (e: Dynamic) {
			for (root in roots) root.destroy();
			throw e;
		}
		for (root in roots) root.destroy();
	}

	/**
	 * Serializes an element and all its user-facing children into a flat array.
	 * The element's parent is saved as "", its children's parents as paths
	 * starting at the element. Focus links are not copied.
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
	 * Pastes elements from clipboard data into the current scene and returns
	 * the root of each pasted tree. Creates new elements with unique names and
	 * restores parent-child relationships. If targetParent is a container, each
	 * copied tree is pasted into it, otherwise into the scene. Pasted trees are
	 * offset by 10 units, except in grid cells.
	 */
	public static function pasteElements(clipboardData: Array<TElementData>, ?targetParent: Element): Array<Element> {
		var scene = sceneData.currentScene;
		if (scene == null || clipboardData.length == 0) return [];

		// Determine where to paste the root element
		var pasteParent: Element = HierarchyUtils.canAcceptChild(targetParent) ? targetParent : scene.root;

		// Pasted radio buttons join the canvas' groups
		var radioGroupMap: Map<String, RadioGroup> = [for (group in sceneData.radioGroups) group.id => group];

		// Map from a copied element's path (within its copied tree) to its new element
		var pathToElement: Map<String, Element> = new Map();
		var pastedRoots: Array<Element> = [];

		for (elemData in clipboardData) {
			// The clipboard can hold several copied trees; paths only need to be unique within each
			var isTreeRoot: Bool = elemData.parent == "";
			if (isTreeRoot) pathToElement = new Map();

			var parent: Element = isTreeRoot ? pasteParent : pathToElement.get(elemData.parent);
			if (parent == null) continue;

			var element: Element = CanvasElements.create(elemData, radioGroupMap);
			if (element == null) continue;
			rememberImageName(element, elemData);

			// Names are unique among siblings: a copied tree's root gets a free name in
			// the container it's pasted into; the elements inside it keep theirs
			var proposedKey: String = isTreeRoot ? NameUtils.nextUniqueName(elemData.key, NameUtils.getSiblingNames(null, pasteParent)) : elemData.key;

			pathToElement.set(CanvasLoader.joinPath(elemData.parent, elemData.key), element);

			if (isTreeRoot) {
				if (!Std.isOfType(pasteParent, GridLayout)) element.setPosition(elemData.posX + 10, elemData.posY + 10);
				if (pasteParent == scene.root) {
					scene.root.add(element, cast elemData.anchor);
				} else {
					HierarchyUtils.moveAsChild(element, pasteParent);
				}
				pastedRoots.push(element);
			} else {
				// Child element — add to its parent
				HierarchyUtils.moveAsChild(element, parent);
			}
			sceneData.registerElement(element, proposedKey, scene);
		}

		return pastedRoots;
	}

	/**
	 * Removes all scenes and frees their elements, leaving no scene. Callers
	 * create or load scenes right after.
	 */
	public static function clearCanvas(): Void {
		for (scene in sceneData.scenes) {
			SceneManager.removeScene(scene.key);
			scene.root.destroy();
		}

		// Clear the scenes array and reset current scene
		sceneData.scenes.resize(0);
		sceneData.currentScene = null;
		imageNames.clear();

		Selection.clear();
	}

	/** The toolbar's Clear Canvas: removes everything and leaves one empty scene, as one undoable step. */
	public static function clearToEmptyScene(): Void {
		clearCanvas();
		SceneEvents.sceneAdded.emit("Scene_1");
		History.edited("Clear canvas");
	}
}
