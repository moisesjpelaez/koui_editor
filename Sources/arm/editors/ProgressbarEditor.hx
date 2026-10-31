package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
import koui.elements.Element;
import koui.elements.Progressbar;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

class ProgressbarEditor implements IElementEditor {
	var textHandle: Handle;
	var minValueHandle: Handle;
	var maxValueHandle: Handle;
	var precisionHandle: Handle;
	var valueHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Progressbar";
	function get_displayName(): String return "Progressbar";
	function get_category(): String return "Misc.";
	function get_isComposite(): Bool return true;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Progressbar(0, 100);
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		minValueHandle = new Handle();
		maxValueHandle = new Handle();
		precisionHandle = new Handle();
		valueHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Progressbar Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> bar(e).text, (e, text) -> bar(e).text = text, true);
		PropertyFields.float(ui, minValueHandle, "Min Value", elements, e -> bar(e).minValue, (e, min) -> {
			bar(e).minValue = min;
			bar(e).value = Math.max(min, bar(e).value);
		});
		PropertyFields.float(ui, maxValueHandle, "Max Value", elements, e -> bar(e).maxValue, (e, max) -> {
			bar(e).maxValue = max;
			bar(e).value = Math.min(max, bar(e).value);
		});
		PropertyFields.int(ui, precisionHandle, "Precision", elements, e -> bar(e).precision, (e, precision) -> {
			bar(e).precision = Std.int(Math.max(0, precision));
			var steps: Float = Math.pow(10, -bar(e).precision);
			bar(e).value = Math.round(bar(e).value / steps) * steps;
		});

		// The range and precision of the first selected bar
		var first: Progressbar = bar(elements[0]);
		PropertyFields.slider(ui, valueHandle, "Value", first.minValue, first.maxValue, first.precision, elements, e -> bar(e).value, (e, value) -> bar(e).value = value);
	}

	static inline function bar(element: Element): Progressbar {
		return cast element;
	}
}
