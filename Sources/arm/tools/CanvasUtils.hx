package arm.tools;

import arm.ElementsData;
import arm.ElementsData.THierarchyEntry;
import arm.ElementEvents;

import haxe.Json;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;
import koui.elements.layouts.AnchorPane;

// JSON structure typedefs
typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var elements: Array<TElementsData>;
}

typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
}

typedef TElementsData = {
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
	static inline var FORMAT_VERSION: String = "1.0";

	// Canvas name from command line args (e.g., "MyCanvas")
	public static var canvasName: String = "UntitledCanvas";

	// Project directory from command line args
	public static var projectDir: String = "";
	public static var buildPath: String = "";
	public static var projectExt: String = "";

	static var elementsData: ElementsData = ElementsData.data;
    static var elements: Array<THierarchyEntry> = ElementsData.data.elements;

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

		trace('Canvas name: ${canvasName}');
		trace('Project dir: ${projectDir}');
	}

	/**
	 * Gets the full path for the canvas JSON file.
	 * Path: Bundled/koui_canvas/[canvasName].json
	 */
	public static function getCanvasPath(): String {
		return projectDir + "/Bundled/koui_canvas/" + canvasName + ".json";
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
	 */
	public static function refreshTheme(): Void {
		var assetsPath: String = projectDir + "/Assets/ui_override.ksn";
		var blob: js.lib.ArrayBuffer = Krom.loadBlob(assetsPath);

		if (blob != null) {
			var themeContent: String = haxe.io.Bytes.ofData(blob).toString();
			var error: String = koui.theme.RuntimeThemeLoader.parseAndApply(themeContent);

			if (error != null) {
				trace('Theme reload ERROR: ${error}');
			} else {
				var buildPath: String = projectDir + buildPath + "/ui_override.ksn";
				try {
				var bytes: haxe.io.Bytes = haxe.io.Bytes.ofString(themeContent);
				Krom.fileSaveBytes(buildPath, bytes.getData());
					trace('Theme reloaded successfully from: ${assetsPath}');
					trace('Theme copied to build directory: ${buildPath}');
				} catch (e: Dynamic) {
					trace('Theme reloaded but failed to copy to build directory: ${e}');
				}
			}
		} else {
			trace('Theme file not found: ${assetsPath}');
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
			trace('Canvas saved: ${canvasName}');
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
			trace('Canvas loaded: ${canvasName}');
		} catch (e: Dynamic) {
			trace('Failed to parse canvas: ${e}');
		}
	}

	/**
	 * Serializes the current canvas state to a TCanvasData structure.
	 */
	static function serializeCanvas(): TCanvasData {
		var root: AnchorPane = elementsData.root;
		var elementsData: Array<TElementsData> = [];

		// Build a map of element -> key for parent references
		var elementKeyMap: Map<Element, String> = new Map();
		for (entry in elements) {
			elementKeyMap.set(entry.element, entry.key);
		}

		// Serialize elements in hierarchy order (depth-first traversal)
		serializeElementsRecursive(root, elementKeyMap, elementsData);

		return {
			name: canvasName,
			version: FORMAT_VERSION,
			canvas: {
				width: root.width,
				height: root.height
			},
			elements: elementsData
		};
	}

	/**
	 * Recursively serializes elements in hierarchy order.
	 */
	static function serializeElementsRecursive(parent: Element, elementKeyMap: Map<Element, String>, output: Array<TElementsData>): Void {
		// Get children of this parent
		var children: Array<Element> = HierarchyUtils.getChildren(parent);

		for (child in children) {
			// Skip internal children (like Button's _label)
			if (HierarchyUtils.shouldSkipInternalChild(parent, child)) {
				continue;
			}

			// Find the entry for this child
			var entry: THierarchyEntry = null;
			for (e in elements) {
				if (e.element == child) {
					entry = e;
					break;
				}
			}

			if (entry != null) {
				var elementData: TElementsData = serializeElement(entry, elementKeyMap);
				if (elementData != null) {
					output.push(elementData);
				}

				// Recursively serialize children of this element
				serializeElementsRecursive(child, elementKeyMap, output);
			}
		}
	}

	/**
	 * Serializes a single element to TElementsData.
	 */
	static function serializeElement(entry: THierarchyEntry, elementKeyMap: Map<Element, String>): TElementsData {
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
	static function getElementType(element: Element): String {
		if (Std.isOfType(element, Button)) return "Button";
		if (Std.isOfType(element, Label)) return "Label";
		if (Std.isOfType(element, AnchorPane)) return "AnchorPane";
		// Add more types here as needed:
		// if (Std.isOfType(element, Checkbox)) return "Checkbox";
		// if (Std.isOfType(element, Slider)) return "Slider";
		// if (Std.isOfType(element, Panel)) return "Panel";
		return "Unknown";
	}

	/**
	 * Serializes type-specific properties.
	 */
	static function serializeTypeProperties(element: Element, type: String): Dynamic {
		switch (type) {
			case "Label":
				var label: Label = cast element;
				return {
					text: label.text,
					alignmentHor: cast label.alignmentHor,
					alignmentVert: cast label.alignmentVert
				};

			case "Button":
				var button: Button = cast element;
				return {
					text: button.text,
					isToggle: button.isToggle,
					isPressed: button.isPressed
				};

			case "AnchorPane":
				// AnchorPane doesn't have special properties beyond base Element
				return {};

			default:
				return {};
		}
	}

	/**
	 * Deserializes a canvas from TCanvasData and rebuilds the editor state.
	 */
	static function deserializeCanvas(canvasData: TCanvasData): Void {
		var root: AnchorPane = elementsData.root;
		// Clear existing elements (except root)
		clearCanvas();

		// Resize canvas if needed
		root.width = canvasData.canvas.width;
		root.height = canvasData.canvas.height;

		// First pass: create all elements and store in a map
		var elementMap: Map<String, Element> = new Map();

		for (elemData in canvasData.elements) {
			var element: Element = createElementFromData(elemData);
			if (element != null) {
				elementMap.set(elemData.key, element);
			}
		}

		// Second pass: emit elementAdded first, then reparent to correct location
		for (elemData in canvasData.elements) {
			var element: Element = elementMap.get(elemData.key);
			if (element == null) continue;

			// Emit elementAdded FIRST - this registers the element and adds it to canvas at default position
			// (KouiEditor.onElementAdded adds to root at TopLeft)
			ElementEvents.elementAdded.emit({ key: elemData.key, element: element });

			// Now update the key to the loaded value (KouiEditor generated a unique name)
			for (entry in elements) {
				if (entry.element == element) {
					entry.key = elemData.key;
					break;
				}
			}

			// THEN reparent to correct parent/anchor from the saved data
			var parent: Element = null;
			if (elemData.parentKey != null && elementMap.exists(elemData.parentKey)) {
				parent = elementMap.get(elemData.parentKey);
			}

			if (parent != null) {
				HierarchyUtils.moveAsChild(element, parent);
			} else {
				// Update anchor if it's a root-level element (already added by KouiEditor, just update anchor)
				element.anchor = cast elemData.anchor;
			}
		}

        ElementEvents.elementSelected.emit(null);
	}

	/**
	 * Creates an element from TElementsData.
	 */
	static function createElementFromData(data: TElementsData): Element {
		var element: Element = null;

		switch (data.type) {
			case "Label":
				var label: Label = new Label(data.properties.text != null ? data.properties.text : "");
				if (data.properties.alignmentHor != null) {
					label.alignmentHor = cast data.properties.alignmentHor;
				}
				if (data.properties.alignmentVert != null) {
					label.alignmentVert = cast data.properties.alignmentVert;
				}
				element = label;

			case "Button":
				var button: Button = new Button(data.properties.text != null ? data.properties.text : "");
				if (data.properties.isToggle != null) {
					button.isToggle = data.properties.isToggle;
				}
				if (data.properties.isPressed != null) {
					button.isPressed = data.properties.isPressed;
				}
				element = button;

			case "AnchorPane":
				var pane: AnchorPane = new AnchorPane(data.posX, data.posY, data.width, data.height);
				element = pane;

			// Add more types here as needed:
			// case "Checkbox": ...
			// case "Slider": ...

			default:
				trace('Unknown element type: ${data.type}');
				return null;
		}

		// Apply common properties
		if (element != null) {
			element.posX = data.posX;
			element.posY = data.posY;
			element.width = data.width;
			element.height = data.height;
			element.anchor = cast data.anchor;
			element.visible = data.visible;
			element.disabled = data.disabled;
			if (data.tID != null && data.tID != "") {
				element.setTID(data.tID);
			}
		}

		return element;
	}

	/**
	 * Clears all elements from the canvas (except root AnchorPane).
	 */
	static function clearCanvas(): Void {
		var root: AnchorPane = elementsData.root;
		// Remove all elements from root
		var children: Array<Element> = HierarchyUtils.getChildren(root).copy();
		for (child in children) {
			root.remove(child);
		}

		// Clear ElementsData but keep the root - clear in-place to preserve array reference
		// (HierarchyPanel holds a reference to this array)
		elements.resize(0);
		elements.push({ key: "AnchorPane", element: root });
	}
}
