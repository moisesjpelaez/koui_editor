package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
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

	public function initHandles(): Void {
		textHandle = new Handle();
		isToggleHandle = new Handle();
		isPressedHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Button Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Button).text, (e, text) -> (cast e: Button).text = text);
		// Only toggle buttons show as pressed
		PropertyFields.check(ui, isPressedHandle, "Is Pressed", elements, e -> (cast e: Button).isToggle && (cast e: Button).isPressed, (e, pressed) -> (cast e: Button).isPressed = pressed);
		PropertyFields.check(ui, isToggleHandle, "Is Toggle", elements, e -> (cast e: Button).isToggle, (e, toggle) -> (cast e: Button).isToggle = toggle);
	}
}
