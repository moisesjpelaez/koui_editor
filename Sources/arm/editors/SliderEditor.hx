package arm.editors;

import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
import arm.panels.PropertyFields.TRangeHandles;
import koui.elements.Element;
import koui.elements.Slider;
import koui.elements.Slider.SliderOrientation;
import koui.Koui;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Handle;

@:access(koui.Koui)
class SliderEditor implements IElementEditor {
	var rangeHandles: TRangeHandles;
	var orientationHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;

	function get_typeName(): String return "Slider";
	function get_displayName(): String return "Slider";
	function get_category(): String return "Misc.";

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		return new Slider(0, 100);
	}

	public function initHandles(): Void {
		orientationHandle = new Handle();
		rangeHandles = { min: new Handle(), max: new Handle(), precision: new Handle(), value: new Handle() };
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Slider Properties", Center);
		ui.separator();

		var orientations: Array<SliderOrientation> = [Up, Down, Left, Right];
		PropertyFields.combo(ui, orientationHandle, "Orientation", ["Up", "Down", "Left", "Right"], elements, e -> orientations.indexOf(slider(e).orientation), (e, index) -> {
			slider(e).orientation = orientations[index];
			Koui.updateElementSize(e);
		});
		PropertyFields.range(ui, rangeHandles, elements, e -> slider(e).precision, (e, precision) -> slider(e).precision = precision);

	}

	static inline function slider(element: Element): Slider {
		return cast element;
	}
}
