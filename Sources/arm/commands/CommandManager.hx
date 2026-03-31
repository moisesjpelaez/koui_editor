package arm.commands;

import arm.data.SceneData;
import arm.events.SceneEvents;

class CommandManager {
	public static var instance(default, null): CommandManager;

	var undoStack: Array<ICommand>;
	var redoStack: Array<ICommand>;
	var maxHistory: Int;
	public var isUndoRedoing(default, null): Bool = false;

	public function new(maxHistory: Int = 100) {
		this.maxHistory = maxHistory;
		undoStack = [];
		redoStack = [];
		instance = this;
	}

	/** Execute a command and record it for undo. */
	public function execute(cmd: ICommand): Void {
		cmd.execute();
		record(cmd);
	}

	/** Record a command that was already executed (e.g. from UI interactions). */
	public function record(cmd: ICommand): Void {
		undoStack.push(cmd);
		if (undoStack.length > maxHistory) undoStack.shift();
		redoStack.resize(0);
	}

	public function undo(): Bool {
		if (undoStack.length == 0) return false;
		isUndoRedoing = true;
		var cmd = undoStack.pop();
		switchToScene(cmd.sceneName);
		cmd.undo();
		redoStack.push(cmd);
		isUndoRedoing = false;
		return true;
	}

	public function redo(): Bool {
		if (redoStack.length == 0) return false;
		isUndoRedoing = true;
		var cmd = redoStack.pop();
		switchToScene(cmd.sceneName);
		cmd.execute();
		undoStack.push(cmd);
		isUndoRedoing = false;
		return true;
	}

	function switchToScene(sceneName: String): Void {
		if (sceneName == null || sceneName == "") return;
		var current = SceneData.data.currentScene;
		if (current != null && current.key == sceneName) return;
		SceneEvents.sceneChanged.emit(sceneName);
	}

	public function canUndo(): Bool return undoStack.length > 0;
	public function canRedo(): Bool return redoStack.length > 0;
	public function clear(): Void { undoStack.resize(0); redoStack.resize(0); }
}
