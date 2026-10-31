package arm.editors;

import arm.canvas.CanvasElements;
import arm.panels.PropertyFields;
import koui.elements.Checkbox;
import koui.elements.Element;
import zui.Zui;
import zui.Zui.Handle;

class CheckboxEditor extends ElementEditor {
	var textHandle: Handle = new Handle();
	var isCheckedHandle: Handle = new Handle();

	public function new() {
		super("Checkbox", "Checkbox", "Buttons", groups -> new Checkbox("New Checkbox"));
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Checkbox Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Checkbox).text, (e, text) -> (cast e: Checkbox).text = text);
		PropertyFields.check(ui, isCheckedHandle, "Is Checked", elements, e -> (cast e: Checkbox).isChecked, (e, checked) -> CanvasElements.setChecked(cast e, checked));
	}
}
