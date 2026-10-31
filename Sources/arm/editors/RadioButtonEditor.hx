package arm.editors;

import arm.data.SceneData;
import arm.editors.IElementEditor;
import arm.panels.PropertyFields;
import koui.elements.Element;
import koui.elements.Panel;
import koui.elements.RadioButton;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;
import koui.utils.RadioGroup;
import zui.Zui;
import zui.Zui.Align;
import zui.Zui.Handle;

@:access(koui.elements.Element)
class RadioButtonEditor implements IElementEditor {
	var textHandle: Handle;
	var isCheckedHandle: Handle;
	var groupHandle: Handle;

	public function new() { initHandles(); }

	public var typeName(get, never): String;
	public var displayName(get, never): String;
	public var category(get, never): String;
	public var isComposite(get, never): Bool;

	function get_typeName(): String return "RadioButton";
	function get_displayName(): String return "Radio Button";
	function get_category(): String return "Buttons";
	function get_isComposite(): Bool return true;

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		var group: RadioGroup = null;
		if (radioGroups != null && radioGroups.length > 0) {
			group = radioGroups[0];
		} else {
			group = new RadioGroup("RadioGroup");
		}
		return new RadioButton(group, "New Radio");
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		isCheckedHandle = new Handle();
		groupHandle = new Handle();
	}

	public function drawProperties(ui: Zui, elements: Array<Element>): Void {
		ui.text("Radio Button Properties", Center);
		ui.separator();

		PropertyFields.text(ui, textHandle, "Text", elements, e -> (cast e: RadioButton).text, (e, text) -> (cast e: RadioButton).text = text);
		PropertyFields.check(ui, isCheckedHandle, "Is Checked", elements, e -> (cast e: RadioButton).isChecked, (e, checked) -> {
			var radioButton: RadioButton = cast e;
			if (checked) {
				radioButton.group.setActiveButton(radioButton);
			} else {
				radioButton.isChecked = false;
				var checkSquare: Panel = radioButton.getChild(new TypeMatchBehaviour(Panel));
				if (checkSquare != null) checkSquare.setContextElement("");
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
