package arm.panels;

import arm.base.UIBase;
import arm.data.History;
import arm.data.RadioGroups;
import arm.data.SceneData;
import arm.tools.ZuiUtils;
import arm.types.Enums;

import kha.Image;
import koui.elements.RadioButton;
import koui.utils.RadioGroup;

import zui.Zui;
import zui.Zui.Handle;

/** The Properties panel's Radio Groups tab: create, rename and delete groups, add buttons, pick the active one. */
@:access(koui.utils.RadioGroup, zui.Zui)
class RadioGroupsTab {
	var nameHandle: Handle = new Handle({text: "RadioGroup"});
	/** Each group's fields, by group id: handles drawn in a loop need one each. */
	var renameHandles: Map<String, Handle> = new Map();
	var addHandles: Map<String, Handle> = new Map();

	public function new() {}

	public function draw(uiBase: UIBase, icons: Image): Void {
		var ui: Zui = uiBase.ui;

		ui.text("Radio Group Management", Center);
		ui.separator();

		ui.row([3/4, 1/4]);
		var requestedId: String = ui.textInput(nameHandle, "Group ID", Right);
		if (ZuiUtils.iconButton(ui, icons, 1, 2, "Create Radio Group", false, false, 0.7)) {
			nameHandle.text = RadioGroups.create(requestedId).id;
			History.edited("Add radio group");
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		ui._y += 4;
		ui.separator();

		// Radio buttons of the current scene, for the "Add" combos
		var sceneButtons: Array<RadioButton> = [for (element in SceneData.data.getElements()) if (Std.isOfType(element, RadioButton)) cast element];
		var addOptions: Array<String> = ["(add radio button)"].concat([for (button in sceneButtons) SceneData.data.getLabel(button)]);

		// Changes are applied after the loop, which iterates over the groups
		var groupToDelete: Null<RadioGroup> = null;
		var groupToRename: Null<RadioGroup> = null;
		var newId: String = "";

		for (group in RadioGroups.all) {
			ui.row([5/6, 1/6]);

			var renameHandle: Handle = getHandle(renameHandles, group.id);
			renameHandle.text = group.id;
			var typedId: String = ui.textInput(renameHandle, "", Left);
			if (renameHandle.changed && typedId != group.id) {
				groupToRename = group;
				newId = typedId;
			}

			// The first group can't be deleted
			if (ZuiUtils.iconButton(ui, icons, 1, 3, "Delete group", false, group == RadioGroups.all[0], 0.7)) {
				groupToDelete = group;
			}

			ui.indent();

			var addHandle: Handle = getHandle(addHandles, group.id);
			var picked: Int = ui.combo(addHandle, addOptions, "Add", true, Right);
			if (addHandle.changed && picked > 0) {
				if (RadioGroups.moveButton(sceneButtons[picked - 1], group)) History.edited("Change radio group");
				addHandle.position = 0;
				uiBase.hwnds[PanelProperties].redraws = 2;
			}

			if (group.buttons.length == 0) {
				ui.text("No buttons in this group.");
			} else {
				for (button in group.buttons.copy()) {
					var path: Null<String> = SceneData.data.getLabel(button);
					var label: String = path != null ? path : "(removed)";
					if (group.activeButton == button) label += " [active]";

					ui.row([5/6, 1/6]);
					ui.text(label, Left);

					if (ZuiUtils.iconButton(ui, icons, 7, 0, "Set Active", group.activeButton == button, false, 0.7)) {
						group.setActiveButton(button);
						History.edited("Set active radio button");
						uiBase.hwnds[PanelProperties].redraws = 2;
					}
				}
			}

			ui.unindent();
			ui._y += 2;
			ui.separator();
		}

		if (groupToDelete != null && RadioGroups.delete(groupToDelete)) {
			History.edited("Delete radio group");
			uiBase.hwnds[PanelProperties].redraws = 2;
		}

		if (groupToRename != null && RadioGroups.rename(groupToRename, newId)) {
			History.edited("Rename radio group");
			uiBase.hwnds[PanelProperties].redraws = 2;
		}
	}

	static function getHandle(handles: Map<String, Handle>, groupId: String): Handle {
		var handle: Null<Handle> = handles.get(groupId);
		if (handle == null) {
			handle = new Handle({position: 0});
			handles.set(groupId, handle);
		}
		return handle;
	}
}
