package arm.data;

import arm.tools.NameUtils;

import koui.elements.RadioButton;
import koui.utils.RadioGroup;

/**
 * The canvas' radio groups; their buttons can be in any scene. The first group
 * always exists. Callers record the undo steps.
 */
@:access(koui.utils.RadioGroup)
class RadioGroups {
	public static var all(get, never): Array<RadioGroup>;
	static inline function get_all(): Array<RadioGroup> return SceneData.data.radioGroups;

	public static function find(id: String): Null<RadioGroup> {
		for (group in all) {
			if (group.id == id) return group;
		}
		return null;
	}

	// "RadioGroup" if `requestedId` is empty; a taken name gets a number
	public static function create(requestedId: String): RadioGroup {
		var baseId: String = StringTools.trim(requestedId != null ? requestedId : "");
		if (baseId == "") baseId = "RadioGroup";

		var group: RadioGroup = new RadioGroup(NameUtils.nextUniqueName(baseId, [for (group in all) group.id]));
		all.push(group);
		return group;
	}

	// Its buttons move to the first group, which can't be deleted
	public static function delete(group: RadioGroup): Bool {
		var index: Int = all.indexOf(group);
		if (index <= 0) return false;

		for (button in group.buttons.copy()) moveButton(button, all[0]);
		all.splice(index, 1);
		return true;
	}

	// False if `newId` is empty or taken
	public static function rename(group: RadioGroup, newId: String): Bool {
		var id: String = StringTools.trim(newId);
		if (id == "" || id == group.id || find(id) != null) return false;

		group.id = id;
		return true;
	}

	// False if it's already there
	public static function moveButton(button: RadioButton, group: RadioGroup): Bool {
		if (button.group == group) return false;

		if (button.group != null) button.group.remove(button);
		button.group = group;
		group.add(button);
		return true;
	}
}
