package arm.editors;

import arm.panels.PropertyFields;
import koui.elements.Element;
import koui.elements.Label;
import zui.Zui;
import zui.Zui.Handle;

class LabelEditor extends ElementEditor {
	var textHandle: Handle = new Handle();

	public function new() {
		super("Label", "Label", "Basic", groups -> new Label("New Label"));
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Label Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: Label).text, (e, text) -> (cast e: Label).text = text);
	}
}
