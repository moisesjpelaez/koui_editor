package arm.data;

import arm.canvas.CanvasLoader;
import arm.tools.CanvasUtils;
import arm.types.Types;

import haxe.Json;

import koui.elements.Element;

/** The canvas at one point in the history. */
typedef TSnapshot = {
	/** The saved canvas, without the "active" scene flag (which scene is shown is not an edit). */
	var canvas: String;
	var scene: String;
	/** Paths of the selected elements in `scene`. */
	var selection: Array<String>;
}

/**
 * Undo and redo, as snapshots of the whole canvas.
 *
 * Code that changes the canvas calls `edited()`. The change is recorded as one
 * step by `commitPending()`, which the editor calls each frame while no mouse
 * button is held, so a drag is one step and so is everything an edit changes
 * as a side effect. Undo rebuilds the canvas from the previous snapshot.
 */
class History {
	static inline var MAX_STEPS: Int = 100;

	static var undoStack: Array<TSnapshot> = [];
	static var redoStack: Array<TSnapshot> = [];

	/** The canvas after the last recorded step. */
	static var current: TSnapshot = null;
	static var savedCanvas: String = null;

	static var pendingLabel: Null<String> = null;
	static var restoring: Bool = false;

	/** Marks the canvas as changed; the change is recorded by the next `commitPending()`. */
	public static function edited(label: String): Void {
		if (restoring) return;
		if (pendingLabel == null) pendingLabel = label;
	}

	public static inline function hasPendingEdit(): Bool {
		return pendingLabel != null;
	}

	/** Records the pending edit as one step, if it changed the canvas. */
	public static function commitPending(): Void {
		if (pendingLabel == null || current == null) return;
		pendingLabel = null;

		var after: TSnapshot = capture();
		if (after.canvas != current.canvas) {
			undoStack.push(current);
			if (undoStack.length > MAX_STEPS) undoStack.shift();
			redoStack.resize(0);
		}
		current = after;
	}

	/** Starts a new history from the current canvas, e.g. after loading one. */
	public static function reset(): Void {
		undoStack.resize(0);
		redoStack.resize(0);
		pendingLabel = null;
		current = capture();
		savedCanvas = current.canvas;
	}

	public static function canUndo(): Bool return undoStack.length > 0 || hasPendingEdit();
	public static function canRedo(): Bool return redoStack.length > 0;

	public static function undo(): Bool {
		commitPending();
		if (undoStack.length == 0) return false;
		redoStack.push(current);
		restore(undoStack.pop());
		return true;
	}

	public static function redo(): Bool {
		commitPending();
		if (redoStack.length == 0) return false;
		undoStack.push(current);
		restore(redoStack.pop());
		return true;
	}

	/**
	 * Whether the canvas differs from the last saved or loaded one, including a
	 * drag still going on. Doesn't record anything, so asking during a drag
	 * doesn't split it.
	 */
	public static function isDirty(): Bool {
		if (current == null) return false;
		return capture().canvas != savedCanvas;
	}

	/** Remembers the canvas as just saved (including a pending edit, which the file contains). */
	public static function markSaved(): Void {
		if (current != null) savedCanvas = capture().canvas;
	}

	/** Whether the canvas still matches the last recorded step, i.e. no change went unrecorded. */
	public static function isInSync(): Bool {
		return pendingLabel == null && current != null && capture().canvas == current.canvas;
	}

	static function capture(): TSnapshot {
		var data: TCanvasData = CanvasUtils.serializeCanvas();
		for (scene in data.scenes) scene.active = false;

		var sceneData: SceneData = SceneData.data;
		var scene: TSceneEntry = sceneData.currentScene;
		var selection: Array<String> = [];
		if (scene != null) {
			for (element in Selection.elements) selection.push(CanvasLoader.getPath(element, scene.root, scene.keys));
		}

		return {
			canvas: Json.stringify(data),
			scene: scene != null ? scene.key : null,
			selection: selection
		};
	}

	static function restore(snapshot: TSnapshot): Void {
		restoring = true;
		try {
			CanvasUtils.rebuildCanvas(Json.parse(snapshot.canvas), snapshot.scene);
		} catch (e: Dynamic) {
			// Otherwise every later edit would be ignored
			restoring = false;
			throw e;
		}
		restoring = false;
		current = snapshot;

		var scene: TSceneEntry = SceneData.data.currentScene;
		if (scene == null) return;
		var selected: Array<Element> = [];
		for (path in snapshot.selection) {
			var element: Element = CanvasLoader.findByPath(scene.root, scene.keys, path);
			if (element != null) selected.push(element);
		}
		Selection.setAll(selected);
	}
}
