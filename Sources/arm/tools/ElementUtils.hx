package arm.tools;

import arm.editors.ElementRegistry;
import arm.editors.IElementEditor;
import koui.elements.Element;
import koui.utils.RadioGroup;

/**
 * Shared utilities for element creation and type detection.
 * Delegates to ElementRegistry for type-specific behavior.
 */
class ElementUtils {
	/**
	 * Returns the type string for an element.
	 */
	public static function getElementType(element: Element): String {
		return ElementRegistry.getElementType(element);
	}

	/**
	 * Creates an element from deserialized data.
	 */
	public static function createElement(
		type: String,
		posX: Int,
		posY: Int,
		width: Int,
		height: Int,
		anchor: Int,
		visible: Bool,
		disabled: Bool,
		tID: String,
		properties: Dynamic,
		?radioGroupMap: Map<String, RadioGroup>
	): Element {
		var editor: IElementEditor = ElementRegistry.getByTypeName(type);
		if (editor == null) {
			trace('Unknown element type: $type');
			return null;
		}

		var element: Element = editor.createFromData(posX, posY, width, height, properties, radioGroupMap);

		// Apply common properties
		if (element != null) {
			element.posX = posX;
			element.posY = posY;
			element.width = width;
			element.height = height;
			element.anchor = cast anchor;
			element.visible = visible;
			element.disabled = disabled;
			if (tID != null && tID != "") {
				element.setTID(tID);
			}
		}

		return element;
	}

	/**
	 * Serializes type-specific properties for an element.
	 */
	public static function serializeProperties(element: Element, type: String): Dynamic {
		var editor: IElementEditor = ElementRegistry.getByTypeName(type);
		if (editor == null) return {};
		return editor.serializeProperties(element);
	}
}
