package arm.tools;

import arm.ElementData;
import arm.ElementData.THierarchyEntry;
import arm.ElementEvents;

import haxe.Json;

import koui.elements.Button;
import koui.elements.Element;
import koui.elements.Label;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;

// JSON structure typedefs
typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var elements: Array<TElementData>;
}

typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
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
	static inline var FORMAT_VERSION: String = "1.0";

	// Canvas name from command line args (e.g., "MyCanvas")
	public static var canvasName: String = "UntitledCanvas";

	/**
	 * Initializes the canvas name from command line arguments.
	 * Scans all arguments to find one ending with .json
	 */
	public static function init(): Void {
		var argCount: Int = Krom.getArgCount();

		// Debug: print all arguments
		trace('Argument count: ${argCount}');
		for (i in 0...argCount) {
			trace('Arg[${i}]: ${Krom.getArg(i)}');
		}

		// Scan through arguments to find one that looks like a canvas path (.json file)
		for (i in 0...argCount) {
			var arg: String = Krom.getArg(i);
			if (arg != null && StringTools.endsWith(arg.toLowerCase(), ".json")) {
				// Found a .json argument - extract canvas name from it
				var name: String = arg;
				// Remove path separators
				var lastSlash: Int = Std.int(Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\")));
				if (lastSlash >= 0) {
					name = name.substring(lastSlash + 1);
				}
				// Remove .json extension
				name = name.substring(0, name.length - 5);
				if (name != "") {
					canvasName = name;
					trace('Found canvas name from arg[${i}]: ${canvasName}');
					break;
				}
			}
		}

		trace('Final canvas name: ${canvasName}');
	}

	/**
	 * Gets the full path for the canvas JSON file.
	 * Path: Bundled/koui_canvas/[canvasName].json
	 */
	public static function getCanvasPath(): String {
		var basePath: String = Krom.getFilesLocation();
		basePath = StringTools.replace(basePath, "\\", "/");

		// basePath is: .../koui_editor/build_koui_editor/debug/krom
		// Navigate up 3 levels to project root, then to Bundled/koui_canvas
		var parts: Array<String> = basePath.split("/");
		parts.pop(); // remove "krom"
		parts.pop(); // remove "debug"
		parts.pop(); // remove "build_koui_editor"

		var projectRoot: String = parts.join("/");
		return projectRoot + "/Bundled/koui_canvas/" + canvasName + ".json";
	}

	/**
	 * Gets the directory path for canvas files.
	 */
	public static function getCanvasDir(): String {
		var basePath: String = Krom.getFilesLocation();
		basePath = StringTools.replace(basePath, "\\", "/");

		// Split and remove last 3 segments
		var parts: Array<String> = basePath.split("/");
		parts.pop(); // remove "krom"
		parts.pop(); // remove "debug"
		parts.pop(); // remove "build_koui_editor"

		var projectRoot: String = parts.join("/");
		return projectRoot + "/Bundled/koui_canvas";
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
		var basePath: String = Krom.getFilesLocation();

		// Try multiple path formats (relative and absolute)
		var paths: Array<String> = [
			basePath + "/../../../Bundled/koui_canvas/" + canvasName + ".json",
			getCanvasPath(),
		];

		var blob: js.lib.ArrayBuffer = null;

		for (path in paths) {
			var _blob: js.lib.ArrayBuffer = Krom.loadBlob(path);
			if (_blob != null) {
				blob = _blob;
				break;
			}
		}

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
		var root: AnchorPane = ElementData.root;
		var elementsData: Array<TElementData> = [];

		// Build a map of element -> key for parent references
		var elementKeyMap: Map<Element, String> = new Map();
		for (entry in ElementData.data.elements) {
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
	static function serializeElementsRecursive(parent: Element, elementKeyMap: Map<Element, String>, output: Array<TElementData>): Void {
		// Get children of this parent
		var children: Array<Element> = HierarchyUtils.getChildren(parent);

		for (child in children) {
			// Skip internal children (like Button's _label)
			if (HierarchyUtils.shouldSkipInternalChild(parent, child)) {
				continue;
			}

			// Find the entry for this child
			var entry: THierarchyEntry = null;
			for (e in ElementData.data.elements) {
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
				serializeElementsRecursive(child, elementKeyMap, output);
			}
		}
	}

	/**
	 * Serializes a single element to TElementData.
	 */
	static function serializeElement(entry: THierarchyEntry, elementKeyMap: Map<Element, String>): TElementData {
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
		var root: AnchorPane = ElementData.root;
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
			for (entry in ElementData.data.elements) {
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
	 * Creates an element from TElementData.
	 */
	static function createElementFromData(data: TElementData): Element {
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
		var root: AnchorPane = ElementData.root;

		// Remove all elements from root
		var children: Array<Element> = HierarchyUtils.getChildren(root).copy();
		for (child in children) {
			root.remove(child);
		}

		// Clear ElementData but keep the root - clear in-place to preserve array reference
		// (HierarchyPanel holds a reference to this array)
		ElementData.data.elements.resize(0);
		ElementData.data.elements.push({ key: "AnchorPane", element: root });
	}
}
