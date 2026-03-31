package arm.commands;

import arm.data.SceneData;
import arm.events.SceneEvents;
import arm.types.Types;
import koui.Koui;
import koui.elements.layouts.AnchorPane;
import koui.utils.SceneManager;

@:access(koui.utils.SceneManager)
class SceneRemoveCommand implements ICommand {
	var _sceneName: String;
	var sceneEntry: TSceneEntry;
	var sceneIndex: Int;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Remove scene "$_sceneName"';
	function get_sceneName(): String return null; // Scene commands handle their own switching

	/**
	 * @param sceneName The name of the scene to remove
	 * @param sceneEntry The full TSceneEntry backup (must be captured BEFORE removal)
	 * @param sceneIndex The index in SceneData.scenes (must be captured BEFORE removal)
	 */
	public function new(sceneName: String, sceneEntry: TSceneEntry, sceneIndex: Int) {
		this._sceneName = sceneName;
		this.sceneEntry = sceneEntry;
		this.sceneIndex = sceneIndex;
	}

	/** Redo: remove the scene again. */
	public function execute(): Void {
		// Remove from SceneManager
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
			var idx = sceneIndex > 0 ? sceneIndex - 1 : 0;
			if (idx >= sceneData.scenes.length) idx = sceneData.scenes.length - 1;
			SceneManager.setScene(sceneData.scenes[idx].key);
			SceneEvents.sceneChanged.emit(sceneData.scenes[idx].key);
		}
	}

	/** Undo: restore the removed scene. */
	public function undo(): Void {
		// Re-add the AnchorPane to Koui and SceneManager's internal map
		SceneManager.scenes.set(_sceneName, sceneEntry.root);
		Koui.add(sceneEntry.root);

		// Re-insert into SceneData at original position
		var sceneData = SceneData.data;
		var idx = sceneIndex;
		if (idx > sceneData.scenes.length) idx = sceneData.scenes.length;
		sceneData.scenes.insert(idx, sceneEntry);

		// Switch to the restored scene
		SceneManager.setScene(_sceneName);
		SceneEvents.sceneChanged.emit(_sceneName);
	}
}
