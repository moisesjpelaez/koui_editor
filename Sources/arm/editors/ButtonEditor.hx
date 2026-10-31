package arm.editors;

import arm.panels.PropertyFields;
import koui.elements.Button;
import koui.elements.Element;
import zui.Zui;
import zui.Zui.Handle;

class ButtonEditor extends ElementEditor {
	var textHandle: Handle = new Handle();
	var isToggleHandle: Handle = new Handle();
	var isPressedHandle: Handle = new Handle();

	public function new() {
		super("Button", "Button", "Buttons", groups -> new Button("New Button"));
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Button Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Button).text, (e, text) -> (cast e: Button).text = text);
		// Only toggle buttons show as pressed
		PropertyFields.check(ui, isPressedHandle, "Is Pressed", elements, e -> (cast e: Button).isToggle && (cast e: Button).isPressed, (e, pressed) -> (cast e: Button).isPressed = pressed);
		PropertyFields.check(ui, isToggleHandle, "Is Toggle", elements, e -> (cast e: Button).isToggle, (e, toggle) -> (cast e: Button).isToggle = toggle);
	}
}
