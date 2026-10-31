package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
import arm.panels.PropertyFields.TRangeHandles;
import koui.elements.Element;
import koui.elements.Progressbar;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Handle;

class ProgressbarEditor implements IElementEditor {
	var rangeHandles: TRangeHandles;
	var textHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "Progressbar";
	function get_displayName(): String return "Progressbar";
	function get_category(): String return "Misc.";

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Progressbar(0, 100);
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		rangeHandles = { min: new Handle(), max: new Handle(), precision: new Handle(), value: new Handle() };
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Progressbar Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> bar(e).text, (e, text) -> bar(e).text = text, true);
		PropertyFields.range(ui, rangeHandles, elements, e -> bar(e).precision, (e, precision) -> bar(e).precision = precision);

	}

	static inline function bar(element: Element): Progressbar {
		return cast element;
	}
}
