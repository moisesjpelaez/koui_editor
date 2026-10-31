package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
import koui.elements.Element;
import koui.elements.Slider;
import koui.elements.Slider.SliderOrientation;
import koui.Koui;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(koui.Koui)
class SliderEditor implements IElementEditor {
	var orientationHandle: Handle;
	var minValueHandle: Handle;
	var maxValueHandle: Handle;
	var precisionHandle: Handle;
	var valueHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "Slider";
	function get_displayName(): String return "Slider";
	function get_category(): String return "Misc.";
	function get_isComposite(): Bool return true;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Slider(0, 100);
	}

	public function initHandles(): Void {
		orientationHandle = new Handle();
		minValueHandle = new Handle();
		maxValueHandle = new Handle();
		precisionHandle = new Handle();
		valueHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Slider Properties", Center);
		ui.separator();

		var orientations: Array<SliderOrientation> = [Up, Down, Left, Right];
		PropertyFields.combo(ui, orientationHandle, "Orientation", ["Up", "Down", "Left", "Right"], elements, e -> orientations.indexOf(slider(e).orientation), (e, index) -> {
			slider(e).orientation = orientations[index];
			Koui.updateElementSize(e);
		});
		PropertyFields.float(ui, minValueHandle, "Min Value", elements, e -> slider(e).minValue, (e, min) -> {
			slider(e).minValue = min;
			slider(e).value = Math.max(min, slider(e).value);
		});
		PropertyFields.float(ui, maxValueHandle, "Max Value", elements, e -> slider(e).maxValue, (e, max) -> {
			slider(e).maxValue = max;
			slider(e).value = Math.min(max, slider(e).value);
		});
		PropertyFields.int(ui, precisionHandle, "Precision", elements, e -> slider(e).precision, (e, precision) -> {
			slider(e).precision = Std.int(Math.max(0, precision));
			var steps: Float = Math.pow(10, -slider(e).precision);
			slider(e).value = Math.round(slider(e).value / steps) * steps;
		});

		// The range and precision of the first selected slider
		var first: Slider = slider(elements[0]);
		PropertyFields.slider(ui, valueHandle, "Value", first.minValue, first.maxValue, first.precision, elements, e -> slider(e).value, (e, value) -> slider(e).value = value);
	}

	static inline function slider(element: Element): Slider {
		return cast element;
	}
}
