package arm.editors;

import arm.editors.IElementEditor;
import arm.events.ElementEvents;
import koui.elements.Button;
import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class ButtonEditor implements IElementEditor {
	var textHandle: Handle;
	var isToggleHandle: Handle;
	var isPressedHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Button";
	function get_displayName(): String return "Button";
	function get_category(): String return "Buttons";
	function get_isComposite(): Bool return true;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Button("New Button");
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var text: String = properties != null && properties.text != null ? properties.text : "";
		var button = new Button(text);
		if (properties != null) {
			if (properties.isToggle != null) button.isToggle = properties.isToggle;
			if (properties.isPressed != null) button.isPressed = properties.isPressed;
		}
		return button;
	}

	public function serializeProperties(element: Element): Dynamic {
		var button: Button = cast element;
		return {
			text: button.text,
			isToggle: button.isToggle,
			isPressed: button.isPressed
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		isToggleHandle = new Handle();
		isPressedHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Button Properties", Center);
		ui.separator();

		var button: Button = cast element;

		textHandle.text = button.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			if (newText != null && newText != "") {
				ElementEvents.propertyChanged.emit(button, "text", button.text, newText);
				button.text = newText;
			}
		}

		isPressedHandle.selected = button.isToggle && button.isPressed;
		var newPressed = ui.check(isPressedHandle, "Is Pressed");
		if (newPressed != button.isPressed) {
			ElementEvents.propertyChanged.emit(button, "isPressed", button.isPressed, newPressed);
			button.isPressed = newPressed;
		}

		isToggleHandle.selected = button.isToggle;
		var newToggle = ui.check(isToggleHandle, "Is Toggle");
		if (newToggle != button.isToggle) {
			ElementEvents.propertyChanged.emit(button, "isToggle", button.isToggle, newToggle);
			button.isToggle = newToggle;
		}
	}
}
