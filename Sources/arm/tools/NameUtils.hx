package arm.tools;

import arm.data.SceneData;
import koui.elements.Element;

class NameUtils {
	// `baseName` with the lowest free number ("Scene_1", "Scene_2"), for new elements and scenes
	public static function generateUniqueName(baseName: String, existingNames: Array<String>, separator: String = "_"): String {
		var existingNumbers: Array<Int> = [];
		for (name in existingNames) {
			var num: Int = suffixNumber(name, baseName, separator);
			if (num > 0) existingNumbers.push(num);
		}

		var counter: Int = 1;
		while (existingNumbers.indexOf(counter) != -1) {
			counter++;
		}

		return baseName + separator + counter;
	}

	/**
	 * `proposedName` if it's free, otherwise its base name with the number after
	 * the highest taken: "My_Button_2" becomes "My_Button_3", "Label" "Label_1".
	 */
	public static function nextUniqueName(proposedName: String, existingNames: Array<String>, separator: String = "_"): String {
		if (existingNames.indexOf(proposedName) == -1) return proposedName;

		var base: String = baseName(proposedName, separator);
		var highest: Int = 0;
		for (name in existingNames) {
			var num: Int = suffixNumber(name, base, separator);
			if (num > highest) highest = num;
		}
		return base + separator + (highest + 1);
	}

	// `name` without a trailing separator and number: "My_Button_2" becomes "My_Button"
	public static function baseName(name: String, separator: String = "_"): String {
		var index: Int = name.lastIndexOf(separator);
		if (index <= 0) return name;
		return isNumber(name.substr(index + separator.length)) ? name.substr(0, index) : name;
	}

	// The number in `base` + separator + number, 0 for `base` itself, -1 otherwise
	static function suffixNumber(name: String, base: String, separator: String): Int {
		if (name == base) return 0;
		var prefix: String = base + separator;
		if (!StringTools.startsWith(name, prefix)) return -1;
		var rest: String = name.substr(prefix.length);
		return isNumber(rest) ? Std.parseInt(rest) : -1;
	}

	static function isNumber(text: String): Bool {
		if (text.length == 0) return false;
		for (i in 0...text.length) {
			var c: Int = text.charCodeAt(i);
			if (c < "0".code || c > "9".code) return false;
		}
		return true;
	}

	// The names of the user elements inside `parent`, except `element`
	public static function getSiblingNames(element: Null<Element>, parent: Element): Array<String> {
		var sceneData: SceneData = SceneData.data;
		var existingNames: Array<String> = [];

		for (sibling in sceneData.getChildren(parent)) {
			if (sibling != element) existingNames.push(sceneData.getElementKey(sibling));
		}

		return existingNames;
	}

	public static function generateName(element: Element, parent: Element): String {
		var baseName: String = Type.getClassName(Type.getClass(element)).split(".").pop();
		var existingNames: Array<String> = getSiblingNames(element, parent);
		return generateUniqueName(baseName, existingNames, "_");
	}

	public static function ensureUniqueName(proposedName: String, element: Element, parent: Element): String {
		return nextUniqueName(proposedName, getSiblingNames(element, parent));
	}
}
