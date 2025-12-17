package armory.trait.internal;

import iron.App;
import iron.Trait;
import koui.Koui;
import koui.elements.Element;
import koui.elements.Button;
import koui.elements.Label;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;

// JSON structure typedefs (matching CanvasUtils format)
private typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var elements: Array<TElementsData>;
}

private typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
	var settings: TSettings;
}

private typedef TSettings = {
	var scaleOnResize: Bool;
	var autoExpand: Bool;
	var expandHorizontal: Bool;
	var expandVertical: Bool;
}

private typedef TElementsData = {
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

/**
 * Runtime trait for loading and displaying Koui canvases.
 * Attach this trait to a game object in Blender to render a UI canvas.
 *
 * Unlike Armory2D's immediate mode canvas, Koui uses retained mode:
 * - Elements are created once from JSON and persist in memory
 * - Direct property modification on elements (no handle lookups)
 * - Better performance for complex UIs
 *
 * Note: Koui.init() is automatically called in Main.hx via the armory_hooks.py
 * library hook system. The game startup is wrapped inside Koui.init() callback.
 */
@:access(koui.Koui, koui.elements.Element)
class KouiCanvas extends Trait {

	/** The canvas name (without .json extension) */
	public var cnvName: String;

	/** Map of element key -> Element for fast lookup */
	private var elementMap: Map<String, Element>;

	/** The root AnchorPane containing all canvas elements */
	private var rootPane: AnchorPane;

	/** Whether the canvas has finished loading */
	public var ready(get, null): Bool;
	private function get_ready(): Bool { return rootPane != null; }

	/** Callbacks to execute when canvas is ready */
	private var onReadyFuncs: Array<Void->Void> = null;

	/** Whether the canvas is visible */
	private var canvasVisible: Bool = true;

	// Settings
	var scaleOnResize: Bool = false;
	var autoExpand: Bool = false;
	var expandHorizontal: Bool = false;
	var expandVertical: Bool = false;

	var baseH: Int = 576;
	var baseW: Int = 1024;

	/**
	 * Create a new KouiCanvas trait.
	 * @param canvasName Name of the canvas (without .json extension)
	 */
	public function new(canvasName: String) {
		super();

		trace("[KouiCanvas] Initializing canvas: " + canvasName);

		cnvName = canvasName;
		elementMap = new Map();

		notifyOnInit(function() {
			// Load canvas JSON
			iron.data.Data.getBlob(canvasName + ".json", function(blob: kha.Blob) {
				if (blob == null) {
					trace('[KouiCanvas] Failed to load canvas: $canvasName.json');
					return;
				}

				var canvasData: TCanvasData = null;
				try {
					canvasData = haxe.Json.parse(blob.toString());
				} catch (e: Dynamic) {
					trace('[KouiCanvas] Failed to parse canvas JSON: $e');
					return;
				}

				try {
					buildCanvas(canvasData);
					trace('[KouiCanvas] Canvas loaded: $canvasName');
				} catch (e: Dynamic) {
					trace('[KouiCanvas] Failed to build canvas: $e');
				}
			});
		});

		notifyOnRender2D(function(g: kha.graphics2.Graphics) {
			if (!ready || !canvasVisible) return;

			// Execute ready callbacks (once per callback)
			if (onReadyFuncs != null && onReadyFuncs.length > 0) {
				for (f in onReadyFuncs) {
					f();
				}
				onReadyFuncs.resize(0);
			}
		});

		notifyOnRemove(function() {
			// Clean up when trait is removed
			if (rootPane != null) {
				Koui.remove(rootPane);
				rootPane = null;
			}
			elementMap.clear();
			if (scaleOnResize) App.resized.disconnect(onAppResized);
		});
	}

	/**
	 * Build the canvas from parsed JSON data.
	 */
	private function buildCanvas(canvasData: TCanvasData): Void {
		// Settings
		if (canvasData.canvas.settings != null) {
			scaleOnResize = canvasData.canvas.settings.scaleOnResize;
			autoExpand = canvasData.canvas.settings.autoExpand;
			expandHorizontal = canvasData.canvas.settings.expandHorizontal;
			expandVertical = canvasData.canvas.settings.expandVertical;
		}
		if (scaleOnResize != null && scaleOnResize) {
			App.resized.connect(onAppResized);
			baseH = canvasData.canvas.height;
			baseW = canvasData.canvas.width;
		}

		// Create root pane with canvas dimensions
		rootPane = new AnchorPane(0, 0, canvasData.canvas.width, canvasData.canvas.height);
		elementMap.set("AnchorPane", rootPane);

		// First pass: create all elements
		for (elemData in canvasData.elements) {
			var element: Element = createElementFromData(elemData);
			if (element != null) {
				elementMap.set(elemData.key, element);
			}
		}

		// Second pass: parent elements correctly
		for (elemData in canvasData.elements) {
			var element: Element = elementMap.get(elemData.key);
			if (element == null) continue;

			var parent: Element = rootPane;
			if (elemData.parentKey != null && elementMap.exists(elemData.parentKey)) {
				parent = elementMap.get(elemData.parentKey);
			}

			// Add to parent with correct anchor
			if (Std.isOfType(parent, AnchorPane)) {
				var anchorPane: AnchorPane = cast parent;
				anchorPane.add(element, cast elemData.anchor);
			} else {
				element.parent = parent;
				parent.children.push(element);
			}
		}

		// Add root pane to Koui's default layout
		Koui.add(rootPane, TopLeft);
	}

	/**
	 * Create an element from JSON data.
	 */
	private function createElementFromData(data: TElementsData): Element {
		var element: Element = null;

		switch (data.type) {
			case "Label":
				var label = new Label(data.properties.text != null ? data.properties.text : "");
				if (data.properties.alignmentHor != null) {
					label.alignmentHor = cast data.properties.alignmentHor;
				}
				if (data.properties.alignmentVert != null) {
					label.alignmentVert = cast data.properties.alignmentVert;
				}
				element = label;

			case "Button":
				var button = new Button(data.properties.text != null ? data.properties.text : "");
				if (data.properties.isToggle != null) {
					button.isToggle = data.properties.isToggle;
				}
				if (data.properties.isPressed != null) {
					button.isPressed = data.properties.isPressed;
				}
				element = button;

			case "AnchorPane":
				element = new AnchorPane(data.posX, data.posY, data.width, data.height);

			// TODO: Add more element types as needed:
			// case "Checkbox": ...
			// case "Slider": ...
			// case "TextInput": ...
			// case "Dropdown": ...

			default:
				trace('[KouiCanvas] Unknown element type: ${data.type}');
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

	function onAppResized(w: Int, h: Int): Void {
		if (expandHorizontal) {
			Koui.uiScale = w / baseH;
		} else if (expandVertical) {
			Koui.uiScale = h / baseW;
		} else {
			var scaleW = w / baseW;
			var scaleH = h / baseH;
			Koui.uiScale = Math.min(scaleW, scaleH);
		}
		Koui.onResize(w, h);
	}

	// =========================================================================
	// Public API
	// =========================================================================

	/**
	 * Register a callback to be executed when the canvas is ready.
	 * If the canvas is already ready, the callback is executed on the next render.
	 *
	 * @param f Callback function
	 */
	public function notifyOnReady(f: Void->Void): Void {
		if (onReadyFuncs == null) onReadyFuncs = [];
		onReadyFuncs.push(f);
	}

	/**
	 * Get an element by its key.
	 *
	 * @param key The element's unique key
	 * @return The element, or null if not found
	 */
	public function getElement(key: String): Null<Element> {
		return elementMap.get(key);
	}

	/**
	 * Get an element by its key, cast to a specific type.
	 * Returns null if the element doesn't exist or isn't of the requested type.
	 *
	 * Example:
	 * ```haxe
	 * var button = canvas.getElementAs(Button, "MyButton");
	 * if (button != null) button.text = "Clicked!";
	 * ```
	 *
	 * @param cls The class type to cast to
	 * @param key The element's unique key
	 * @return The element cast to type T, or null
	 */
	public function getElementAs<T: Element>(cls: Class<T>, key: String): Null<T> {
		var element = elementMap.get(key);
		if (element == null) return null;
		return Std.downcast(element, cls);
	}

	/**
	 * Get all element keys in this canvas.
	 *
	 * @return Iterator over all element keys
	 */
	public function getElementKeys(): Iterator<String> {
		return elementMap.keys();
	}

	/**
	 * Set whether the canvas is visible.
	 * Invisible canvases are not rendered and don't process events.
	 *
	 * @param visible Whether the canvas should be visible
	 */
	public function setCanvasVisible(visible: Bool): Void {
		canvasVisible = visible;
		if (rootPane != null) {
			rootPane.visible = visible;
		}
	}

	/**
	 * Get whether the canvas is visible.
	 *
	 * @return Whether the canvas is visible
	 */
	public function getCanvasVisible(): Bool {
		return canvasVisible;
	}

	/**
	 * Set the canvas dimensions.
	 *
	 * @param width The new width
	 * @param height The new height
	 */
	public function setCanvasDimensions(width: Int, height: Int): Void {
		if (rootPane != null) {
			rootPane.width = width;
			rootPane.height = height;
		}
	}

	/**
	 * Get the root AnchorPane of this canvas.
	 *
	 * @return The root pane, or null if canvas isn't ready
	 */
	public function getRoot(): Null<AnchorPane> {
		return rootPane;
	}

	/**
	 * Get the active KouiCanvas trait from the current scene or camera.
	 *
	 * @return The active KouiCanvas trait, or null if not found
	 */
	public static function getActiveCanvas(): Null<KouiCanvas> {
		var activeCanvas = iron.Scene.active.getTrait(KouiCanvas);
		if (activeCanvas == null) {
			activeCanvas = iron.Scene.active.camera.getTrait(KouiCanvas);
		}
		return activeCanvas;
	}

	// TODO: Consider adding hot-reload support in the future
	// This would allow reloading the canvas JSON at runtime for development
	// public function reloadCanvas(): Void { ... }
}
