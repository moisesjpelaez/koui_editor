package arm.tools;

import arm.data.CanvasSettings;
import arm.data.SceneData;
import arm.data.SceneData.TSceneEntry;
import arm.events.SceneEvents;
import arm.events.ElementEvents;
import arm.tools.ElementUtils;

import haxe.Json;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;

// JSON structure typedefs
typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var scenes: Array<TSceneData>;
}

typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
	var settings: {
		var expandOnResize: Bool;
		var scaleOnResize: Bool;
		var autoScale: Bool;
		var scaleHorizontal: Bool;
		var scaleVertical: Bool;
	};
	@:optional var editor: {
		var undoStackSize: Int;
	};
}

typedef TSceneData = {
	var key: String;
	var active: Bool;
	var elements: Array<TElementData>;
}

typedef TElementData = {
	var key: String;
	var type: String;
	var tID: String;
	var posX: Int;
	var posY: Int;
	var width: Int;
	var height: Int;
	var anchor: Int;
	var visible: Bool;
	var disabled: Bool;
	var parentKey: Null<String>;
	var properties: Dynamic;
}

class CanvasUtils {
	static inline var FORMAT_VERSION: String = "1.1";

	// Canvas name from command line args (e.g., "MyCanvas")
	public static var canvasName: String = "UntitledCanvas";

	// Project directory from command line args
	public static var projectDir: String = "";
	public static var buildPath: String = "";
	public static var projectExt: String = "";

	static var sceneData: SceneData = SceneData.data;

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
	 * Gets the full path for the canvas JSON file.
	 * Path: Bundled/koui_canvas/[canvasName].json
	 */
	public static function getCanvasPath(): String {
		return projectDir + "/Bundled/koui_canvas/" + canvasName + ".json";
	}

