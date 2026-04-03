package arm.commands;

import arm.data.SceneData;
import arm.events.ElementEvents;
import arm.tools.HierarchyUtils;
import arm.types.Types;
import koui.elements.Element;

class ElementRemoveCommand implements ICommand {
	var element: Element;
	var key: String;
	var _sceneName: String;
	var parentElement: Element;
	var childIndex: Int;
	var childEntries: Array<TElementEntry>;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Remove element "$key"';
	function get_sceneName(): String return _sceneName;

	/**
	 * @param element The element being removed
	 * @param key The element's key/name
	 * @param parentElement The parent it belongs to
	 * @param childIndex Index in parent's children list
	 * @param childEntries All TElementEntry records for this element and its descendants (captured before removal)
	 */
	public function new(element: Element, key: String, parentElement: Element, childIndex: Int, childEntries: Array<TElementEntry>) {
		this.element = element;
		this.key = key;
		this.parentElement = parentElement;
		this.childIndex = childIndex;
		this.childEntries = childEntries;
		this._sceneName = SceneData.data.currentScene != null ? SceneData.data.currentScene.key : "";
	}

	public function execute(): Void {
		// Remove element and its children from parent
		HierarchyUtils.detachFromCurrentParent(element);

		// Remove all entries from SceneData
		var sceneData = SceneData.data;
		for (scene in sceneData.scenes) {
			if (scene.key == _sceneName) {
				for (entry in childEntries) {
					for (i in 0...scene.elements.length) {
						if (scene.elements[i].element == entry.element) {
							scene.elements.splice(i, 1);
							break;
						}
					}
				}
				break;
			}
		}

		ElementEvents.elementSelected.emit(null);
	}

	public function undo(): Void {
		// Re-add to parent regardless of layout/container type.
		HierarchyUtils.moveAsChild(element, parentElement);

		// Re-add all entries to SceneData
		var sceneData = SceneData.data;
		for (scene in sceneData.scenes) {
			if (scene.key == _sceneName) {
				for (entry in childEntries) {
					scene.elements.push({key: entry.key, element: entry.element});
				}
				break;
			}
		}
	}
}
