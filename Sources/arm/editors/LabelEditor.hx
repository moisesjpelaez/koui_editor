package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Element;
import koui.elements.Label;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class LabelEditor implements IElementEditor {
	var textHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Label";
	function get_displayName(): String return "Label";
	function get_category(): String return "Basic";
	function get_isComposite(): Bool return false;

	public function matches(element: Element): Bool return Std.isOfType(element, Label);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Label("New Label");
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var text: String = properties != null && properties.text != null ? properties.text : "";
		var label = new Label(text);
		return label;
	}

	public function serializeProperties(element: Element): Dynamic {
		var label: Label = cast element;
		return {
			text: label.text
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Label Properties", Center);
		ui.separator();

		var label: Label = cast element;
		textHandle.text = label.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			if (newText != null && newText != "") {
				ElementEvents.propertyChanged.emit(label, "text", label.text, newText);
				label.text = newText;
			}
		}
	}
}