	/**
	 * Looks up the asset name for a kha.Image by searching Koui.imageMap.
	 * Returns empty string if not found.
	 */
	public static function getImageName(image: kha.Image): String {
		if (image == null) return "";
		for (key in Koui.imageMap.keys()) {
			if (Koui.imageMap.get(key) == image) {
				return key;
			}
		}
		return "";
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

					if (error != null) {
						trace('Theme reload ERROR: ${error}');
					} else {
						var buildPath: String = projectDir + buildPath + "/ui_override.ksn";
						try {
							var bytes: haxe.io.Bytes = haxe.io.Bytes.ofString(themeContent);
							Krom.fileSaveBytes(buildPath, bytes.getData());
							// Theme reloaded successfully
						} catch (e: Dynamic) {
							trace('Theme reloaded but failed to copy to build directory: ${e}');
						}
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
		var listFile: String = projectDir + "/Assets/fonts/_fontlist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			// List .ttf files, output just filenames
			cmd = 'cmd /c dir /b "' + fontsDir + '\\*.ttf" > "' + listFile + '" 2>nul';
		} else {
			cmd = 'ls -1 "' + fontsDir + '"/*.ttf > "' + listFile + '" 2>/dev/null || true';
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
			if (trimmed.length > 0 && StringTools.endsWith(trimmed.toLowerCase(), ".ttf")) {
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
	 * Loads all images from the project's Assets/images/ directory.
	 * Each image is registered in Koui.imageMap with its normalized name.
	 * @param done Callback when all images are loaded
	 */
	static function loadAllImages(done: Void->Void): Void {
		var imagesDir: String = projectDir + "/Assets/images";
		if (kha.System.systemId == "Windows") {
			imagesDir = StringTools.replace(imagesDir, "/", "\\");
		}

		// Use system command to list image files
		var listFile: String = projectDir + "/Assets/images/_imagelist.txt";
		if (kha.System.systemId == "Windows") {
			listFile = StringTools.replace(listFile, "/", "\\");
		}

		var cmd: String;
		if (kha.System.systemId == "Windows") {
			// List image files (png, jpg), output just filenames using wildcard that matches multiple extensions
			cmd = 'cmd /c dir /b "' + imagesDir + '" > "' + listFile + '" 2>nul';
		} else {
			cmd = 'ls -1 "' + imagesDir + '" > "' + listFile + '" 2>/dev/null || true';
		}

		Krom.sysCommand(cmd);

		// Read the list file
		var listBlob: js.lib.ArrayBuffer = Krom.loadBlob(listFile);
		if (listBlob == null) {
			done();
			return;
		}

		var listContent: String = haxe.io.Bytes.ofData(listBlob).toString();
		var imageFiles: Array<String> = [];

		for (line in listContent.split("\n")) {
			var trimmed: String = StringTools.trim(line);
			if (trimmed.length > 0) {
				var lower: String = trimmed.toLowerCase();
				if (StringTools.endsWith(lower, ".png") || StringTools.endsWith(lower, ".jpg") || StringTools.endsWith(lower, ".k")) {
					// On Windows, dir /b gives just filename; on Linux ls -1 gives full path
					var filename: String = trimmed;
					var slashIdx: Int = Std.int(Math.max(filename.lastIndexOf("/"), filename.lastIndexOf("\\")));
					if (slashIdx >= 0) {
						filename = filename.substring(slashIdx + 1);
					}
					imageFiles.push(filename);
				}
			}
		}

		if (imageFiles.length == 0) {
			done();
			return;
		}

		var remaining: Int = imageFiles.length;

		for (filename in imageFiles) {
			var assetName: String = normalizeAssetName(filename);
			var imagePath: String = imagesDir + (kha.System.systemId == "Windows" ? "\\" : "/") + filename;

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
		} catch (e: Dynamic) {
			trace('Failed to save canvas: ${e}');
		}
	}

	/**
	 * Loads the canvas from Bundled/koui_canvas/[canvasName].json if it exists.
	 */
	public static function loadCanvas(): Void {
		var blob: js.lib.ArrayBuffer = Krom.loadBlob(getCanvasPath());
		if (blob == null) {
			trace('Canvas file not found: ${canvasName}');
			return;
		}

		try {
			var jsonString: String = haxe.io.Bytes.ofData(blob).toString();
			var canvasData: TCanvasData = Json.parse(jsonString);

			deserializeCanvas(canvasData);
			SceneEvents.canvasLoaded.emit();
		} catch (e: Dynamic) {
			trace('Failed to parse canvas: ${e}');
		}
	}

	/**
	 * Serializes the current canvas state to a TCanvasData structure.
	 */
	static function serializeCanvas(): TCanvasData {
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
			version: FORMAT_VERSION,
			canvas: {
				width: canvasWidth,
				height: canvasHeight,
				settings: {
					expandOnResize: CanvasSettings.expandOnResize,
					scaleOnResize: CanvasSettings.scaleOnResize,
					autoScale: CanvasSettings.autoScale,
					scaleHorizontal: CanvasSettings.scaleHorizontal,
					scaleVertical: CanvasSettings.scaleVertical
				},
				editor: {
					undoStackSize: CanvasSettings.undoStackSize
				}
			},
			scenes: scenesData
		};
	}

	/**
	 * Serializes a single scene to TSceneData.
	 */
	static function serializeScene(scene: TSceneEntry): TSceneData {
		var elementsData: Array<TElementData> = [];

		// Build a map of element -> key for parent references
		var elementKeyMap: Map<Element, String> = new Map();
		for (entry in scene.elements) {
			elementKeyMap.set(entry.element, entry.key);
		}

		// Serialize elements in hierarchy order (depth-first traversal)
		serializeElementsRecursive(scene.root, scene.elements, elementKeyMap, elementsData);

		return {
			key: scene.key,
			active: scene.active,
			elements: elementsData
		};
	}

	/**
	 * Recursively serializes elements in hierarchy order.
	 */
	static function serializeElementsRecursive(parent: Element, sceneElements: Array<{key: String, element: Element}>, elementKeyMap: Map<Element, String>, output: Array<TElementData>): Void {
		// Get children of this parent
		var children: Array<Element> = HierarchyUtils.getChildren(parent);

		for (child in children) {
			// Skip internal children (like Button's _label)
			if (HierarchyUtils.shouldSkipInternalChild(parent, child)) {
				continue;
			}

			// Find the entry for this child
			var entry: {key: String, element: Element} = null;
			for (e in sceneElements) {
				if (e.element == child) {
					entry = e;
					break;
				}
			}

			if (entry != null) {
				var elementData: TElementData = serializeElement(entry, elementKeyMap);
				if (elementData != null) {
					output.push(elementData);
				}

				// Recursively serialize children of this element
				serializeElementsRecursive(child, sceneElements, elementKeyMap, output);
			}
		}
	}

	/**
	 * Serializes a single element to TElementData.
	 */
	static function serializeElement(entry: {key: String, element: Element}, elementKeyMap: Map<Element, String>): TElementData {
		var element: Element = entry.element;
		var type: String = getElementType(element);

		if (type == "Unknown") {
			trace('Skipping unknown element type: ${entry.key}');
			return null;
		}

		// Get parent key
		var parentKey: Null<String> = null;
		var parent: Element = HierarchyUtils.getParentElement(element);
		if (parent != null && elementKeyMap.exists(parent)) {
			parentKey = elementKeyMap.get(parent);
		}

		return {
			key: entry.key,
			type: type,
			tID: element.getTID(),
			posX: element.posX,
			posY: element.posY,
			width: element.width,
			height: element.height,
			anchor: cast element.anchor,
			visible: element.visible,
			disabled: element.disabled,
			parentKey: parentKey,
			properties: serializeTypeProperties(element, type)
		};
	}

	/**
	 * Returns the type string for an element.
	 */
	public static function getElementType(element: Element): String {
		return ElementUtils.getElementType(element);
	}

	/**
	 * Serializes type-specific properties.
	 */
	static function serializeTypeProperties(element: Element, type: String): Dynamic {
		return ElementUtils.serializeProperties(element, type);
	}

	/**
	 * Deserializes a canvas from TCanvasData and rebuilds the editor state.
	 */
	static function deserializeCanvas(canvasData: TCanvasData): Void {
		// Clear existing scenes (and remove from SceneManager/Koui)
		clearCanvas();

		// Load canvas settings
		if (canvasData.canvas.settings != null) {
			CanvasSettings.expandOnResize = canvasData.canvas.settings.expandOnResize;
			CanvasSettings.scaleOnResize = canvasData.canvas.settings.scaleOnResize;
			CanvasSettings.autoScale = canvasData.canvas.settings.autoScale;
			CanvasSettings.scaleHorizontal = canvasData.canvas.settings.scaleHorizontal;
			CanvasSettings.scaleVertical = canvasData.canvas.settings.scaleVertical;
		}

		// Load editor-only settings
		if (canvasData.canvas.editor != null) {
			CanvasSettings.undoStackSize = canvasData.canvas.editor.undoStackSize;
		}

		// Deserialize each scene by emitting sceneAdded (like the Add Scene button does)
		var activeSceneKey: String = null;
		for (sceneDataEntry in canvasData.scenes) {
			deserializeScene(sceneDataEntry, canvasData.canvas.width, canvasData.canvas.height);
			if (sceneDataEntry.active) {
				activeSceneKey = sceneDataEntry.key;
			}
		}

		// If no scenes were loaded, create a default scene
		if (sceneData.scenes.length == 0) {
			SceneEvents.sceneAdded.emit("Scene");
		} else if (activeSceneKey != null) {
			// Switch to the active scene
			SceneEvents.sceneChanged.emit(activeSceneKey);
		}

		ElementEvents.elementSelected.emit(null);
	}

	/**
	 * Deserializes a single scene from TSceneData.
	 */
	static function deserializeScene(sceneDataEntry: TSceneData, canvasWidth: Int, canvasHeight: Int): Void {
		// Emit sceneAdded - this triggers KouiEditor.onSceneAdded which properly sets up the scene
		SceneEvents.sceneAdded.emit(sceneDataEntry.key);

		// Get the scene that was just created by the event handler
		var scene: TSceneEntry = sceneData.currentScene;

		// First pass: create all elements in order (use array to handle duplicate keys)
		var createdElements: Array<Element> = [];
		for (elemData in sceneDataEntry.elements) {
			var element: Element = createElementFromData(elemData);
			createdElements.push(element);
		}

		// Build a map for parent lookup (parents are serialized before children)
		var elementMap: Map<String, Element> = new Map();
		for (i in 0...sceneDataEntry.elements.length) {
			if (createdElements[i] != null) {
				elementMap.set(sceneDataEntry.elements[i].key, createdElements[i]);
			}
		}

		// Second pass: add elements to correct parents with correct anchors
		// Use index to pair each elemData with its created element (handles duplicate keys)
		for (i in 0...sceneDataEntry.elements.length) {
			var elemData = sceneDataEntry.elements[i];
			var element = createdElements[i];
			if (element == null) continue;

			// Register element in scene data with the loaded key
			scene.elements.push({ key: elemData.key, element: element });

			// Find the parent element
			var parent: Element = null;
			if (elemData.parentKey != null && elementMap.exists(elemData.parentKey)) {
				parent = elementMap.get(elemData.parentKey);
			}

			// Set the anchor before adding to parent
			element.anchor = cast elemData.anchor;

			// Add to parent (or root if no parent)
			if (parent != null) {
				HierarchyUtils.moveAsChild(element, parent);
			} else {
				// Root-level element - add to scene root
				scene.root.add(element, cast elemData.anchor);
			}
		}
	}

	/**
	 * Creates an element from TElementData.
	 */
	static function createElementFromData(data: TElementData): Element {
		return ElementUtils.createElement(
			data.type,
			data.posX,
			data.posY,
			data.width,
			data.height,
			data.anchor,
			data.visible,
			data.disabled,
			data.tID,
			data.properties
		);
	}

	/**
	 * Clears all elements from all scenes and removes all scenes.
	 */
	public static function clearCanvas(): Void {
		// Remove all scenes by emitting sceneRemoved (like the Delete Scene button does)
		var scenesToRemove: Array<TSceneEntry> = sceneData.scenes.copy();
		for (scene in scenesToRemove) {
			// Clear element bookkeeping
			scene.elements.resize(0);

			// Emit scene removed - KouiEditor.onSceneRemoved will call SceneManager.removeScene
			SceneEvents.sceneRemoved.emit(scene.key);
		}

		// Clear the scenes array and reset current scene
		sceneData.scenes.resize(0);
		sceneData.currentScene = null;

		ElementEvents.elementSelected.emit(null);
	}
}
