package arm.commands;

import arm.data.SceneData;
import koui.elements.Element;

class KeyRenameCommand implements ICommand {
	var element: Element;
	var oldKey: String;
	var newKey: String;
	var _sceneName: String;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Rename key "$oldKey" to "$newKey"';
	function get_sceneName(): String return _sceneName;

	public function new(element: Element, oldKey: String, newKey: String) {
		this.element = element;
		this.oldKey = oldKey;
		this.newKey = newKey;
		this._sceneName = SceneData.data.currentScene != null ? SceneData.data.currentScene.key : "";
	}

	public function execute(): Void {
		SceneData.data.updateElementKey(element, newKey);
	}

	public function undo(): Void {
		SceneData.data.updateElementKey(element, oldKey);
	}
}
