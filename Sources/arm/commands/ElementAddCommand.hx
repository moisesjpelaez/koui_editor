package arm.commands;

import arm.data.SceneData;
import arm.events.ElementEvents;
import arm.tools.HierarchyUtils;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout.Anchor;

class ElementAddCommand implements ICommand {
	var element: Element;
	var key: String;
	var _sceneName: String;
	var parentElement: Element;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Add element "$key"';
	function get_sceneName(): String return _sceneName;

	/**
	 * @param element The element that was added
	 * @param key The assigned key/name
	 * @param parentElement The parent element it was added to (rootPane)
	 */
	public function new(element: Element, key: String, parentElement: Element) {
		this.element = element;
		this.key = key;
		this.parentElement = parentElement;
		this._sceneName = SceneData.data.currentScene != null ? SceneData.data.currentScene.key : "";
	}

	public function execute(): Void {
		// Re-add to parent
		if (Std.isOfType(parentElement, AnchorPane)) {
			cast(parentElement, AnchorPane).add(element, Anchor.TopLeft);
		}

		// Re-add to SceneData
		var sceneData = SceneData.data;
		for (scene in sceneData.scenes) {
			if (scene.key == _sceneName) {
				scene.elements.push({key: key, element: element});
				break;
			}
		}
	}

	public function undo(): Void {
		// Remove from parent
		HierarchyUtils.detachFromCurrentParent(element);

		// Remove from SceneData
		var sceneData = SceneData.data;
		for (scene in sceneData.scenes) {
			if (scene.key == _sceneName) {
				for (i in 0...scene.elements.length) {
					if (scene.elements[i].element == element) {
						scene.elements.splice(i, 1);
						break;
					}
				}
				break;
			}
		}

		ElementEvents.elementSelected.emit(null);
	}
}
