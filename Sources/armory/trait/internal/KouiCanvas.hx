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
 * Loads a canvas saved by the Koui Editor and shows its scenes.
 *
 * The scene saved as active is shown first; `setScene` switches scenes.
 * Koui itself is started and drawn by the code armory_hooks.py adds to
 * Main.hx; this trait only builds the canvas.
 */
@:access(koui.Koui, koui.elements.Element, koui.elements.layouts.GridLayout)
class KouiCanvas extends Trait {
	// The canvas name, without ".json"
	public var cnvName: String;

	private var scenes: Map<String, TBuiltScene>;
	// Shared by all scenes
	private var radioGroups: Map<String, RadioGroup>;
	private var currentScene: TBuiltScene;

	public var ready(get, null): Bool;
	private function get_ready(): Bool { return currentScene != null; }

	private var onReadyFuncs: Array<Void->Void> = null;
	private var canvasVisible: Bool = true;

	var expandOnResize: Bool = false;
	var scaleOnResize: Bool = false;
	var scaleHorizontal: Bool = false;
	var scaleVertical: Bool = false;

	var baseH: Int = 576;
	var baseW: Int = 1024;

	public function new(canvasName: String) {
		super();

		trace("[KouiCanvas] Initializing canvas: " + canvasName);

		cnvName = canvasName;
		scenes = new Map();
		radioGroups = new Map();

		notifyOnInit(function() {
			// Kha rather than Iron's Data.getBlob, which doesn't report a missing file
			var path: String = @:privateAccess iron.data.Data.resolvePath(canvasName + ".json");
			kha.Assets.loadBlobFromPath(path, function(blob: kha.Blob) {
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
			}, function(error: kha.AssetError) {
				trace('[KouiCanvas] Failed to load canvas "$canvasName": $path not found (${error.error})');
			});
		});

	}

