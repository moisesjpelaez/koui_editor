package arm.editors;

import arm.editors.IElementEditor;
import koui.elements.Element;
import koui.elements.layouts.ColLayout;
import koui.utils.RadioGroup;
import zui.Zui;

class ColLayoutEditor implements IElementEditor {
	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "ColLayout";
	function get_displayName(): String return "ColLayout";
	function get_category(): String return "Layout";
	function get_isComposite(): Bool return false;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new ColLayout(0, 0, 200, 100, 0);
	}

	public function initHandles(): Void {}
	public function drawProperties(ui: Zui, elements: Array<Element>): Void {}
}
