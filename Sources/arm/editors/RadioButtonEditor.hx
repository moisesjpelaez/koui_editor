package arm.editors;

import arm.data.SceneData;
import arm.canvas.CanvasElements;
import arm.panels.PropertyFields;
import koui.elements.Element;
import koui.elements.RadioButton;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Handle;

class RadioButtonEditor extends ElementEditor {
	var textHandle: Handle = new Handle();
	var isCheckedHandle: Handle = new Handle();
	var groupHandle: Handle = new Handle();

	public function new() {
		super("RadioButton", "Radio Button", "Buttons", groups -> {
			var group: RadioGroup = groups.length > 0 ? groups[0] : new RadioGroup("RadioGroup");
			new RadioButton(group, "New Radio");
		});
	}

	override public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Radio Button Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: RadioButton).text, (e, text) -> (cast e: RadioButton).text = text);
		PropertyFields.check(ui, isCheckedHandle, "Is Checked", elements, e -> (cast e: RadioButton).isChecked, (e, checked) -> {
			var radioButton: RadioButton = cast e;
			if (checked) {
				radioButton.group.setActiveButton(radioButton);
			} else {
				CanvasElements.setChecked(radioButton, false);
			}
		});

		// Radio group combo
		var groups: Array<RadioGroup> = SceneData.data.radioGroups;
		var groupNames: Array<String> = [for (group in groups) group.id];
		PropertyFields.combo(ui, groupHandle, "Radio Group", groupNames, elements, e -> groups.indexOf((cast e: RadioButton).group), (e, index) -> {
			var radioButton: RadioButton = cast e;
			var newGroup: RadioGroup = groups[index];
			if (radioButton.group == newGroup) return;
			// Move button to new group
			if (radioButton.group != null) radioButton.group.remove(radioButton);
			radioButton.group = newGroup;
			newGroup.add(radioButton);
		});
	}
}
