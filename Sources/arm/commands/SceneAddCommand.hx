package arm.commands;

import arm.data.SceneData;
import arm.events.SceneEvents;
import arm.types.Types;
import koui.Koui;
import koui.elements.layouts.AnchorPane;
import koui.utils.SceneManager;

@:access(koui.utils.SceneManager)
class SceneAddCommand implements ICommand {
	var _sceneName: String;
	var sceneEntry: TSceneEntry;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Add scene "$_sceneName"';
	function get_sceneName(): String return null; // Scene commands handle their own switching

	/**
	 * @param sceneName The name of the scene that was added
	 * @param sceneEntry The TSceneEntry created during initial addition (captured AFTER creation)
	 */
	public function new(sceneName: String, sceneEntry: TSceneEntry) {
		this._sceneName = sceneName;
		this.sceneEntry = sceneEntry;
	}

	/** Redo: re-add the scene. */
	public function execute(): Void {
		// Re-add the existing AnchorPane to Koui and SceneManager
		SceneManager.scenes.set(_sceneName, sceneEntry.root);
		Koui.add(sceneEntry.root);

		// Re-insert into SceneData
		var sceneData = SceneData.data;
		sceneData.scenes.push(sceneEntry);

		// Switch to it
		SceneManager.setScene(_sceneName);
		SceneEvents.sceneChanged.emit(_sceneName);
	}

	/** Undo: remove the scene. */
	public function undo(): Void {
		// Remove from SceneManager (hides + removes from Koui + removes from map)
		SceneManager.removeScene(_sceneName);

		// Remove from SceneData
		var sceneData = SceneData.data;
		for (i in 0...sceneData.scenes.length) {
			if (sceneData.scenes[i].key == _sceneName) {
				sceneData.scenes[i].active = false;
				sceneData.scenes.splice(i, 1);
				break;
			}
		}

		// Switch to another scene
		if (sceneData.scenes.length > 0) {
			var target = sceneData.scenes[sceneData.scenes.length - 1];
			SceneManager.setScene(target.key);
			SceneEvents.sceneChanged.emit(target.key);
		}
	}
}
