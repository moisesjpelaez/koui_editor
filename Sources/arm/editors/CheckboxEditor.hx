package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.Panel;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(koui.elements.Element)
class CheckboxEditor implements IElementEditor {
	var textHandle: Handle;
	var isCheckedHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Checkbox";
	function get_displayName(): String return "Checkbox";
	function get_category(): String return "Buttons";
	function get_isComposite(): Bool return true;

	public function matches(element: Element): Bool return Std.isOfType(element, Checkbox);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Checkbox("New Checkbox");
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var text: String = properties != null && properties.text != null ? properties.text : "";
		var checkbox = new Checkbox(text);
		if (properties != null) {
			if (properties.isChecked != null) {
				checkbox.isChecked = properties.isChecked;
				var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
				if (checkSquare != null)
					checkSquare.setContextElement(checkbox.isChecked ? "checked" : "");
			}
		}
		return checkbox;
	}

	public function serializeProperties(element: Element): Dynamic {
		var checkbox: Checkbox = cast element;
		return {
			text: checkbox.text,
			isChecked: checkbox.isChecked
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		isCheckedHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Checkbox Properties", Center);
		ui.separator();

		var checkbox: Checkbox = cast element;

		textHandle.text = checkbox.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			if (newText != null && newText != "") {
				ElementEvents.propertyChanged.emit(checkbox, "text", checkbox.text, newText);
				checkbox.text = newText;
			}
		}

		isCheckedHandle.selected = checkbox.isChecked;
		var newChecked = ui.check(isCheckedHandle, "Is Checked");
		if (newChecked != checkbox.isChecked) {
			ElementEvents.propertyChanged.emit(checkbox, "isChecked", checkbox.isChecked, newChecked);
			checkbox.isChecked = newChecked;
			var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
			if (checkSquare != null)
				checkSquare.setContextElement(newChecked ? "checked" : "");
		}
	}
}
