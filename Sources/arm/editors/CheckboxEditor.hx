package arm.editors;

import arm.editors.IElementEditor;
import arm.canvas.CanvasElements;
import arm.panels.PropertyFields;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Handle;

@:access(koui.elements.Element)
class CheckboxEditor implements IElementEditor {
	var textHandle: Handle;
	var isCheckedHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "Checkbox";
	function get_displayName(): String return "Checkbox";
	function get_category(): String return "Buttons";

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Checkbox("New Checkbox");
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		isCheckedHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Checkbox Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Checkbox).text, (e, text) -> (cast e: Checkbox).text = text);
		PropertyFields.check(ui, isCheckedHandle, "Is Checked", elements, e -> (cast e: Checkbox).isChecked, (e, checked) -> CanvasElements.setChecked(cast e, checked));
	}
}
