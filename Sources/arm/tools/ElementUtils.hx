package arm.tools;

import arm.tools.CanvasUtils;

import koui.Koui;
import koui.elements.Button;
import koui.elements.Checkbox;
import koui.elements.Element;
import koui.elements.ImagePanel;
import koui.elements.Label;
import koui.elements.Panel;
import koui.elements.Progressbar;
import koui.elements.RadioButton;
import koui.elements.Slider;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.ColLayout;
import koui.elements.layouts.RowLayout;
import koui.utils.ElementMatchBehaviour.TypeMatchBehaviour;
import koui.utils.RadioGroup;

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
		if (Std.isOfType(element, RadioButton)) return "RadioButton";
		if (Std.isOfType(element, Checkbox)) return "Checkbox";
		if (Std.isOfType(element, Progressbar)) return "Progressbar";
		if (Std.isOfType(element, Slider)) return "Slider";
		if (Std.isOfType(element, Label)) return "Label";
		if (Std.isOfType(element, ImagePanel)) return "ImagePanel";
		if (Std.isOfType(element, Panel)) return "Panel";
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
		properties: Dynamic,
		?radioGroupMap: Map<String, RadioGroup>
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

			case "RadioButton":
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

				var radioButton: RadioButton = new RadioButton(group, text);
				if (properties != null && properties.isChecked != null && properties.isChecked) {
					radioButton.group.setActiveButton(radioButton);
				}
				element = radioButton;

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

			case "Slider":
				var minVal: Float = properties != null && properties.minValue != null ? properties.minValue : 0.0;
				var maxVal: Float = properties != null && properties.maxValue != null ? properties.maxValue : 1.0;
				var slider: Slider = new Slider(minVal, maxVal);
				if (properties != null) {
					if (properties.value != null) {
						slider.value = properties.value;
					}
					if (properties.precision != null) {
						slider.precision = properties.precision;
					}
					if (properties.orientation != null) {
						slider.orientation = cast properties.orientation;
					}
				}
				element = slider;

			case "AnchorPane":
				var pane: AnchorPane = new AnchorPane(posX, posY, width, height);
				element = pane;

			case "RowLayout":
				var row: RowLayout = new RowLayout(posX, posY, width, height, 0);
				element = row;

			case "ColLayout":
				var col: ColLayout = new ColLayout(posX, posY, width, height, 0);
				element = col;

			case "Panel":
				element = new Panel();

			case "ImagePanel":
				var imagePanel: ImagePanel = new ImagePanel(null);
				if (properties != null) {
					if (properties.imageName != null && properties.imageName != "") {
						var img: kha.Image = Koui.getImage(properties.imageName);
						if (img != null) {
							imagePanel.image = img;
						}
					}
					if (properties.scale != null) {
						imagePanel.scale = properties.scale;
					}
				}
				element = imagePanel;

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

			case "RadioButton":
				var radioButton: RadioButton = cast element;
				return {
					text: radioButton.text,
					isChecked: radioButton.isChecked,
					radioGroup: radioButton.group != null ? radioButton.group.id : ""
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

			case "Slider":
				var slider: Slider = cast element;
				return {
					value: slider.value,
					minValue: slider.minValue,
					maxValue: slider.maxValue,
					precision: slider.precision,
					orientation: cast slider.orientation
				};

			case "Panel", "AnchorPane", "RowLayout", "ColLayout":
				return {};

			case "ImagePanel":
				var imagePanel: ImagePanel = cast element;
				return {
					imageName: CanvasUtils.getImageName(imagePanel.image),
					scale: imagePanel.scale
				};

			default:
				return {};
		}
	}
}
