package arm.editors;

import arm.editors.IElementEditor;
import koui.elements.Element;
import koui.elements.layouts.RowLayout;
import koui.utils.RadioGroup;
import zui.Zui;

class RowLayoutEditor implements IElementEditor {
	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "RowLayout";
	function get_displayName(): String return "RowLayout";
	function get_category(): String return "Layout";

	public function matches(element: Element): Bool return Std.isOfType(element, RowLayout);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new RowLayout(0, 0, 200, 100, 0);
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		return new RowLayout(posX, posY, width, height, 0);
	}

	public function serializeProperties(element: Element): Dynamic return {};

	public function initHandles(): Void {}
	public function syncHandles(element: Element): Void {}
	public function drawProperties(ui: Zui, element: Element): Void {}
}
