package arm.editors;

import arm.data.SceneData;
import arm.editors.IElementEditor;
import arm.events.ElementEvents;
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

	public function matches(element: Element): Bool return Std.isOfType(element, RadioButton);

	public function createDefault(?radioGroups: Array<RadioGroup>): Element {
		var group: RadioGroup = null;
		if (radioGroups != null && radioGroups.length > 0) {
			group = radioGroups[0];
		} else {
			group = new RadioGroup("RadioGroup");
		}
		return new RadioButton(group, "New Radio");
	}

	public function createFromData(posX: Int, posY: Int, width: Int, height: Int, properties: Dynamic, ?radioGroupMap: Map<String, RadioGroup>): Element {
		var text: String = properties != null && properties.text != null ? properties.text : "";
		var groupId: String = properties != null && properties.radioGroup != null ? properties.radioGroup : "RadioGroup";
		var group: RadioGroup = null;
		if (radioGroupMap != null) {
			group = radioGroupMap.get(groupId);
			if (group == null) {
				group = new RadioGroup(groupId);
				radioGroupMap.set(groupId, group);
			}
		} else {
			group = new RadioGroup(groupId);
		}

		var radioButton = new RadioButton(group, text);
		if (properties != null && properties.isChecked != null && properties.isChecked) {
			radioButton.group.setActiveButton(radioButton);
		}
		return radioButton;
	}

	public function serializeProperties(element: Element): Dynamic {
		var radioButton: RadioButton = cast element;
		return {
			text: radioButton.text,
			isChecked: radioButton.isChecked,
			radioGroup: radioButton.group != null ? radioButton.group.id : ""
		};
	}

	public function initHandles(): Void {
		textHandle = new Handle();
		isCheckedHandle = new Handle();
		groupHandle = new Handle();
	}

	public function syncHandles(element: Element): Void {}

	public function drawProperties(ui: Zui, element: Element): Void {
		ui.text("Radio Button Properties", Center);
		ui.separator();

		var radioButton: RadioButton = cast element;
		var sceneData = SceneData.data;

		textHandle.text = radioButton.text;
		var newText: String = ui.textInput(textHandle, "Text", Right);
		if (textHandle.changed) {
			if (newText != null && newText != "") {
				ElementEvents.propertyChanged.emit(radioButton, "text", radioButton.text, newText);
				radioButton.text = newText;
			}
		}

		isCheckedHandle.selected = radioButton.isChecked;
		var newChecked = ui.check(isCheckedHandle, "Is Checked");
		if (newChecked != radioButton.isChecked) {
			ElementEvents.propertyChanged.emit(radioButton, "isChecked", radioButton.isChecked, newChecked);
			if (newChecked) {
				radioButton.group.setActiveButton(radioButton);
			} else {
				radioButton.isChecked = false;
				var checkSquare: Panel = radioButton.getChild(new TypeMatchBehaviour(Panel));
				if (checkSquare != null)
					checkSquare.setContextElement("");
			}
		}

		// Radio group combo
		var availableGroups = sceneData.radioGroups;
		var groupNames: Array<String> = [];
		var currentIndex = 0;
		for (i in 0...availableGroups.length) {
			groupNames.push(availableGroups[i].id);
			if (radioButton.group != null && (availableGroups[i] == radioButton.group || availableGroups[i].id == radioButton.group.id)) {
				currentIndex = i;
			}
		}

		if (groupNames.length == 0) {
			groupNames.push("(none)");
			groupHandle.position = 0;
			ui.combo(groupHandle, groupNames, "Radio Group", true, Right);
		} else {
			groupHandle.position = currentIndex;
			var newGroupIndex = ui.combo(groupHandle, groupNames, "Radio Group", true, Right);
			if (groupHandle.changed && newGroupIndex >= 0 && newGroupIndex < availableGroups.length) {
				var newGroup = availableGroups[newGroupIndex];
				if (radioButton.group == null || (radioButton.group != newGroup && radioButton.group.id != newGroup.id)) {
					var oldGroupId = radioButton.group != null ? radioButton.group.id : "";
					// Move button to new group
					if (radioButton.group != null) radioButton.group.remove(radioButton);
					radioButton.group = newGroup;
					newGroup.add(radioButton);
					ElementEvents.propertyChanged.emit(radioButton, "radioGroup", oldGroupId, newGroup.id);
				}
			}
		}
	}
}
