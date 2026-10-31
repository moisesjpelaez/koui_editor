package arm.editors;

import arm.editors.IElementEditor;
import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.utils.RadioGroup;
import zui.Zui;

class AnchorPaneEditor implements IElementEditor {
	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "AnchorPane";
	function get_displayName(): String return "AnchorPane";
	function get_category(): String return "Layout";

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		var pane = new AnchorPane(0, 0, 200, 200);
		pane.setTID("_fixed_anchorpane");
		return pane;
	}

	public function initHandles(): Void {}
	public function drawProperties(ui: Zui, elements: Array<Element>): Void {}
}
