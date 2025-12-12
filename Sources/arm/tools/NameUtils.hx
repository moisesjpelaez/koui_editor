package arm.tools;

import arm.ElementsData;
import koui.elements.Element;

/**
 * Utilities for generating and validating element names in the hierarchy.
 */
class NameUtils {

	/**
	 * Generate a unique name for an element based on its type and parent's children.
	 * Counts same-type siblings to create name like "Button_1", "Button_2", etc.
	 */
	public static function generateName(element: Element, parent: Element): String {
		var baseName: String = Type.getClassName(Type.getClass(element)).split(".").pop();
		var siblings: Array<Element> = HierarchyUtils.getChildren(parent);

		// Count same-type siblings
		var sameTypeCount: Int = 0;
		for (sibling in siblings) {
			if (Type.getClass(sibling) == Type.getClass(element)) {
				sameTypeCount++;
			}
		}

		return baseName + "_" + (sameTypeCount + 1);
	}

	/**
	 * Ensure a name is unique among siblings. If conflict exists, increment suffix.
	 * Used when reparenting to avoid duplicate names in the new parent.
	 */
	public static function ensureUniqueName(proposedName: String, element: Element, parent: Element): String {
		var siblings: Array<Element> = HierarchyUtils.getChildren(parent);
		var existingNames: Array<String> = [];

		// Collect sibling names (excluding the element itself)
		for (sibling in siblings) {
			if (sibling != element) {
				for (entry in ElementsData.data.elements) {
					if (entry.element == sibling) {
						existingNames.push(entry.key);
						break;
					}
				}
			}
		}

		// If no conflict, use proposed name
		if (existingNames.indexOf(proposedName) == -1) {
			return proposedName;
		}

		// Extract base and number from proposedName (e.g., "Button_1" -> "Button", 1)
		var parts: Array<String> = proposedName.split("_");
		var baseName: String = parts[0];
		var startNum: Int = parts.length > 1 ? Std.parseInt(parts[parts.length - 1]) : 1;
		if (startNum == null) startNum = 1;

		// Increment until we find a unique name
		var uniqueName: String = proposedName;
		var counter: Int = startNum;
		while (existingNames.indexOf(uniqueName) != -1) {
			counter++;
			uniqueName = baseName + "_" + counter;
		}

		return uniqueName;
	}
}