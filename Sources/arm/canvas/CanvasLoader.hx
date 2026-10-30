package arm.canvas;

import arm.tools.HierarchyUtils;
import arm.types.Types;

import koui.elements.Element;
import koui.elements.RadioButton;
import koui.elements.layouts.AnchorPane;
import koui.utils.RadioGroup;

/** A built scene: its root pane and the name of each element in it. */
typedef TBuiltScene = {
	var root: AnchorPane;
	var keys: Map<Element, String>;
}

/**
 * Builds canvases saved by the Koui Editor. Shared by the editor and the game
 * runtime, so both build exactly the same element tree. Invalid data is
 * reported with an exception naming the problem, nothing is guessed.
 */
class CanvasLoader {
	/** Written to saved canvases; loading doesn't check it. */
	public static inline var VERSION: String = "2.0";

	/** Creates the canvas' radio groups, in saved order. */
	public static function createRadioGroups(data: TCanvasData): Array<RadioGroup> {
		return [for (groupData in data.radioGroups) new RadioGroup(groupData.id)];
	}

	/**
	 * Builds the elements of `sceneData` into `root`. Radio buttons join the
	 * groups in `radioGroups` by id. Returns the name of each created element.
	 */
	public static function buildScene(sceneData: TSceneData, root: AnchorPane, radioGroups: Map<String, RadioGroup>): Map<Element, String> {
		var keys: Map<Element, String> = new Map();
		var byPath: Map<String, Element> = ["" => root];

		for (data in sceneData.elements) {
			var where: String = 'scene "${sceneData.key}", element "${joinPath(data.parent, data.key)}"';

			var parent: Element = byPath.get(data.parent);
			if (parent == null) throw '$where: parent not found (parents must come before their children)';
			var path: String = joinPath(data.parent, data.key);
			if (byPath.exists(path)) throw '$where: two siblings have the same name';

			var element: Element = CanvasElements.create(data, radioGroups);
			if (element == null) throw '$where: unknown type "${data.type}"';

			if (parent == root) {
				root.add(element, cast data.anchor);
			} else {
				if (!HierarchyUtils.canAcceptChild(parent)) throw '$where: the parent "${data.parent}" can\'t contain elements';
				HierarchyUtils.moveAsChild(element, parent);
			}
			keys.set(element, data.key);
			byPath.set(path, element);
		}

		for (data in sceneData.elements) {
			var element: Element = byPath.get(joinPath(data.parent, data.key));
			element.focusUp = resolveFocus(byPath, data.focusUp, sceneData.key);
			element.focusDown = resolveFocus(byPath, data.focusDown, sceneData.key);
			element.focusLeft = resolveFocus(byPath, data.focusLeft, sceneData.key);
			element.focusRight = resolveFocus(byPath, data.focusRight, sceneData.key);
		}

		return keys;
	}

	static function resolveFocus(byPath: Map<String, Element>, path: Null<String>, sceneKey: String): Null<Element> {
		if (path == null) return null;
		var target: Element = byPath.get(path);
		if (target == null || path == "") throw 'scene "$sceneKey": focus target "$path" not found';
		return target;
	}

	/** Makes each group's saved active button the checked one. Call after all scenes are built. */
	public static function applyActiveButtons(data: TCanvasData, radioGroups: Map<String, RadioGroup>, scenes: Map<String, TBuiltScene>): Void {
		for (groupData in data.radioGroups) {
			if (groupData.activeButton == null) continue;
			var ref: TElementRef = groupData.activeButton;
			var scene: TBuiltScene = scenes.get(ref.scene);
			var button: RadioButton = scene != null ? Std.downcast(findByPath(scene.root, scene.keys, ref.path), RadioButton) : null;
			if (button == null) throw 'radio group "${groupData.id}": active button "${ref.scene}: ${ref.path}" not found';
			radioGroups.get(groupData.id).setActiveButton(button);
		}
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
