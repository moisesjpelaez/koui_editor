package armory.trait.internal;

import arm.canvas.CanvasLoader;
import arm.tools.HierarchyUtils;
import arm.types.Types;
import iron.App;
import iron.Trait;
import koui.Koui;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.GridLayout;
import koui.elements.layouts.Layout.Anchor;
import koui.events.FocusEvent;
import koui.events.MouseEvent.MouseClickEvent;
import koui.events.MouseEvent.MouseHoverEvent;
import koui.utils.RadioGroup;
import koui.utils.SceneManager;


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
@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.GridLayout)
class KouiCanvas extends Trait {
	/** The canvas name (without .json extension) */
	public var cnvName: String;

	/** All scenes in this canvas */
	private var scenes: Map<String, TBuiltScene>;

	/** Global radio groups shared across all scenes */
	private var radioGroups: Map<String, RadioGroup>;

	/** The currently active scene */
	private var currentScene: TBuiltScene;

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
		radioGroups = new Map();

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
				} catch (e: Dynamic) {
					// Nothing half-built stays on screen
					trace('[KouiCanvas] Failed to build canvas "$canvasName": $e');
					clearCanvas();
					return;
				}
				trace('[KouiCanvas] Canvas loaded: $canvasName');

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
		clearCanvas();
	}

	/** Removes and frees this canvas' scenes (only its own: other canvases keep theirs). */
	function clearCanvas(): Void {
		for (scene in scenes) {
			SceneManager.removeScene(scene.key);
			if (scene.root != null) scene.root.destroy();
		}
		scenes.clear();
		radioGroups.clear();
		currentScene = null;
		if (expandOnResize) App.resized.disconnect(onAppResized);
	}

	/**
	 * Build the canvas from parsed JSON data.
	 */
	private function buildCanvas(canvasData: TCanvasData): Void {
		// Settings
		expandOnResize = canvasData.canvas.settings.expandOnResize;
		scaleOnResize = canvasData.canvas.settings.scaleOnResize;
		scaleHorizontal = canvasData.canvas.settings.scaleHorizontal;
		scaleVertical = canvasData.canvas.settings.scaleVertical;
		if (expandOnResize) {
			App.resized.connect(onAppResized);
			baseH = canvasData.canvas.height;
			baseW = canvasData.canvas.width;
			onAppResized(App.w(), App.h());
		}

		// An ImagePanel shows nothing if its image isn't loaded (e.g. with Assets.loadEverything) before the canvas
		var reported: Array<String> = [];
		for (sceneData in canvasData.scenes) {
			for (element in sceneData.elements) {
				if (element.type != "ImagePanel") continue;
				var name: String = element.properties.imageName;
				if (name == null || name == "" || reported.indexOf(name) >= 0 || Koui.getImage(name) != null) continue;
				reported.push(name);
				trace('[KouiCanvas] Image "$name" is not loaded; load it before the canvas "$cnvName" to show it');
			}
		}

		// Each scene is built into a Koui scene; registered first, so one that fails to build is still cleaned up
		var built: TBuiltCanvas = CanvasLoader.buildCanvas(canvasData, key -> {
			var scene: TBuiltScene = { key: key, root: null, keys: new Map() };
			scenes.set(key, scene);
			SceneManager.addScene(key, pane -> {
				pane.setSize(canvasData.canvas.width, canvasData.canvas.height);
				scene.root = pane;
			});
			return scene.root;
		});
		for (scene in built.scenes) scenes.set(scene.key, scene);
		for (group in built.radioGroups) radioGroups.set(group.id, group);

		if (built.activeScene != null) setScene(built.activeScene);
	}

	function onAppResized(w: Int, h: Int): Void {
		if (scaleOnResize) {
			if (scaleHorizontal) {
				Koui.uiScale = w / baseW;
			} else if (scaleVertical) {
				Koui.uiScale = h / baseH;
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
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) {
			trace('[KouiCanvas] Scene not found: "$sceneName"');
			return false;
		}

		SceneManager.setScene(sceneName);
		// setScene shows the scene, also when the canvas is hidden
		scene.root.visible = canvasVisible;
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
	// Element Access
	// -------------------------------------------------------------------------

	/**
	 * Get an element by its path: the element names from the scene root down,
	 * joined by "/".
	 *
	 * - "player_ui" (an element directly in the scene root)
	 * - "player_ui/health_bar" (nested element)
	 * - "menu/buttons/play_button" (nested deeper)
	 *
	 * @param path The element's path
	 * @param sceneName The scene to look in; the current scene if omitted
	 * @return The element, or null if not found
	 */
	public function getElement(path: String, ?sceneName: String): Null<Element> {
		var scene: TBuiltScene = getSceneForAccess(sceneName);
		if (scene == null) return null;

		var element: Element = CanvasLoader.findByPath(scene.root, scene.keys, path);
		if (element == null) {
			trace('[KouiCanvas] Element not found: "$path" in scene "${scene.key}" (nested elements need their path, e.g. "parent/$path")');
		}
		return element;
	}

	/**
	 * Get an element by its path, cast to a specific type.
	 * Returns null if the element doesn't exist or isn't of the requested type.
	 *
	 * Example:
	 * ```haxe
	 * var button = canvas.getElementAs(Button, "menu/buttons/play_button");
	 * var score = canvas.getElementAs(Label, "score", "hud");
	 * ```
	 *
	 * @param cls The class type to cast to
	 * @param path The element's path
	 * @param sceneName The scene to look in; the current scene if omitted
	 * @return The element cast to type T, or null
	 */
	public function getElementAs<T: Element>(cls: Class<T>, path: String, ?sceneName: String): Null<T> {
		var element: Element = getElement(path, sceneName);
		if (element == null) return null;
		var casted = Std.downcast(element, cls);
		if (casted == null) trace('[KouiCanvas] Element "$path" is not of type ${Type.getClassName(cls)}');
		return casted;
	}

	/**
	 * Get all element paths in a scene (e.g., "player_ui/health_bar").
	 * Elements directly in the scene root return just their name.
	 *
	 * @param sceneName The scene to list; the current scene if omitted
	 * @return Array of all element paths
	 */
	public function getElementKeys(?sceneName: String): Array<String> {
		var scene: TBuiltScene = getSceneForAccess(sceneName);
		if (scene == null) return [];
		var paths: Array<String> = [];
		collectElementPaths(scene, scene.root, "", paths);
		return paths;
	}

	/**
	 * Internal helper to recursively collect element paths.
	 */
	private function collectElementPaths(scene: TBuiltScene, parent: Element, parentPath: String, output: Array<String>): Void {
		for (child in HierarchyUtils.getChildren(parent)) {
			var childKey = scene.keys.get(child);
			if (childKey == null) continue;

			// Build the full path
			var fullPath = CanvasLoader.joinPath(parentPath, childKey);
			output.push(fullPath);

			// Recursively collect from this child's children
			collectElementPaths(scene, child, fullPath, output);
		}
	}

	/** The named scene, or the current one if `sceneName` is null; traces why if there is none. */
	private function getSceneForAccess(sceneName: Null<String>): Null<TBuiltScene> {
		if (sceneName == null) {
			if (currentScene == null) trace('[KouiCanvas] No scene active');
			return currentScene;
		}
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) trace('[KouiCanvas] Scene not found: "$sceneName"');
		return scene;
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
	 * Add an element made in code to a scene, at the scene's root or inside
	 * a container made in the editor (AnchorPane, RowLayout, ColLayout, Panel).
	 *
	 * Example:
	 * ```haxe
	 * var imagePanel = new koui.elements.ImagePanel(kha.Assets.images.logo);
	 * imagePanel.setPosition(100, 50);
	 * imagePanel.setSize(200, 150);
	 * canvas.addElement("Scene_1", "logo_image", imagePanel);
	 *
	 * // Centered, inside a container made in the editor:
	 * canvas.addElement("Scene_1", "icon", imagePanel, Anchor.MiddleCenter, "header/icons");
	 * ```
	 *
	 * @param sceneName The scene to add the element to
	 * @param key The element's name; unique among its siblings, not empty, without "/"
	 * @param element The element to add
	 * @param anchor The element's anchor
	 * @param parentKey The path of the container to add it to; the scene's root if null
	 * @return True if added, false otherwise (the reason is traced)
	 */
	public function addElement(sceneName: String, key: String, element: Element, anchor: Anchor = Anchor.TopLeft, parentKey: String = null): Bool {
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) {
			trace('[KouiCanvas] Scene not found: "$sceneName"');
			return false;
		}

		if (key == null || key == "" || key.indexOf("/") >= 0) {
			trace('[KouiCanvas] Invalid element name "$key": names can\'t be empty or contain "/"');
			return false;
		}

		element.anchor = anchor;

		// Find parent
		var parent: Element = null;
		if (parentKey != null) {
			parent = getElement(parentKey, sceneName);
			if (parent == null) {
				trace('[KouiCanvas] Parent not found: "$parentKey" in scene "$sceneName"');
				return false;
			}
		} else {
			parent = scene.root;
		}

		// Names only need to be unique among siblings
		for (sibling in HierarchyUtils.getChildren(parent)) {
			if (scene.keys.get(sibling) == key) {
				trace('[KouiCanvas] Element key "$key" already exists in "${parentKey != null ? parentKey : sceneName}"');
				return false;
			}
		}

		// Same as loading a canvas: Row/Col layouts get a new slot, Panels a new child
		if (parent == scene.root) {
			scene.root.add(element, anchor);
		} else if (HierarchyUtils.canAcceptChild(parent)) {
			HierarchyUtils.moveAsChild(element, parent);
		} else {
			trace('[KouiCanvas] Parent "$parentKey" can\'t contain elements');
			return false;
		}

		// Register in scene
		scene.keys.set(element, key);

		return true;
	}

	/**
	 * Set the z-index/render order of an element relative to its siblings.
	 * Index 0 renders first (back), higher indices render later (front).
	 *
	 * @param sceneName The scene containing the element
	 * @param keyOrPath The element's key or path
	 * @param index The desired index (0 = back, high = front)
	 * @return True if moved successfully, false otherwise
	 */
	public function setElementZIndex(sceneName: String, keyOrPath: String, index: Int): Bool {
		var element: Element = getElement(keyOrPath, sceneName);
		if (element == null) return false;

		var parent: Element = HierarchyUtils.getParentElement(element);
		if (parent == null) return false;

		// Row/Col cells are placed side by side, not drawn over each other
		if (Std.isOfType(parent, GridLayout)) {
			trace('[KouiCanvas] Z-order control not supported for GridLayout/RowLayout/ColLayout');
			return false;
		}
		var children: Array<Element> = HierarchyUtils.getChildren(parent);

		// Clamp index
		if (index < 0) index = 0;
		if (index >= children.length) index = children.length - 1;

		// Move to desired index
		children.remove(element);
		children.insert(index, element);
		HierarchyUtils.setChildren(parent, children);

		return true;
	}

	/**
	 * Remove an element, with everything inside it, from a scene and free it.
	 * To hide an element for a while, set its `visible` to false instead.
	 *
	 * @param sceneName The scene containing the element
	 * @param keyOrPath The element's path (just its name if it's in the scene's root)
	 * @return True if removed, false if it wasn't found
	 */
	public function removeElement(sceneName: String, keyOrPath: String): Bool {
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) return false;

		var element: Element = CanvasLoader.findByPath(scene.root, scene.keys, keyOrPath);
		if (element == null) return false;

		// Detached the way the editor does it (Row/Col layouts close the gap), then freed
		HierarchyUtils.detachFromCurrentParent(element);
		forgetKeys(scene, element);
		element.destroy();

		return true;
	}

	/** Removes the names of `element` and everything inside it. */
	function forgetKeys(scene: TBuiltScene, element: Element): Void {
		for (child in HierarchyUtils.getChildren(element)) forgetKeys(scene, child);
		scene.keys.remove(element);
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

}

class ElementExt {
	public static inline function onPressed(element: Element, callback: Void->Void) {
		element.addEventListener(MouseClickEvent, function(e: MouseClickEvent) {
			if (e.getState() == ClickStart) callback();
		});
	}

	public static inline function onHover(element: Element, callback: Void->Void) {
		element.addEventListener(MouseHoverEvent, function(e: MouseHoverEvent) {
			if (e.getState() == HoverStart) callback();
		});
	}

	public static inline function onFocus(element: Element, callback: Void->Void) {
		element.addEventListener(FocusEvent, function(e: FocusEvent) {
			if (e.getState() == FocusGet) callback();
		});
	}

	public static inline function onHold(element: Element, callback: Void->Void) {
		element.addEventListener(MouseClickEvent, function(e: MouseClickEvent) {
			if (e.getState() == ClickHold) callback();
		});
	}

	public static inline function onReleased(element: Element, callback: Void->Void) {
		element.addEventListener(MouseClickEvent, function(e: MouseClickEvent) {
			if (e.getState() == ClickEnd) callback();
		});
	}
}
