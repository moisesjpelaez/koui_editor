package arm.editors;

import arm.panels.PropertyFields;
import arm.panels.PropertyFields.TRangeHandles;
import koui.elements.Element;
import koui.elements.Slider;
import koui.elements.Slider.SliderOrientation;
import koui.Koui;
import zui.Zui;
import zui.Zui.Handle;

@:access(koui.Koui)
class SliderEditor extends ElementEditor {
	var orientationHandle: Handle = new Handle();
	var rangeHandles: TRangeHandles = { min: new Handle(), max: new Handle(), precision: new Handle(), value: new Handle() };

	public function new() {
		super("Slider", "Slider", "Misc.", groups -> new Slider(0, 100));
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
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
