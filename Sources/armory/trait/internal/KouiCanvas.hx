package armory.trait.internal;

import armory.system.Signal;
import iron.App;
import iron.Trait;
import koui.Koui;
import koui.elements.Element;
import koui.elements.Button;
import koui.elements.Label;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;
import koui.events.MouseEvent.MouseClickEvent;
import koui.utils.SceneManager;

// JSON structure typedefs (matching CanvasUtils format)
private typedef TCanvasData = {
	var name: String;
	var version: String;
	var canvas: TCanvasSettings;
	var scenes: Array<TSceneData>;
}

private typedef TCanvasSettings = {
	var width: Int;
	var height: Int;
	var settings: TSettings;
}

private typedef TSettings = {
	var expandOnResize: Bool;
	var scaleOnResize: Bool;
	var autoScale: Bool;
	var scaleHorizontal: Bool;
	var scaleVertical: Bool;
}

private typedef TSceneData = {
	var key: String;
	var elements: Array<TElementData>;
}

private typedef TElementData = {
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

// KouiCanvas types
typedef TButton = {
	var element: Button;
	var onPressed: Signal;
	var onHold: Signal;
	var onReleased: Signal;
}

enum abstract ButtonEvent(Int) from Int to Int {
	var Pressed = 0;
	var Hold = 1;
	var Released = 2;
}

// Runtime scene storage
private typedef TKouiScene = {
	var key: String;
	var root: AnchorPane;
	var elements: Map<String, Element>;
	var buttons: Map<String, TButton>;
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
 * Supports multiple scenes within a single canvas. Use setScene() to switch
 * between scenes at runtime. The first scene is automatically activated on load.
 *
 * Note: Koui.init() is automatically called in Main.hx via the armory_hooks.py
 * library hook system. The game startup is wrapped inside Koui.init() callback.
 */
@:access(koui.Koui, koui.elements.Element)
class KouiCanvas extends Trait {

	/** The canvas name (without .json extension) */
	public var cnvName: String;

	/** All scenes in this canvas */
	private var scenes: Map<String, TKouiScene>;

	/** The currently active scene */
	private var currentScene: TKouiScene;

	/** Whether the canvas has finished loading */
	public var ready(get, null): Bool;
	private function get_ready(): Bool { return currentScene != null; }

	/** Callbacks to execute when canvas is ready */
	private var onReadyFuncs: Array<Void->Void> = null;

	/** Whether the canvas is visible */
	private var canvasVisible: Bool = true;

	// Settings
	var expandOnResize: Bool = false;
	var scaleOnResize: Bool = false;
	var autoScale: Bool = false;
	var scaleHorizontal: Bool = false;
	var scaleVertical: Bool = false;

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
		scenes = new Map();

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

				notifyOnRender2D(render2D);
				notifyOnRemove(onRemove);
			});
		});

	}

	function render2D(g: kha.graphics2.Graphics): Void {
		if (!ready || !canvasVisible) return;

		// Execute ready callbacks (once per callback)
		if (onReadyFuncs != null && onReadyFuncs.length > 0) {
			for (f in onReadyFuncs) {
				f();
			}
			onReadyFuncs.resize(0);
		}
	}

	function onRemove(): Void {
		// Clean up when trait is removed
		SceneManager.clearScenes();
		scenes.clear();
		currentScene = null;
		if (expandOnResize) App.resized.disconnect(onAppResized);
	}

	/**
	 * Build the canvas from parsed JSON data.
	 */
	private function buildCanvas(canvasData: TCanvasData): Void {
		// Settings
		if (canvasData.canvas.settings != null) {
			expandOnResize = canvasData.canvas.settings.expandOnResize;
			scaleOnResize = canvasData.canvas.settings.scaleOnResize;
			autoScale = canvasData.canvas.settings.autoScale;
			scaleHorizontal = canvasData.canvas.settings.scaleHorizontal;
			scaleVertical = canvasData.canvas.settings.scaleVertical;
		}
		if (expandOnResize != null && expandOnResize) {
			App.resized.connect(onAppResized);
			baseH = canvasData.canvas.height;
			baseW = canvasData.canvas.width;
		}

		// Build each scene
		var isFirst: Bool = true;
		for (sceneData in canvasData.scenes) {
			buildScene(sceneData, canvasData.canvas.width, canvasData.canvas.height, isFirst);
			isFirst = false;
		}
	}

	/**
	 * Build a single scene from JSON data.
	 */
	private function buildScene(sceneData: TSceneData, canvasWidth: Int, canvasHeight: Int, isFirst: Bool): Void {
		var sceneKey: String = sceneData.key;

		// Create scene storage
		var kouiScene: TKouiScene = {
			key: sceneKey,
			root: null,
			elements: new Map(),
			buttons: new Map()
		};

		// Use SceneManager to create the scene
		SceneManager.addScene(sceneKey, function(scenePane: AnchorPane) {
			scenePane.setSize(canvasWidth, canvasHeight);
			kouiScene.root = scenePane;
			kouiScene.elements.set(sceneKey, scenePane);

			// First pass: create all elements
			for (elemData in sceneData.elements) {
				var element: Element = createElementFromData(elemData, kouiScene);
				if (element != null) {
					kouiScene.elements.set(elemData.key, element);
				}
			}

			// Second pass: parent elements correctly
			for (elemData in sceneData.elements) {
				var element: Element = kouiScene.elements.get(elemData.key);
				if (element == null) continue;

				var parent: Element = scenePane;
				if (elemData.parentKey != null && kouiScene.elements.exists(elemData.parentKey)) {
					parent = kouiScene.elements.get(elemData.parentKey);
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
		});

		// Store scene
		scenes.set(sceneKey, kouiScene);

		// First scene becomes active
		if (isFirst) {
			currentScene = kouiScene;
		}
	}

	/**
	 * Create an element from JSON data.
	 */
	private function createElementFromData(data: TElementData, kouiScene: TKouiScene): Element {
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
				var btn: TButton = {
					element: button,
					onPressed: new Signal(),
					onHold: new Signal(),
					onReleased: new Signal()
				}
				kouiScene.buttons.set(data.key, btn);

				if (data.properties.isToggle != null) {
					button.isToggle = data.properties.isToggle;
				}
				if (data.properties.isPressed != null) {
					button.isPressed = data.properties.isPressed;
				}

				button.addEventListener(MouseClickEvent, function(e: MouseClickEvent) {
					switch (e.getState()) {
						case ClickStart:
							btn.onPressed.emit();
						case ClickHold:
							btn.onHold.emit();
						case ClickEnd:
							btn.onReleased.emit();
						default:
					}
				});

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
		if (scaleOnResize) {
			if (scaleHorizontal) {
				Koui.uiScale = w / baseH;
			} else if (scaleVertical) {
				Koui.uiScale = h / baseW;
			} else {
				var scaleW = w / baseW;
				var scaleH = h / baseH;
				Koui.uiScale = Math.min(scaleW, scaleH);
			}
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

	// -------------------------------------------------------------------------
	// Scene Management
	// -------------------------------------------------------------------------

	/**
	 * Switch to a different scene by name.
	 * The previous scene is hidden and the new scene is shown.
	 *
	 * @param sceneName The name of the scene to switch to
	 * @return True if the scene was found and switched, false otherwise
	 */
	public function setScene(sceneName: String): Bool {
		var scene: TKouiScene = scenes.get(sceneName);
		if (scene == null) {
			trace('[KouiCanvas] Scene not found: "$sceneName"');
			return false;
		}

		SceneManager.setScene(sceneName);
		currentScene = scene;
		return true;
	}

	/**
	 * Get the name of the currently active scene.
	 *
	 * @return The current scene name, or null if no scene is active
	 */
	public function getCurrentSceneName(): Null<String> {
		return currentScene != null ? currentScene.key : null;
	}

	/**
	 * Get all scene names in this canvas.
	 *
	 * @return Array of scene names
	 */
	public function getSceneNames(): Array<String> {
		var names: Array<String> = [];
		for (key in scenes.keys()) {
			names.push(key);
		}
		return names;
	}

	// -------------------------------------------------------------------------
	// Element Access (Current Scene)
	// -------------------------------------------------------------------------

	/**
	 * Get an element by its key from the current scene.
	 *
	 * @param key The element's unique key
	 * @return The element, or null if not found
	 */
	public function getElement(key: String): Null<Element> {
		if (currentScene == null) {
			trace('[KouiCanvas] No scene active');
			return null;
		}
		var element: Element = currentScene.elements.get(key);
		if (element == null) trace('[KouiCanvas] Element not found: "$key" in scene "${currentScene.key}"');
		return element;
	}

	/**
	 * Get an element by its key from the current scene, cast to a specific type.
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
		var element: Element = getElement(key);
		if (element == null) return null;
		var casted = Std.downcast(element, cls);
		if (casted == null) trace('[KouiCanvas] Element "$key" is not of type ${Type.getClassName(cls)}');
		return casted;
	}

	/**
	 * Get a button from the current scene with its signal handlers.
	 *
	 * @param key The button's unique key
	 * @return The TButton with signals, or null if not found
	 */
	public function getButton(key: String): Null<TButton> {
		if (currentScene == null) {
			trace('[KouiCanvas] No scene active');
			return null;
		}
		var btn: TButton = currentScene.buttons.get(key);
		if (btn == null) {
			trace('[KouiCanvas] Button not found: "$key" in scene "${currentScene.key}"');
			return null;
		}
		return btn;
	}

	/**
	 * Get all element keys in the current scene.
	 *
	 * @return Iterator over all element keys
	 */
	public function getElementKeys(): Iterator<String> {
		if (currentScene == null) return [].iterator();
		return currentScene.elements.keys();
	}

	// -------------------------------------------------------------------------
	// Cross-Scene Element Access
	// -------------------------------------------------------------------------

	/**
	 * Get an element by its key from a specific scene.
	 * Use this for cross-scene element access.
	 *
	 * @param sceneName The scene to look in
	 * @param key The element's unique key
	 * @return The element, or null if not found
	 */
	public function getElementFromScene(sceneName: String, key: String): Null<Element> {
		var scene: TKouiScene = scenes.get(sceneName);
		if (scene == null) {
			trace('[KouiCanvas] Scene not found: "$sceneName"');
			return null;
		}
		var element: Element = scene.elements.get(key);
		if (element == null) trace('[KouiCanvas] Element not found: "$key" in scene "$sceneName"');
		return element;
	}

	/**
	 * Get a button from a specific scene with its signal handlers.
	 *
	 * @param sceneName The scene to look in
	 * @param key The button's unique key
	 * @return The TButton with signals, or null if not found
	 */
	public function getButtonFromScene(sceneName: String, key: String): Null<TButton> {
		var scene: TKouiScene = scenes.get(sceneName);
		if (scene == null) {
			trace('[KouiCanvas] Scene not found: "$sceneName"');
			return null;
		}
		var btn: TButton = scene.buttons.get(key);
		if (btn == null) {
			trace('[KouiCanvas] Button not found: "$key" in scene "$sceneName"');
			return null;
		}
		return btn;
	}

	// -------------------------------------------------------------------------
	// Canvas Properties
	// -------------------------------------------------------------------------

	/**
	 * Set whether the canvas is visible.
	 * Invisible canvases are not rendered and don't process events.
	 *
	 * @param visible Whether the canvas should be visible
	 */
	public function setCanvasVisible(visible: Bool): Void {
		canvasVisible = visible;
		if (currentScene != null && currentScene.root != null) {
			currentScene.root.visible = visible;
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
	 * Set the canvas dimensions for all scenes.
	 *
	 * @param width The new width
	 * @param height The new height
	 */
	public function setCanvasDimensions(width: Int, height: Int): Void {
		for (scene in scenes) {
			if (scene.root != null) {
				scene.root.width = width;
				scene.root.height = height;
			}
		}
	}

	/**
	 * Get the root AnchorPane of the current scene.
	 *
	 * @return The root pane, or null if no scene is active
	 */
	public function getRoot(): Null<AnchorPane> {
		return currentScene != null ? currentScene.root : null;
	}

	/**
	 * Get the active KouiCanvas trait from the current scene or camera.
	 *
	 * @return The active KouiCanvas trait, or null if not found
	 */
	public static function getActiveCanvas(): Null<KouiCanvas> {
		var activeCanvas: Null<KouiCanvas> = iron.Scene.active.getTrait(KouiCanvas);
		if (activeCanvas == null) {
			activeCanvas = iron.Scene.active.camera.getTrait(KouiCanvas);
		}
		return activeCanvas;
	}

	// TODO: Consider adding hot-reload support in the future
	// This would allow reloading the canvas JSON at runtime for development
	// public function reloadCanvas(): Void { ... }
}
