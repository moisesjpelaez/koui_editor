package arm.commands;

interface ICommand {
	var description(get, never): String;
	var sceneName(get, never): String;
	function execute(): Void;
	function undo(): Void;
}
