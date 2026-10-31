package arm.canvas;

import arm.tools.HierarchyUtils;
import arm.types.Types;

import koui.elements.Element;
import koui.elements.RadioButton;
import koui.elements.layouts.AnchorPane;
import koui.utils.RadioGroup;

/** A built scene: its root pane and the name of each element in it. */
typedef TBuiltScene = {
	var key: String;
	var root: AnchorPane;
	var keys: Map<Element, String>;
}

/** A built canvas: its scenes and radio groups, in saved order. */
typedef TBuiltCanvas = {
	var scenes: Array<TBuiltScene>;
	/** The saved groups, then any group a radio button names that the canvas didn't list. */
	var radioGroups: Array<RadioGroup>;
	/** The scene saved as shown, or null if none is. */
	var activeScene: Null<String>;
}

/** Elements built under a container: each one's name, and each one by its path below the container. */
typedef TBuiltTree = {
	var keys: Map<Element, String>;
	var byPath: Map<String, Element>;
}

/**
 * Builds canvases saved by the Koui Editor. Shared by the editor (loading,
 * undo, paste) and the game runtime, so all build exactly the same element
 * tree. Invalid data is reported with an exception naming the problem,
 * nothing is guessed.
 */
class CanvasLoader {
	/** Written to saved canvases; loading doesn't check it. */
	public static inline var VERSION: String = "2.0";

	/**
	 * Builds every scene of `data`, each into the root pane `makeRoot` returns
	 * for its name, and checks each group's active radio button. On an error the
	 * panes `makeRoot` made are left to the caller.
	 */
	public static function buildCanvas(data: TCanvasData, makeRoot: String->AnchorPane): TBuiltCanvas {
		var radioGroups: Array<RadioGroup> = [for (groupData in data.radioGroups) new RadioGroup(groupData.id)];
		var groupMap: Map<String, RadioGroup> = [for (group in radioGroups) group.id => group];

		var scenes: Array<TBuiltScene> = [];
		var byKey: Map<String, TBuiltScene> = new Map();
		var activeScene: Null<String> = null;
		for (sceneData in data.scenes) {
			if (byKey.exists(sceneData.key)) throw 'two scenes are named "${sceneData.key}"';
			var root: AnchorPane = makeRoot(sceneData.key);
			var tree: TBuiltTree = buildTree(sceneData.elements, root, groupMap, 'scene "${sceneData.key}"');
			var scene: TBuiltScene = { key: sceneData.key, root: root, keys: tree.keys };
			scenes.push(scene);
			byKey.set(scene.key, scene);
			if (sceneData.active && activeScene == null) activeScene = scene.key;
		}

		// Radio buttons create the groups they name that the canvas didn't list
		for (group in groupMap) {
			if (radioGroups.indexOf(group) < 0) radioGroups.push(group);
		}

		for (groupData in data.radioGroups) {
			if (groupData.activeButton == null) continue;
			var ref: TElementRef = groupData.activeButton;
			var scene: TBuiltScene = byKey.get(ref.scene);
			var button: RadioButton = scene != null ? Std.downcast(findByPath(scene.root, scene.keys, ref.path), RadioButton) : null;
			if (button == null) throw 'radio group "${groupData.id}": active button "${ref.scene}: ${ref.path}" not found';
			groupMap.get(groupData.id).setActiveButton(button);
		}

		return { scenes: scenes, radioGroups: radioGroups, activeScene: activeScene };
	}

	/**
	 * Builds `elements` under the container `parent`: those whose parent is ""
	 * go directly in it, the others below them by path. Radio buttons join the
	 * groups in `radioGroups` by id, which are created if needed. `where` names
	 * the place in error messages.
	 */
	public static function buildTree(elements: Array<TElementData>, parent: Element, radioGroups: Map<String, RadioGroup>, where: String): TBuiltTree {
		var keys: Map<Element, String> = new Map();
		var byPath: Map<String, Element> = ["" => parent];

		for (data in elements) {
			var path: String = joinPath(data.parent, data.key);
			var here: String = '$where, element "$path"';

			if (data.key == "" || data.key.indexOf("/") >= 0) throw '$here: a name can\'t be empty or contain "/"';
			var container: Element = byPath.get(data.parent);
			if (container == null) throw '$here: parent not found (parents must come before their children)';
			if (byPath.exists(path)) throw '$here: two siblings have the same name';
			if (!HierarchyUtils.canAcceptChild(container)) throw '$here: the parent "${data.parent}" can\'t contain elements';

			var element: Element = CanvasElements.create(data, radioGroups);
			if (element == null) throw '$here: unknown type "${data.type}"';

			if (Std.isOfType(container, AnchorPane)) (cast container: AnchorPane).add(element, cast data.anchor);
			else HierarchyUtils.moveAsChild(element, container);
			keys.set(element, data.key);
			byPath.set(path, element);
		}

		// Focus links point at elements of the same tree, so they're set once all exist
		for (data in elements) {
			var element: Element = byPath.get(joinPath(data.parent, data.key));
			element.focusUp = resolveFocus(byPath, data.focusUp, where);
			element.focusDown = resolveFocus(byPath, data.focusDown, where);
			element.focusLeft = resolveFocus(byPath, data.focusLeft, where);
			element.focusRight = resolveFocus(byPath, data.focusRight, where);
		}

		return { keys: keys, byPath: byPath };
	}

	static function resolveFocus(byPath: Map<String, Element>, path: Null<String>, where: String): Null<Element> {
		if (path == null) return null;
		var target: Element = byPath.get(path);
		if (target == null || path == "") throw '$where: focus target "$path" not found';
		return target;
	}

	/** The element at `path` below `root`, or null. */
	public static function findByPath(root: Element, keys: Map<Element, String>, path: String): Null<Element> {
		if (path == "") return null;
		var current: Element = root;
		for (name in path.split("/")) {
			var next: Element = null;
			for (child in HierarchyUtils.getChildren(current)) {
				if (keys.get(child) == name) {
					next = child;
					break;
				}
			}
			if (next == null) return null;
			current = next;
		}
		return current;
	}

	/** The path of `element` below `root`: the names from the root down, joined by "/". */
	public static function getPath(element: Element, root: Element, keys: Map<Element, String>): String {
		var names: Array<String> = [];
		var current: Element = element;
		while (current != null && current != root) {
			names.unshift(keys.get(current));
			current = HierarchyUtils.getParentElement(current);
		}
		return names.join("/");
	}

	public static inline function joinPath(parentPath: String, key: String): String {
		return parentPath == "" ? key : parentPath + "/" + key;
	}
}
