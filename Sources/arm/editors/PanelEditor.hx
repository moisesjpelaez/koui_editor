package arm.editors;

import arm.editors.IElementEditor;
import koui.elements.Element;
import koui.elements.Panel;
import koui.utils.RadioGroup;
import zui.Zui;

class PanelEditor implements IElementEditor {
	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "Panel";
	function get_displayName(): String return "Panel";
	function get_category(): String return "Basic";

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Panel();
	}

	public function initHandles(): Void {}
	public function drawProperties(ui: Zui, elements: Array<Element>): Void {}
}
