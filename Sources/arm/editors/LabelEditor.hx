package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
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

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Label("New Label");
	}

	public function initHandles(): Void {
		textHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Label Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Label).text, (e, text) -> (cast e: Label).text = text);
	}
}