	function render2D(g: kha.graphics2.Graphics): Void {
		if (!ready) return;

		// Each callback runs once, also while the canvas is hidden
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

	// Removes and frees this canvas' scenes; other canvases keep theirs
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

	private function buildCanvas(canvasData: TCanvasData): Void {
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

		// An ImagePanel shows nothing if its image isn't loaded before the canvas
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

		// Scenes are registered before they're built, so one that fails to build is still cleaned up
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

		// The first scene if none is saved as active (a hand-edited file)
		var activeScene: Null<String> = built.activeScene != null ? built.activeScene : (built.scenes.length > 0 ? built.scenes[0].key : null);
		if (activeScene != null) setScene(activeScene);
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

	// Calls `f` once the canvas is loaded; if it already is, on the next frame
	public function notifyOnReady(f: Void->Void): Void {
		if (onReadyFuncs == null) onReadyFuncs = [];
		onReadyFuncs.push(f);
	}

	// Scenes

	// Shows the scene `sceneName` instead of the current one. Returns false if there is no such scene
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

	// The current scene's name, or null if no scene is shown
	public function getCurrentSceneName(): Null<String> {
		return currentScene != null ? currentScene.key : null;
	}

	public function getSceneNames(): Array<String> {
		var names: Array<String> = [];
		for (key in scenes.keys()) {
			names.push(key);
		}
		return names;
	}

	// Elements

	/**
	 * The element at `path`: the names from the scene root down, joined by "/"
	 * (e.g. "menu/buttons/play"). Looks in the current scene if `sceneName`
	 * is omitted. Returns null if not found.
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
	 * Like `getElement`, cast to `cls`; null if the element isn't one.
	 *
	 * ```haxe
	 * var button = canvas.getElementAs(Button, "menu/buttons/play");
	 * var score = canvas.getElementAs(Label, "score", "hud");
	 * ```
	 */
	public function getElementAs<T: Element>(cls: Class<T>, path: String, ?sceneName: String): Null<T> {
		var element: Element = getElement(path, sceneName);
		if (element == null) return null;
		var casted = Std.downcast(element, cls);
		if (casted == null) trace('[KouiCanvas] Element "$path" is not of type ${Type.getClassName(cls)}');
		return casted;
	}

	// The paths of all elements in a scene, the current one if `sceneName` is omitted
	public function getElementKeys(?sceneName: String): Array<String> {
		var scene: TBuiltScene = getSceneForAccess(sceneName);
		if (scene == null) return [];
		var paths: Array<String> = [];
		collectElementPaths(scene, scene.root, "", paths);
		return paths;
	}

	private function collectElementPaths(scene: TBuiltScene, parent: Element, parentPath: String, output: Array<String>): Void {
		for (child in HierarchyUtils.getChildren(parent)) {
			var childKey = scene.keys.get(child);
			if (childKey == null) continue;

			var fullPath = CanvasLoader.joinPath(parentPath, childKey);
			output.push(fullPath);
			collectElementPaths(scene, child, fullPath, output);
		}
	}

	// The named scene, or the current one if `sceneName` is null; traces why if there is none
	private function getSceneForAccess(sceneName: Null<String>): Null<TBuiltScene> {
		if (sceneName == null) {
			if (currentScene == null) trace('[KouiCanvas] No scene active');
			return currentScene;
		}
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) trace('[KouiCanvas] Scene not found: "$sceneName"');
		return scene;
	}

	// Canvas

	// A hidden canvas isn't drawn and doesn't get input
	public function setCanvasVisible(visible: Bool): Void {
		canvasVisible = visible;
		if (currentScene != null && currentScene.root != null) {
			currentScene.root.visible = visible;
		}
	}

	public function getCanvasVisible(): Bool {
		return canvasVisible;
	}

	// Sets the size of every scene
	public function setCanvasDimensions(width: Int, height: Int): Void {
		for (scene in scenes) {
			if (scene.root != null) {
				scene.root.width = width;
				scene.root.height = height;
			}
		}
	}

	// The current scene's root pane, or null if no scene is shown
	public function getRoot(): Null<AnchorPane> {
		return currentScene != null ? currentScene.root : null;
	}

	/**
	 * Adds an element made in code to a scene: to its root, or to the container
	 * at `parentKey` (AnchorPane, RowLayout, ColLayout, Panel).
	 *
	 * ```haxe
	 * var logo = new koui.elements.ImagePanel(kha.Assets.images.logo);
	 * logo.setPosition(100, 50);
	 * canvas.addElement("Scene_1", "logo", logo);
	 * canvas.addElement("Scene_1", "icon", icon, Anchor.MiddleCenter, "header/icons");
	 * ```
	 *
	 * @param key The element's name: not empty, without "/", unique among its siblings
	 * @return False if it couldn't be added; the reason is traced
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

		for (sibling in HierarchyUtils.getChildren(parent)) {
			if (scene.keys.get(sibling) == key) {
				trace('[KouiCanvas] Element key "$key" already exists in "${parentKey != null ? parentKey : sceneName}"');
				return false;
			}
		}

		// As when loading: Row/Col layouts get a new cell, Panels a new child
		if (parent == scene.root) {
			scene.root.add(element, anchor);
		} else if (HierarchyUtils.canAcceptChild(parent)) {
			HierarchyUtils.moveAsChild(element, parent);
		} else {
			trace('[KouiCanvas] Parent "$parentKey" can\'t contain elements');
			return false;
		}

		scene.keys.set(element, key);
		return true;
	}

	/**
	 * Moves an element to `index` among its siblings: 0 is drawn first (at the
	 * back). Not for elements in a Row/Col layout. Returns false if it wasn't moved.
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

		if (index < 0) index = 0;
		if (index >= children.length) index = children.length - 1;

		children.remove(element);
		children.insert(index, element);
		HierarchyUtils.setChildren(parent, children);

		return true;
	}

	/**
	 * Removes an element and everything inside it, and frees them. To hide an
	 * element for a while, set its `visible` instead. Returns false if not found.
	 */
	public function removeElement(sceneName: String, keyOrPath: String): Bool {
		var scene: TBuiltScene = scenes.get(sceneName);
		if (scene == null) return false;

		var element: Element = CanvasLoader.findByPath(scene.root, scene.keys, keyOrPath);
		if (element == null) return false;

		// Row/Col layouts close the gap
		HierarchyUtils.detachFromCurrentParent(element);
		forgetKeys(scene, element);
		element.destroy();

		return true;
	}

	// Removes the names of `element` and everything inside it
	function forgetKeys(scene: TBuiltScene, element: Element): Void {
		for (child in HierarchyUtils.getChildren(element)) forgetKeys(scene, child);
		scene.keys.remove(element);
	}

	// The KouiCanvas on the active scene or its camera, or null
	public static function getActiveCanvas(): Null<KouiCanvas> {
		var activeCanvas: Null<KouiCanvas> = iron.Scene.active.getTrait(KouiCanvas);
		if (activeCanvas == null && iron.Scene.active.camera != null) {
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
