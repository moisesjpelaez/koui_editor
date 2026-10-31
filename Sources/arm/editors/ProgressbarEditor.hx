package arm.editors;

import arm.panels.PropertyFields;
import arm.panels.PropertyFields.TRangeHandles;
import koui.elements.Element;
import koui.elements.Progressbar;
import zui.Zui;
import zui.Zui.Handle;

class ProgressbarEditor extends ElementEditor {
	var textHandle: Handle = new Handle();
	var rangeHandles: TRangeHandles = { min: new Handle(), max: new Handle(), precision: new Handle(), value: new Handle() };

	public function new() {
		super("Progressbar", "Progressbar", "Misc.", groups -> new Progressbar(0, 100));
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Progressbar Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> bar(e).text, (e, text) -> bar(e).text = text, true);
		PropertyFields.range(ui, rangeHandles, elements, e -> bar(e).precision, (e, precision) -> bar(e).precision = precision);
	}

	static inline function bar(element: Element): Progressbar {
		return cast element;
	}
}
