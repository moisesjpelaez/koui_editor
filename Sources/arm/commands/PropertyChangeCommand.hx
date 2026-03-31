package arm.commands;

import arm.data.SceneData;
import koui.Koui;
import koui.elements.Element;

@:access(koui.Koui, koui.elements.Element)
class PropertyChangeCommand implements ICommand {
	var element: Element;
	var properties: Array<String>;
	var oldValues: Array<Dynamic>;
	var newValues: Array<Dynamic>;
	var _sceneName: String;

	public var description(get, never): String;
	public var sceneName(get, never): String;

	function get_description(): String return 'Change ${properties.join(", ")}';
	function get_sceneName(): String return _sceneName;

	public function new(element: Element, properties: Array<String>, oldValues: Array<Dynamic>, newValues: Array<Dynamic>) {
		this.element = element;
		this.properties = properties;
		this.oldValues = oldValues;
		this.newValues = newValues;
		this._sceneName = SceneData.data.currentScene != null ? SceneData.data.currentScene.key : "";
	}

	public function execute(): Void {
		applyValues(newValues);
	}

	public function undo(): Void {
		applyValues(oldValues);
	}

	function applyValues(values: Array<Dynamic>): Void {
		for (i in 0...properties.length) {
			var prop = properties[i];
			var val = values[i];

			if (prop == "TID") {
				element.setTID(cast val);
			} else {
				Reflect.setProperty(element, prop, val);
			}
		}

		var needsUpdateSize = false;
		for (prop in properties) {
			switch (prop) {
				case "width" | "height" | "TID":
					needsUpdateSize = true;
				default:
			}
		}
		if (needsUpdateSize) {
			Koui.updateElementSize(element);
		}
		element.invalidateElem();
	}
}
