package arm.commands;

import arm.data.SceneData;
import koui.utils.SceneManager;

class SceneRenameCommand implements ICommand {
	var oldKey: String;
	var newKey: String;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Rename scene "$oldKey" to "$newKey"';
	function get_sceneName(): String return null; // Scene commands handle their own switching

	public function new(oldKey: String, newKey: String) {
		this.oldKey = oldKey;
		this.newKey = newKey;
	}

	public function execute(): Void {
		applyRename(oldKey, newKey);
	}

	public function undo(): Void {
		applyRename(newKey, oldKey);
	}

	function applyRename(fromKey: String, toKey: String): Void {
		SceneManager.renameScene(fromKey, toKey);

		var sceneData = SceneData.data;
		for (scene in sceneData.scenes) {
			if (scene.key == fromKey) {
				scene.key = toKey;
				break;
			}
		}

		if (sceneData.currentScene != null && sceneData.currentScene.key == fromKey) {
			sceneData.currentScene.key = toKey;
		}
	}
}
