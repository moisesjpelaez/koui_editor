package arm.tools;

import arm.ElementsData;
import koui.elements.Element;

class NameUtils {
	static var elements: Array<THierarchyEntry> = ElementsData.data.elements;

	/**
	 * Generate a unique name from a base name and a list of existing names.
	 * Finds the lowest available number suffix (e.g., "Scene_1", "Scene_2", etc.)
	 * @param baseName The base name (e.g., "Scene", "Button")
	 * @param existingNames Array of existing names to check against
	 * @param separator The separator between base name and number (default: " ")
	 * @return A unique name with the lowest available number suffix
	 */
	public static function generateUniqueName(baseName: String, existingNames: Array<String>, separator: String = "_"): String {
		// Collect existing numbers for this base name
		var existingNumbers: Array<Int> = [];
		for (name in existingNames) {
			// Check if name starts with our baseName
			if (name.indexOf(baseName) == 0) {
				// Try to extract the number suffix
				var parts: Array<String> = name.split(separator);
				if (parts.length > 1) {
					var num: Null<Int> = Std.parseInt(parts[parts.length - 1]);
					if (num != null) {
						existingNumbers.push(num);
					}
				}
			}
		}

		// Find the lowest available number starting from 1
		var counter: Int = 1;
		while (existingNumbers.indexOf(counter) != -1) {
			counter++;
		}

		return baseName + separator + counter;
	}

	static function getSiblingNames(element: Element, parent: Element): Array<String> {
		var siblings: Array<Element> = HierarchyUtils.getChildren(parent);
		var existingNames: Array<String> = [];

		// Collect sibling names (excluding the element itself)
		for (sibling in siblings) {
			if (sibling != element) {
				for (entry in elements) {
					if (entry.element == sibling) {
						existingNames.push(entry.key);
						break;
					}
				}
			}
		}

		return existingNames;
	}

	public static function generateName(element: Element, parent: Element): String {
		var baseName: String = Type.getClassName(Type.getClass(element)).split(".").pop();
		var existingNames: Array<String> = getSiblingNames(element, parent);
		return generateUniqueName(baseName, existingNames, "_");
	}

	public static function ensureUniqueName(proposedName: String, element: Element, parent: Element): String {
		var existingNames: Array<String> = getSiblingNames(element, parent);

		// If no conflict, use proposed name
		if (existingNames.indexOf(proposedName) == -1) {
			return proposedName;
		}

		// Extract base name from proposedName (e.g., "Button_1" -> "Button")
		var parts: Array<String> = proposedName.split("_");
		var baseName: String = parts[0];

		return generateUniqueName(baseName, existingNames, "_");
	}
}