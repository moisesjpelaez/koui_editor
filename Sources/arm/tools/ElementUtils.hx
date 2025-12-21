package arm.tools;

import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.Progressbar;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;

/**
 * Shared utilities for element creation and type detection.
 * Used by both the editor (CanvasUtils) and can be referenced by other tools.
 */
@:access(koui.elements.Panel)
class ElementUtils {
	/**
	 * Returns the type string for an element.
	 */
	public static function getElementType(element: Element): String {
		if (Std.isOfType(element, Button)) return "Button";
		if (Std.isOfType(element, Checkbox)) return "Checkbox";
		if (Std.isOfType(element, Progressbar)) return "Progressbar";
		if (Std.isOfType(element, Label)) return "Label";
		// Check RowLayout/ColLayout before AnchorPane since they're more specific
		if (Std.isOfType(element, RowLayout)) return "RowLayout";
		if (Std.isOfType(element, ColLayout)) return "ColLayout";
		if (Std.isOfType(element, AnchorPane)) return "AnchorPane";
		return "Unknown";
	}

	/**
	 * Creates an element from deserialized data.
	 * @param type Element type string (Label, Button, AnchorPane, RowLayout, ColLayout)
	 * @param posX X position
	 * @param posY Y position
	 * @param width Element width
	 * @param height Element height
	 * @param anchor Anchor value
	 * @param visible Visibility flag
	 * @param disabled Disabled flag
	 * @param tID Theme ID
	 * @param properties Type-specific properties
	 * @return Created element or null if type is unknown
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
		properties: Dynamic
	): Element {
		var element: Element = null;

		switch (type) {
			case "Label":
				var text: String = properties != null && properties.text != null ? properties.text : "";
				var label: Label = new Label(text);
				if (properties != null) {
					if (properties.alignmentHor != null) {
						label.alignmentHor = cast properties.alignmentHor;
					}
					if (properties.alignmentVert != null) {
						label.alignmentVert = cast properties.alignmentVert;
					}
				}
				element = label;

			case "Button":
				var text: String = properties != null && properties.text != null ? properties.text : "";
				var button: Button = new Button(text);
				if (properties != null) {
					if (properties.isToggle != null) {
						button.isToggle = properties.isToggle;
					}
					if (properties.isPressed != null) {
						button.isPressed = properties.isPressed;
					}
				}
				element = button;

			case "Checkbox":
				var text: String = properties != null && properties.text != null ? properties.text : "";
				var checkbox: Checkbox = new Checkbox(text);
				if (properties != null) {
					if (properties.isChecked != null) {
						checkbox.isChecked = properties.isChecked;
						// Update the internal Panel's visual state
						var checkSquare: Panel = checkbox.getChild(new TypeMatchBehaviour(Panel));
						checkSquare.setContextElement(checkbox.isChecked ? "checked" : "");
					}
				}
				element = checkbox;

			case "Progressbar":
				var minVal: Float = properties != null && properties.minValue != null ? properties.minValue : 0.0;
				var maxVal: Float = properties != null && properties.maxValue != null ? properties.maxValue : 1.0;
				var progressbar: Progressbar = new Progressbar(minVal, maxVal);
				if (properties != null) {
					if (properties.value != null) {
						progressbar.value = properties.value;
					}
					if (properties.text != null) {
						progressbar.text = properties.text;
					}
					if (properties.precision != null) {
						progressbar.precision = properties.precision;
					}
				}
				element = progressbar;

			case "AnchorPane":
				var pane: AnchorPane = new AnchorPane(posX, posY, width, height);
				element = pane;

			case "RowLayout":
				var row: RowLayout = new RowLayout(posX, posY, width, height, 0);
				element = row;

			case "ColLayout":
				var col: ColLayout = new ColLayout(posX, posY, width, height, 0);
				element = col;

			default:
				trace('Unknown element type: $type');
				return null;
		}

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
		switch (type) {
			case "Label":
				var label: Label = cast element;
				return {
					text: label.text,
					alignmentHor: cast label.alignmentHor,
					alignmentVert: cast label.alignmentVert
				};

			case "Button":
				var button: Button = cast element;
				return {
					text: button.text,
					isToggle: button.isToggle,
					isPressed: button.isPressed
				};

			case "Checkbox":
				var checkbox: Checkbox = cast element;
				return {
					text: checkbox.text,
					isChecked: checkbox.isChecked
				};

			case "Progressbar":
				var progressbar: Progressbar = cast element;
				return {
					value: progressbar.value,
					minValue: progressbar.minValue,
					maxValue: progressbar.maxValue,
					text: progressbar.text,
					precision: progressbar.precision
				};

			case "AnchorPane", "RowLayout", "ColLayout":
				return {};

			default:
				return {};
		}
	}
}
